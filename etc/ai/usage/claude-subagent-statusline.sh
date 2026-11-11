#!/bin/bash
# Claude Code "subagentStatusLine" integration: records per-subagent token
# usage (and an estimated $ cost) to the local ai-usage SQLite store.
#
# Deliberately emits no stdout: omitting a row override keeps Claude Code's
# default "name . description . token count" rendering for every subagent
# row, since this script's job is only to capture data, not redesign the
# display (no reporting/UI layer yet -- data store only, for now).
#
# Wired via etc/claude-code/settings.json "subagentStatusLine". Payload
# arrives as JSON on stdin; see https://code.claude.com/docs/en/statusline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

# A render must stay fast: a held write lock costs this much, then the write is skipped.
# shellcheck disable=SC2034
USAGE_DB_BUSY_TIMEOUT_MS=200

PAYLOAD=$(cat)

PARENT_SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty')
PARENT_TRANSCRIPT=$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty')

if [[ -z "$PARENT_SESSION_ID" ]]; then
    exit 0
fi

usage_db_init 2>/dev/null || exit 0
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

SQL=""
while IFS=$'\x1f' read -r TASK_ID NAME AGENT_TYPE MODEL_ID EFFORT TOKEN_COUNT \
    CONTEXT_WINDOW_SIZE START_TIME STATUS; do
    [[ -z "$TASK_ID" ]] && continue

    SUBAGENT_TRANSCRIPT=$(usage_subagent_transcript_path "$PARENT_TRANSCRIPT" "$TASK_ID")
    ESTIMATED_COST=$(usage_transcript_cost "$SUBAGENT_TRANSCRIPT") || ESTIMATED_COST=""
    STARTED_AT="$START_TIME"
    [[ -z "$STARTED_AT" || "$STARTED_AT" == "null" ]] && STARTED_AT="$NOW"

    SQL+="
        INSERT INTO subagent_tasks (
            tool, parent_session_id, task_id, name, agent_type, model, effort,
            token_count, estimated_cost_usd, context_window_size,
            started_at, updated_at, status, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$PARENT_SESSION_ID"), $(sql_str "$TASK_ID"),
            $(sql_str "$NAME"), $(sql_str "$AGENT_TYPE"), $(sql_str "$MODEL_ID"), $(sql_str "$EFFORT"),
            $(sql_num "$TOKEN_COUNT"), $(sql_num "$ESTIMATED_COST"), $(sql_num "$CONTEXT_WINDOW_SIZE"),
            $(sql_str "$STARTED_AT"), $(sql_str "$NOW"), $(sql_str "$STATUS"), $(sql_str "$PAYLOAD")
        )
        ON CONFLICT(tool, parent_session_id, task_id) DO UPDATE SET
            name = COALESCE(excluded.name, subagent_tasks.name),
            agent_type = excluded.agent_type,
            model = excluded.model,
            effort = excluded.effort,
            token_count = excluded.token_count,
            -- A task's cost only grows: per-request usage is fixed once billed and requests
            -- accumulate, so a firing that reads a shorter transcript must not lower a
            -- higher stored value. MAX() yields NULL only when both sides are NULL.
            estimated_cost_usd = MAX(
                COALESCE(excluded.estimated_cost_usd, subagent_tasks.estimated_cost_usd),
                COALESCE(subagent_tasks.estimated_cost_usd, excluded.estimated_cost_usd)),
            context_window_size = excluded.context_window_size,
            updated_at = excluded.updated_at,
            status = excluded.status,
            raw_json = excluded.raw_json;
    "
done <<<"$(usage_subagent_task_rows "$PAYLOAD")"

if [[ -n "$SQL" ]]; then
    usage_sql "$SQL" 2>/dev/null || true
fi

exit 0
