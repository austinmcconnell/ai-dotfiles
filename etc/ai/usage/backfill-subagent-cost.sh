#!/bin/bash
# Recomputes subagent_tasks.estimated_cost_usd for every claude-code row from that task's own
# transcript (usage_transcript_cost in lib.sh). Only that column is written. A row whose transcript
# is missing or cannot be fully priced is cleared to NULL rather than left holding a figure this
# script cannot reproduce, so no row keeps a value from a superseded estimator. Safe to re-run.
#
# Usage:
#   backfill-subagent-cost.sh           dry run: print before/after per row, write nothing
#   backfill-subagent-cost.sh --apply   back up the DB, then update in one transaction

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

if [[ ! -f "$USAGE_DB" ]]; then
    echo "no DB at $USAGE_DB" >&2
    exit 1
fi

# Prints the UPDATE for one row and a before/after line for the report. An unpriceable row is
# cleared to NULL, except when it is already NULL and so needs no statement.
backfill_row() {
    local parent_id="$1" task_id="$2" model="$3" before="$4" payload="$5"
    local transcript subagent_transcript after value

    transcript="$(jq -r '.transcript_path // empty' <<<"$payload")"
    subagent_transcript="$(usage_subagent_transcript_path "$transcript" "$task_id")"
    after="$(usage_transcript_cost "$subagent_transcript")"

    if [[ -z "$after" ]]; then
        if [[ -z "$before" ]]; then
            printf '%s %s NULL NULL (already clear)\n' "${task_id:0:8}" "$model" >&2
            return 0
        fi
        value="NULL"
        printf '%s %s %s NULL (cleared, no transcript price)\n' \
            "${task_id:0:8}" "$model" "$before" >&2
    else
        value="$after"
        printf '%s %s %s %s\n' "${task_id:0:8}" "$model" "${before:-NULL}" "$after" >&2
    fi

    printf "UPDATE subagent_tasks SET estimated_cost_usd = %s" "$value"
    printf " WHERE tool = 'claude-code' AND parent_session_id = %s AND task_id = %s;\n" \
        "$(sql_str "$parent_id")" "$(sql_str "$task_id")"
}

ROWS="$(sqlite3 -separator "$FIELD_SEP" "$USAGE_DB" "
    SELECT parent_session_id, task_id, model, estimated_cost_usd, raw_json
    FROM subagent_tasks WHERE tool = 'claude-code';
")"

if [[ -z "$ROWS" ]]; then
    echo "no claude-code subagent_tasks rows found"
    exit 0
fi

echo "task model before after" >&2
STATEMENTS=""
COUNT=0
while IFS="$FIELD_SEP" read -r parent_id task_id model before payload; do
    [[ -z "$task_id" ]] && continue
    COUNT=$((COUNT + 1))
    STATEMENTS+="$(backfill_row "$parent_id" "$task_id" "$model" "$before" "$payload")"$'\n'
done <<<"$ROWS"

UPDATES="$(grep -c '^UPDATE ' <<<"$STATEMENTS" || true)"
echo "rows: $COUNT, statements: $UPDATES" >&2

if [[ "$APPLY" != true ]]; then
    echo "dry run: no changes written. Re-run with --apply to back up and update." >&2
    exit 0
fi

BACKUP="$USAGE_DB.bak-$(date -u +%Y%m%dT%H%M%SZ)"
# Timestamps are second-granular, so two runs in one second would otherwise overwrite the
# first backup with a copy of the already-updated DB, losing the only pre-change snapshot.
if [[ -e "$BACKUP" ]]; then
    echo "backup already exists, refusing to overwrite: $BACKUP" >&2
    exit 1
fi
sqlite3 "$USAGE_DB" ".backup '$BACKUP'"
echo "backup written: $BACKUP" >&2

sqlite3 -bail "$USAGE_DB" "BEGIN; $STATEMENTS COMMIT;"
echo "updated $UPDATES of $COUNT rows" >&2
