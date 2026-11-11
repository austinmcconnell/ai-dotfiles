#!/bin/bash
# Fills compaction_events.real_* on PostCompact rows from the compact_boundary records in each
# session's transcripts (usage_resolve_compaction_boundaries in lib.sh). Claude Code writes a
# boundary after the PostCompact hook runs, so the hook leaves these columns NULL and this fills
# them, either from the statusline or by hand. Safe to re-run.
#
# A row and a boundary pair only when each is the other's single candidate within 5 seconds.
# Ambiguous rows, and rows holding a value with no boundary to check it against, are listed and
# left alone. --apply may also replace a wrong value, and clears a row only when its value is
# provably another boundary's preTokens in the same session. A session whose transcripts cannot
# all be read cleanly is skipped.
#
# Usage:
#   resolve-compaction-boundaries.sh [session-id]           dry run: report per row, write nothing
#   resolve-compaction-boundaries.sh --apply [session-id]   back up the DB, then write

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

APPLY=false
SESSION_FILTER=""
for arg in "$@"; do
    case "$arg" in
    --apply) APPLY=true ;;
    -*)
        echo "usage: $0 [--apply] [session-id]" >&2
        exit 2
        ;;
    *) SESSION_FILTER="$arg" ;;
    esac
done

if [[ ! -f "$USAGE_DB" ]]; then
    echo "no DB at $USAGE_DB" >&2
    exit 1
fi

if [[ -n "$SESSION_FILTER" ]]; then
    SESSIONS="$SESSION_FILTER"
else
    SESSIONS="$(usage_sql "SELECT DISTINCT session_id FROM compaction_events
        WHERE tool = 'claude-code' AND hook_event = 'PostCompact' ORDER BY session_id;")"
fi

if [[ -z "$SESSIONS" ]]; then
    echo "no claude-code PostCompact rows found"
    exit 0
fi

# Runs one session in $1 mode and prints its report lines to stderr under the session id. Sets
# CHANGES to the number of rows the report says would change, and SKIPPED when the session was
# left alone.
resolve_session() {
    local session="$1" mode="$2" report status=0 line
    report="$(usage_resolve_compaction_boundaries "$session" "$mode")" || status=$?
    if ((status == 3)); then
        SKIPPED=$((SKIPPED + 1))
        echo "${session:0:8} skipped (see above)" >&2
        return 0
    elif ((status != 0)); then
        echo "${session:0:8} failed with status $status" >&2
        exit 1
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        printf '%s %s\n' "${session:0:8}" "$line" >&2
        case "$line" in
        fill\|* | correct\|* | neighbour\|*) CHANGES=$((CHANGES + 1)) ;;
        esac
    done <<<"$report"
}

echo "session class|row|before|after (summary|rows|boundaries|paired)" >&2
CHANGES=0
SKIPPED=0
while IFS= read -r session; do
    [[ -n "$session" ]] || continue
    resolve_session "$session" report
done <<<"$SESSIONS"
echo "rows to write: $CHANGES, sessions skipped: $SKIPPED" >&2

if [[ "$APPLY" != true ]]; then
    echo "dry run: no changes written. Re-run with --apply to back up and update." >&2
    exit 0
fi
if ((CHANGES == 0)); then
    echo "nothing to write" >&2
    exit 0
fi

BACKUP="$USAGE_DB.bak-resolve-$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -e "$BACKUP" ]]; then
    echo "backup already exists, refusing to overwrite: $BACKUP" >&2
    exit 1
fi
sqlite3 "$USAGE_DB" ".backup '$BACKUP'"
echo "backup written: $BACKUP" >&2

# The transcripts and rows are read again, so this prints what was actually written.
echo "applying:" >&2
CHANGES=0
SKIPPED=0
while IFS= read -r session; do
    [[ -n "$session" ]] || continue
    resolve_session "$session" apply
done <<<"$SESSIONS"
echo "wrote $CHANGES rows, sessions skipped: $SKIPPED" >&2
