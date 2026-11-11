#!/bin/bash
# Logs PreCompact/PostCompact hook firings to the local ai-usage store.
#
# Wired via etc/claude-code/settings.json to BOTH the "PreCompact" and
# "PostCompact" hook arrays (matcher "*") -- one script, distinguished by the
# payload's hook_event_name. Neither event's payload carries any token data
# (Claude Code hooks never do -- confirmed against the official hooks
# reference and etc/ai/usage/README.md's "Claude Code integration" section),
# so snapshot_input_tokens is read from the session's last known
# sessions.input_tokens row instead: an approximation of the token count
# right before (PreCompact) or shortly after (PostCompact) compaction, not
# an exact figure from the compaction itself.
#
# The exact figures (real_* columns) are not available yet on PostCompact either: Claude Code
# writes the compact_boundary record into the transcript after this hook returns. Those columns are
# filled afterwards from the transcript (usage_resolve_compaction_boundaries in usage/lib.sh), so
# this hook inserts them NULL. A PostCompact row keeps raw_json._diag.hook_started_at, the only
# millisecond-resolution timestamp of the firing.
#
# Purely observational: always exits 0 (even when the DB is locked or unwritable) and never emits a
# `deny` decision, so it can never block or delay the compaction it's trying to measure. Its SQLite
# waits are short and add up to well under the hook's 5 s limit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../usage/lib.sh"

# A failure anywhere below (locked or unwritable DB, bad payload) must not surface as a hook error.
trap 'exit 0' EXIT

PAYLOAD=$(cat)

# Millisecond ISO-8601 so it compares directly with a boundary record's timestamp.
HOOK_STARTED="$(perl -MTime::HiRes=gettimeofday -MPOSIX=strftime -e '
    my ($s, $u) = gettimeofday;
    printf "%s.%03dZ", strftime("%Y-%m-%dT%H:%M:%S", gmtime $s), $u / 1000' 2>/dev/null ||
    date -u +"%Y-%m-%dT%H:%M:%SZ")"

IFS=$'\t' read -r HOOK_EVENT SESSION_ID TRIGGER <<<"$(
    printf '%s' "$PAYLOAD" | jq -r '[.hook_event_name, .session_id, .trigger] | map(. // "") | @tsv'
)"

RAW_JSON="$PAYLOAD"
if [[ "$HOOK_EVENT" == "PostCompact" ]]; then
    RAW_JSON="$(printf '%s' "$PAYLOAD" | jq -c --arg started "$HOOK_STARTED" \
        '. + {_diag: {hook_started_at: $started}}' || printf '%s' "$PAYLOAD")"
fi

if [[ -n "$SESSION_ID" ]]; then
    USAGE_DB_BUSY_TIMEOUT_MS=300
    usage_db_init
    # shellcheck disable=SC2034
    USAGE_DB_BUSY_TIMEOUT_MS=400
    SNAPSHOT_TOKENS="$(usage_sql "SELECT input_tokens FROM sessions
        WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")" || SNAPSHOT_TOKENS=""
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    usage_sql "
        INSERT INTO compaction_events (
            tool, session_id, hook_event, trigger, snapshot_input_tokens, occurred_at, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$SESSION_ID"), $(sql_str "$HOOK_EVENT"),
            $(sql_str "$TRIGGER"), $(sql_num "$SNAPSHOT_TOKENS"),
            $(sql_str "$NOW"), $(sql_str "$RAW_JSON")
        );
    "
fi

exit 0
