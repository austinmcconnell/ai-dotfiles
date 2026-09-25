-- Local, tool-agnostic AI usage/cost tracking schema.
--
-- Both tables are upserted, not appended: the AI tools that populate them
-- (currently Claude Code's statusLine/subagentStatusLine) report cumulative
-- per-session totals on every firing, not per-turn deltas, so each row is a
-- snapshot keyed by identity and overwritten in place. Treating this as an
-- events log would double-count, since every firing already carries the
-- running total.
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
