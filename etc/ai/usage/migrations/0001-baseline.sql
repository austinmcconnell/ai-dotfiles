-- Version 1, frozen: the schema when user_version tracking began. It only
-- adopts a DB created before then, so never edit it; schema.sql documents the
-- tables, and later changes are later migrations.

CREATE TABLE IF NOT EXISTS sessions (
    tool                    TEXT NOT NULL,
    session_id              TEXT NOT NULL,
    cwd                     TEXT,
    project_dir             TEXT,
    model                   TEXT,
    effort                  TEXT,
    started_at              TEXT NOT NULL,
    updated_at              TEXT NOT NULL,
    total_cost_usd          REAL,
    input_tokens            INTEGER,
    output_tokens           INTEGER,
    last_turn_cache_creation_tokens INTEGER,
    last_turn_cache_read_tokens     INTEGER,
    total_duration_ms       INTEGER,
    total_api_duration_ms   INTEGER,
    credits                 REAL,
    raw_json                TEXT,
    PRIMARY KEY (tool, session_id)
);

CREATE TABLE IF NOT EXISTS subagent_tasks (
    tool                 TEXT NOT NULL,
    parent_session_id    TEXT NOT NULL,
    task_id              TEXT NOT NULL,
    name                 TEXT,
    agent_type           TEXT,
    model                TEXT,
    effort               TEXT,
    token_count          INTEGER,
    estimated_cost_usd   REAL,
    context_window_size  INTEGER,
    started_at           TEXT NOT NULL,
    updated_at           TEXT NOT NULL,
    status               TEXT,
    raw_json             TEXT,
    PRIMARY KEY (tool, parent_session_id, task_id)
);

CREATE TABLE IF NOT EXISTS compaction_events (
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                     TEXT NOT NULL,
    session_id               TEXT NOT NULL,
    hook_event               TEXT NOT NULL,
    trigger                  TEXT,
    snapshot_input_tokens    INTEGER,
    real_pre_tokens          INTEGER,
    real_post_tokens         INTEGER,
    cumulative_dropped_tokens INTEGER,
    duration_ms              INTEGER,
    occurred_at              TEXT NOT NULL,
    raw_json                 TEXT
);

CREATE TABLE IF NOT EXISTS cost_snapshots (
    id                     INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                   TEXT NOT NULL,
    session_id             TEXT NOT NULL,
    total_cost_usd         REAL,
    input_tokens           INTEGER,
    output_tokens          INTEGER,
    cache_creation_tokens  INTEGER,
    cache_read_tokens      INTEGER,
    context_used_percentage REAL,
    occurred_at            TEXT NOT NULL,
    raw_json                TEXT
);

CREATE TABLE IF NOT EXISTS rate_limit_snapshots (
    id                        INTEGER PRIMARY KEY AUTOINCREMENT,
    tool                      TEXT NOT NULL,
    five_hour_used_percentage REAL,
    seven_day_used_percentage REAL,
    five_hour_resets_at       INTEGER,
    seven_day_resets_at       INTEGER,
    occurred_at               TEXT NOT NULL,
    raw_json                  TEXT
);
