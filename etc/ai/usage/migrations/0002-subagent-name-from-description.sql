-- Sets subagent_tasks.name to the launch description kept in each row's stored raw_json. Rows
-- written before the writer used the description hold the live activity label instead. A row
-- keeps its current name when raw_json is NULL, is not valid JSON, has no task entry for its
-- task_id, or has no non-empty text description. Every lookup goes through the validated
-- document, so a malformed row cannot raise an error and wedge usage_db_init.
UPDATE subagent_tasks
SET name = COALESCE(
    (SELECT NULLIF(json_extract(subagent_tasks.raw_json, t.fullkey || '.description'), '')
     FROM json_each(
         CASE WHEN json_valid(subagent_tasks.raw_json) THEN subagent_tasks.raw_json END,
         '$.tasks') AS t
     WHERE json_extract(subagent_tasks.raw_json, t.fullkey || '.id') = subagent_tasks.task_id
         AND json_type(subagent_tasks.raw_json, t.fullkey || '.description') = 'text'
     LIMIT 1),
    name)
WHERE raw_json IS NOT NULL;
