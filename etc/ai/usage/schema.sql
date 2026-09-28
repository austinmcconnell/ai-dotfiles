-- Local, tool-agnostic AI usage/cost tracking schema.
--
-- `sessions` and `subagent_tasks` are upserted, not appended: the AI tools
-- that populate them (currently Claude Code's statusLine/subagentStatusLine)
-- report cumulative per-session totals on every firing, not per-turn deltas,
-- so each row is a snapshot keyed by identity and overwritten in place.
-- Treating those as an events log would double-count, since every firing
-- already carries the running total.
--
-- `compaction_events` is the deliberate exception: it's append-only, because
-- the thing it records (a compaction firing) is itself a discrete event, not
-- a running total — upserting it the way `sessions` does would overwrite the
-- one snapshot that matters with whatever the next unrelated statusline
-- firing produces.
--
-- Applied idempotently by usage_db_init() in lib.sh.

CREATE TABLE IF NOT EXISTS sessions (
    tool                    TEXT NOT NULL,   -- 'claude-code', 'kiro-cli' (future), ...
    session_id              TEXT NOT NULL,
    cwd                     TEXT,
    project_dir             TEXT,
    model                   TEXT,            -- resolved model id, not a display name
    effort                  TEXT,            -- low/medium/high/xhigh/max or a numeric budget; nullable
    started_at              TEXT NOT NULL,   -- ISO8601 UTC, set once on first upsert
    updated_at              TEXT NOT NULL,   -- ISO8601 UTC, set on every upsert
    total_cost_usd          REAL,            -- nullable: not every tool computes this natively
    input_tokens            INTEGER,         -- cumulative for the session
    output_tokens           INTEGER,         -- cumulative for the session
    last_turn_cache_creation_tokens INTEGER, -- most recent turn only; not cumulative (source data has no running total)
    last_turn_cache_read_tokens     INTEGER, -- most recent turn only; not cumulative (source data has no running total)
    total_duration_ms       INTEGER,
    total_api_duration_ms   INTEGER,
    credits                 REAL,            -- nullable: a native billing unit (e.g. Kiro), if ever reachable
    raw_json                TEXT,            -- last raw payload, as insurance against needing a column for every future field
    PRIMARY KEY (tool, session_id)
);

CREATE TABLE IF NOT EXISTS subagent_tasks (
    tool                 TEXT NOT NULL,
    parent_session_id    TEXT NOT NULL,
    task_id              TEXT NOT NULL,
    name                 TEXT,
    agent_type           TEXT,
    model                TEXT,               -- resolved model id, not a display name
    effort               TEXT,
    token_count          INTEGER,
    estimated_cost_usd   REAL,               -- estimated: source data gives one token count, not an input/output split
    context_window_size  INTEGER,
    started_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL,
    status               TEXT,
    raw_json             TEXT,
    PRIMARY KEY (tool, parent_session_id, task_id)
);

-- Append-only log of PreCompact/PostCompact hook firings. Neither hook's
-- payload carries any token data (Claude Code hooks never do — see
-- README.md's "Claude Code integration" section), so snapshot_input_tokens
-- is read from this session's current `sessions.input_tokens` row at the
-- moment the hook fires: an approximation of the token count right before
-- (PreCompact) or after (PostCompact) compaction, not an exact figure from
-- the compaction itself.
--
-- The real_* columns fill that gap on PostCompact only: Claude Code writes a
-- `compact_boundary` system message with an exact compactMetadata object
-- into the session's transcript once compaction finishes, and the hook
-- payload's transcript_path can be read to extract it. That record does not
-- exist yet at PreCompact time, so these stay NULL on PreCompact rows (and
-- on any PostCompact row where the transcript couldn't be parsed).
CREATE TABLE IF NOT EXISTS compaction_events (
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                     TEXT NOT NULL,   -- 'claude-code', 'kiro-cli' (future), ...
    session_id               TEXT NOT NULL,
    hook_event               TEXT NOT NULL,   -- 'PreCompact' | 'PostCompact'
    trigger                  TEXT,            -- 'manual' | 'auto', from the hook payload
    snapshot_input_tokens    INTEGER,         -- last known sessions.input_tokens at fire time; nullable if no prior row existed
    real_pre_tokens          INTEGER,         -- exact compactMetadata.preTokens; NULL until PostCompact resolves it
    real_post_tokens         INTEGER,         -- exact compactMetadata.postTokens; PostCompact only
    cumulative_dropped_tokens INTEGER,        -- exact compactMetadata.cumulativeDroppedTokens; PostCompact only
    duration_ms              INTEGER,         -- exact compactMetadata.durationMs; PostCompact only
    occurred_at              TEXT NOT NULL,   -- ISO8601 UTC
    raw_json                 TEXT             -- the hook's raw stdin payload, as insurance against needing a column for every future field
);
