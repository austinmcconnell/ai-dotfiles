-- Local, tool-agnostic AI usage/cost tracking schema.
--
-- `sessions` and `subagent_tasks` are upserted, not appended: the AI tools
-- that populate them (currently Claude Code's statusLine/subagentStatusLine)
-- report cumulative per-session totals on every firing, not per-turn deltas,
-- so each row is a snapshot keyed by identity and overwritten in place.
-- Treating those as an events log would double-count, since every firing
-- already carries the running total.
--
-- `compaction_events` and `cost_snapshots` are the deliberate exceptions:
-- both are append-only. `compaction_events` records a discrete event (a
-- compaction firing), not a running total — upserting it the way `sessions`
-- does would overwrite the one snapshot that matters with whatever the next
-- unrelated statusline firing produces. `cost_snapshots` deliberately
-- duplicates data already in `sessions` (same cumulative totals) so a
-- session's cost/token trajectory over its lifetime survives past the point
-- `sessions` next overwrites itself — `sessions` only ever holds the latest
-- snapshot, so history has nowhere else to live.
--
-- Always the newest schema. usage_db_init() in lib.sh applies it as-is to a
-- new DB; an existing DB reaches the same shape through migrations/, so a
-- change here ships with the migration that makes it.

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
    input_tokens            INTEGER,         -- most recent API call only; not cumulative (source data has no running total)
    output_tokens           INTEGER,         -- most recent API call only; not cumulative (source data has no running total)
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
    name                 TEXT,               -- launch description; kept when a firing carries none
    agent_type           TEXT,
    model                TEXT,               -- resolved model id, not a display name
    effort               TEXT,
    token_count          INTEGER,
    estimated_cost_usd   REAL,               -- estimated from subagent transcript; NULL if unavailable
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

-- Append-only cost/token trajectory, one row per statusline firing where
-- total_cost_usd actually changed since this session's last recorded
-- snapshot (see claude-statusline.sh) -- skips true no-op re-renders while
-- keeping every real cost-changing step, so a session's history survives
-- past `sessions`' own upsert-in-place snapshot.
CREATE TABLE IF NOT EXISTS cost_snapshots (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                   TEXT NOT NULL,   -- 'claude-code', 'kiro-cli' (future), ...
    session_id             TEXT NOT NULL,
    total_cost_usd         REAL,
    input_tokens           INTEGER,         -- full context (input + cache read + cache write) of the API call in flight or just finished; not cumulative
    output_tokens          INTEGER,         -- same call's output so far; may be partial when captured mid-stream; not cumulative
    cache_creation_tokens  INTEGER,         -- most recent turn only; not cumulative (source data has no running total)
    cache_read_tokens      INTEGER,         -- most recent turn only; not cumulative (source data has no running total)
    context_used_percentage REAL,           -- relative to the model's native context ceiling, not autoCompactWindow
    occurred_at            TEXT NOT NULL,   -- ISO8601 UTC
    raw_json                TEXT            -- the statusline's raw stdin payload, as insurance against needing a column for every future field
);

-- Append-only rate-limit trajectory, one row per statusline firing where
-- five_hour_used_percentage or seven_day_used_percentage actually changed
-- since the last recorded row (see claude-statusline.sh). Deliberately no
-- session_id: unlike cost, rate limits are account-wide, not per-session --
-- every concurrently open session observes the same percentage, so keying
-- rows by session would just duplicate one real-world change N times (N =
-- concurrently open sessions) rather than attributing distinct usage to
-- each. Concurrent sessions can race on the dedup check and both insert a
-- near-simultaneous duplicate row; accepted as harmless, same as this
-- tracker's other best-effort dedup checks.
CREATE TABLE IF NOT EXISTS rate_limit_snapshots (
    id                        INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                      TEXT NOT NULL,   -- 'claude-code', 'kiro-cli' (future), ...
    five_hour_used_percentage REAL,
    seven_day_used_percentage REAL,
    five_hour_resets_at       INTEGER,         -- unix epoch seconds
    seven_day_resets_at       INTEGER,         -- unix epoch seconds
    occurred_at               TEXT NOT NULL,   -- ISO8601 UTC
    raw_json                  TEXT             -- the statusline's raw stdin payload, as insurance against needing a column for every future field
);
