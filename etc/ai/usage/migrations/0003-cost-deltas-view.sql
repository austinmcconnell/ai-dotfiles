-- Adds v_cost_deltas, which splits each session's cumulative cost into per-snapshot deltas
-- booked to the model and effort in that snapshot's raw_json. See schema.sql for its limits.
CREATE VIEW IF NOT EXISTS v_cost_deltas AS
SELECT
    id,
    tool,
    session_id,
    occurred_at,
    json_extract(CASE WHEN json_valid(raw_json) THEN raw_json END, '$.model.id') AS model,
    json_extract(CASE WHEN json_valid(raw_json) THEN raw_json END, '$.effort.level') AS effort,
    total_cost_usd - lag(total_cost_usd, 1, 0)
        OVER (PARTITION BY tool, session_id ORDER BY id) AS cost_delta_usd
FROM cost_snapshots;
