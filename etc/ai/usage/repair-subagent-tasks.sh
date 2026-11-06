#!/bin/bash
# One-time repair for subagent_tasks rows written before the column-shift fix
# (078ad84). Those rows have effort set, but the current writer always writes
# effort as NULL, so that marks a shifted row. Each repaired row is rebuilt
# from its stored raw_json using the same field mapping as the writer.
#
# Usage:
#   repair-subagent-tasks.sh           dry run: print before/after, write nothing
#   repair-subagent-tasks.sh --apply   back up the DB, then repair in one transaction

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

APPLY=false
case "${1:-}" in
    "") ;;
    --apply) APPLY=true ;;
    *)
        echo "usage: $0 [--apply]" >&2
        exit 2
        ;;
esac

FIELD_SEP=$'\x1f'

# Columns the writer sets from one task row. `effort` is always NULL and
# `raw_json` is left untouched.
repair_statement_for_row() {
    local task_id="$1" parent_id="$2" payload="$3"
    local row name agent_type model token_count context_size started_at status cost

    row="$(usage_subagent_task_rows "$payload" | awk -F "$FIELD_SEP" -v id="$task_id" '$1 == id')"
    if [[ -z "$row" ]]; then
        echo "SKIP $task_id: task not found in raw_json" >&2
        return 0
    fi

    IFS="$FIELD_SEP" read -r _ name agent_type model _ token_count context_size started_at status <<<"$row"
    cost="$(usage_estimate_cost "$model" "$token_count")"

    printf "UPDATE subagent_tasks SET name = %s, agent_type = %s, model = %s, effort = NULL, token_count = %s, estimated_cost_usd = %s, context_window_size = %s, started_at = %s, status = %s WHERE tool = 'claude-code' AND parent_session_id = %s AND task_id = %s;\n" \
        "$(sql_str "$name")" "$(sql_str "$agent_type")" "$(sql_str "$model")" \
        "$(sql_num "$token_count")" "$(sql_num "$cost")" "$(sql_num "$context_size")" \
        "$(sql_str "$started_at")" "$(sql_str "$status")" \
        "$(sql_str "$parent_id")" "$(sql_str "$task_id")"
}

describe_row() {
    local task_id="$1"
    sqlite3 -separator " | " "$USAGE_DB" "
        SELECT task_id, agent_type, model, effort, token_count, estimated_cost_usd, context_window_size, started_at
        FROM subagent_tasks WHERE task_id = $(sql_str "$task_id");
    "
}

if [[ ! -f "$USAGE_DB" ]]; then
    echo "no DB at $USAGE_DB" >&2
    exit 1
fi

CANDIDATES="$(sqlite3 -separator "$FIELD_SEP" "$USAGE_DB" "
    SELECT parent_session_id, task_id, raw_json FROM subagent_tasks
    WHERE tool = 'claude-code' AND effort IS NOT NULL;
")"

if [[ -z "$CANDIDATES" ]]; then
    echo "no shifted subagent_tasks rows found"
    exit 0
fi

STATEMENTS=""
COUNT=0
while IFS="$FIELD_SEP" read -r parent_id task_id payload; do
    [[ -z "$task_id" ]] && continue
    COUNT=$((COUNT + 1))
    echo "== before: task_id | agent_type | model | effort | token_count | cost | context_window | started_at"
    describe_row "$task_id"
    STATEMENTS+="$(repair_statement_for_row "$task_id" "$parent_id" "$payload")"$'\n'
done <<<"$CANDIDATES"

echo "rows to repair: $COUNT"

if [[ "$APPLY" != true ]]; then
    echo "dry run: no changes written. Re-run with --apply to back up and repair."
    echo "--- statements:"
    printf '%s' "$STATEMENTS"
    exit 0
fi

BACKUP="$USAGE_DB.bak-$(date -u +%Y%m%dT%H%M%SZ)"
sqlite3 "$USAGE_DB" ".backup '$BACKUP'"
echo "backup written: $BACKUP"

sqlite3 "$USAGE_DB" "BEGIN; $STATEMENTS COMMIT;"
echo "repaired $COUNT rows"
