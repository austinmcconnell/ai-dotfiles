#!/bin/bash
# Claude Code "statusLine" integration: records this session's cumulative
# cost/token usage to the local ai-usage SQLite store as a side effect, then
# prints the status line text Claude Code displays.
#
# Wired via etc/claude-code/settings.json "statusLine". Payload arrives as
# JSON on stdin; see https://code.claude.com/docs/en/statusline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

PAYLOAD=$(cat)

IFS=$'\t' read -r SESSION_ID CWD PROJECT_DIR MODEL_ID MODEL_DISPLAY EFFORT \
    COST_USD DURATION_MS API_DURATION_MS INPUT_TOKENS OUTPUT_TOKENS \
    CACHE_CREATION CACHE_READ CTX_USED_PCT <<<"$(
        printf '%s' "$PAYLOAD" | jq -r '[
        .session_id, .workspace.current_dir, .workspace.project_dir,
        .model.id, .model.display_name, .effort.level,
        .cost.total_cost_usd, .cost.total_duration_ms, .cost.total_api_duration_ms,
        .context_window.total_input_tokens, .context_window.total_output_tokens,
        .context_window.current_usage.cache_creation_input_tokens,
        .context_window.current_usage.cache_read_input_tokens,
        .context_window.used_percentage
    ] | @tsv'
    )"

if [[ -n "$SESSION_ID" ]]; then
    usage_db_init
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sqlite3 "$USAGE_DB" "
        INSERT INTO sessions (
            tool, session_id, cwd, project_dir, model, effort,
            started_at, updated_at, total_cost_usd, input_tokens, output_tokens,
            last_turn_cache_creation_tokens, last_turn_cache_read_tokens,
            total_duration_ms, total_api_duration_ms, credits, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$SESSION_ID"), $(sql_str "$CWD"), $(sql_str "$PROJECT_DIR"),
            $(sql_str "$MODEL_ID"), $(sql_str "$EFFORT"),
            $(sql_str "$NOW"), $(sql_str "$NOW"), $(sql_num "$COST_USD"),
            $(sql_num "$INPUT_TOKENS"), $(sql_num "$OUTPUT_TOKENS"),
            $(sql_num "$CACHE_CREATION"), $(sql_num "$CACHE_READ"),
            $(sql_num "$DURATION_MS"), $(sql_num "$API_DURATION_MS"),
            NULL, $(sql_str "$PAYLOAD")
        )
        ON CONFLICT(tool, session_id) DO UPDATE SET
            cwd = excluded.cwd,
            project_dir = excluded.project_dir,
            model = excluded.model,
            effort = excluded.effort,
            updated_at = excluded.updated_at,
            total_cost_usd = excluded.total_cost_usd,
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            last_turn_cache_creation_tokens = excluded.last_turn_cache_creation_tokens,
            last_turn_cache_read_tokens = excluded.last_turn_cache_read_tokens,
            total_duration_ms = excluded.total_duration_ms,
            total_api_duration_ms = excluded.total_api_duration_ms,
            raw_json = excluded.raw_json;
    "
fi

DISPLAY_MODEL="${MODEL_DISPLAY:-?}"
DISPLAY_COST="\$0.00"
[[ -n "$COST_USD" && "$COST_USD" != "null" ]] && DISPLAY_COST="$(printf '$%.4f' "$COST_USD")"
DISPLAY_CTX="${CTX_USED_PCT:-0}"
DISPLAY_EFFORT=""
[[ -n "$EFFORT" && "$EFFORT" != "null" ]] && DISPLAY_EFFORT=" | effort:$EFFORT"

printf '%s | %s | %s%% ctx%s\n' "$DISPLAY_MODEL" "$DISPLAY_COST" "$DISPLAY_CTX" "$DISPLAY_EFFORT"
