#!/bin/bash
# Logs PreCompact/PostCompact hook firings to the local ai-usage store.
#
# Wired via etc/claude-code/settings.json to BOTH the "PreCompact" and
# "PostCompact" hook arrays (matcher "*") -- one script, distinguished by the
# payload's hook_event_name. Neither event's payload carries any token data
# (Claude Code hooks never do -- confirmed against the official hooks
# reference and etc/ai/usage/README.md's "Claude Code integration" section),
# so this reads the session's last known input_tokens out of its `sessions`
# row instead: an approximation of the token count right before (PreCompact)
# or shortly after (PostCompact) compaction, not an exact figure from the
# compaction itself.
#
# Purely observational: always exits 0 and never emits a `deny` decision, so
# it can never block or delay the compaction it's trying to measure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../usage/lib.sh"

PAYLOAD=$(cat)

IFS=$'\t' read -r HOOK_EVENT SESSION_ID TRIGGER <<<"$(
    printf '%s' "$PAYLOAD" | jq -r '[.hook_event_name, .session_id, .trigger] | map(. // "") | @tsv'
)"

if [[ -n "$SESSION_ID" ]]; then
    usage_db_init
    SNAPSHOT_TOKENS=$(sqlite3 "$USAGE_DB" \
        "SELECT input_tokens FROM sessions WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sqlite3 "$USAGE_DB" "
        INSERT INTO compaction_events (
            tool, session_id, hook_event, trigger, snapshot_input_tokens, occurred_at, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$SESSION_ID"), $(sql_str "$HOOK_EVENT"),
            $(sql_str "$TRIGGER"), $(sql_num "$SNAPSHOT_TOKENS"), $(sql_str "$NOW"), $(sql_str "$PAYLOAD")
        );
    "
fi

exit 0
