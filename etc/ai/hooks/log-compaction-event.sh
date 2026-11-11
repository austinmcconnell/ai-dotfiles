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
# On PostCompact, an exact figure IS available: Claude Code writes a
# compact_boundary system message with a compactMetadata object
# (preTokens/postTokens/cumulativeDroppedTokens/durationMs) into the
# session's transcript once compaction finishes. This script reads the
# payload's transcript_path and extracts it for the real_* columns. That
# record does not exist yet at PreCompact time, so those columns stay NULL
# on PreCompact rows.
#
# Purely observational: always exits 0 and never emits a `deny` decision, so
# it can never block or delay the compaction it's trying to measure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../usage/lib.sh"

PAYLOAD=$(cat)

# Millisecond ISO-8601 so it compares directly with a boundary record's timestamp.
HOOK_STARTED="$(perl -MTime::HiRes=gettimeofday -MPOSIX=strftime -e '
    my ($s, $u) = gettimeofday;
    printf "%s.%03dZ", strftime("%Y-%m-%dT%H:%M:%S", gmtime $s), $u / 1000' 2>/dev/null ||
    date -u +"%Y-%m-%dT%H:%M:%SZ")"

IFS=$'\t' read -r HOOK_EVENT SESSION_ID TRIGGER TRANSCRIPT_PATH <<<"$(
    printf '%s' "$PAYLOAD" | jq -r '[.hook_event_name, .session_id, .trigger, .transcript_path] | map(. // "") | @tsv'
)"

REAL_PRE=""
REAL_POST=""
REAL_DROPPED=""
REAL_DURATION=""
RAW_JSON="$PAYLOAD"
if [[ "$HOOK_EVENT" == "PostCompact" && -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    BOUNDARY_COUNT="$(grep -cF '"compact_boundary"' "$TRANSCRIPT_PATH" 2>/dev/null || true)"
    LAST_BOUNDARY="$(grep -F '"compact_boundary"' "$TRANSCRIPT_PATH" 2>/dev/null | tail -1 || true)"
    LAST_META="null"
    if [[ -n "$LAST_BOUNDARY" ]]; then
        IFS=$'\t' read -r REAL_PRE REAL_POST REAL_DROPPED REAL_DURATION <<<"$(
            printf '%s' "$LAST_BOUNDARY" | jq -r '[.compactMetadata.preTokens, .compactMetadata.postTokens, .compactMetadata.cumulativeDroppedTokens, .compactMetadata.durationMs] | map(. // "") | @tsv'
        )"
        LAST_META="$(printf '%s' "$LAST_BOUNDARY" | jq -c '{timestamp, preTokens: .compactMetadata.preTokens, postTokens: .compactMetadata.postTokens, durationMs: .compactMetadata.durationMs, precomputed: .compactMetadata.precomputed}' || echo null)"
    fi
    # What the transcript held when the hook fired, kept beside the payload to diagnose
    # PostCompact rows whose real_* columns come back empty or stale.
    RAW_JSON="$(printf '%s' "$PAYLOAD" | jq -c \
        --arg started "$HOOK_STARTED" --argjson count "${BOUNDARY_COUNT:-0}" \
        --argjson last "$LAST_META" \
        '. + {_diag: {hook_started_at: $started, boundary_count: $count, last_boundary: $last}}' ||
        printf '%s' "$PAYLOAD")"
fi

if [[ -n "$SESSION_ID" ]]; then
    usage_db_init
    SNAPSHOT_TOKENS=$(sqlite3 "$USAGE_DB" \
        "SELECT input_tokens FROM sessions WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sqlite3 "$USAGE_DB" "
        INSERT INTO compaction_events (
            tool, session_id, hook_event, trigger, snapshot_input_tokens,
            real_pre_tokens, real_post_tokens, cumulative_dropped_tokens, duration_ms,
            occurred_at, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$SESSION_ID"), $(sql_str "$HOOK_EVENT"),
            $(sql_str "$TRIGGER"), $(sql_num "$SNAPSHOT_TOKENS"),
            $(sql_num "$REAL_PRE"), $(sql_num "$REAL_POST"), $(sql_num "$REAL_DROPPED"), $(sql_num "$REAL_DURATION"),
            $(sql_str "$NOW"), $(sql_str "$RAW_JSON")
        );
    "
fi

exit 0
