#!/bin/bash
# Checks what log-compaction-event.sh stores for PreCompact and PostCompact payloads.
# Builds synthetic transcripts in a temp dir and writes to a temp usage DB, so the real
# ~/.claude and usage.db are never read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
HOOK="$(dirname "$USAGE_DIR")/hooks/log-compaction-event.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export USAGE_DB_DIR="$WORK/db"

# shellcheck disable=SC1091
source "$USAGE_DIR/lib.sh"

FAILURES=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# One compact_boundary record: timestamp, preTokens, and optionally a postTokens value.
boundary() {
    jq -cn --arg ts "$1" --argjson pre "$2" --argjson post "${3:-null}" '{
        type: "system", subtype: "compact_boundary", timestamp: $ts,
        compactMetadata: {trigger: "auto", preTokens: $pre, postTokens: $post,
            cumulativeDroppedTokens: 100, durationMs: 15, precomputed: true}
    }'
}

write_fixtures() {
    local dir="$WORK/fixtures"
    mkdir -p "$dir"
    echo '{"type":"user","message":{"content":"hello"}}' >"$dir/none.jsonl"
    {
        echo '{"type":"user","message":{"content":"hello"}}'
        boundary 2026-11-09T02:23:00.276Z 252086 39415
    } >"$dir/one.jsonl"
}

# $1 is the event, $2 the session id, $3 the transcript path.
run_hook() {
    jq -cn --arg event "$1" --arg session "$2" --arg path "$3" '{
        hook_event_name: $event, session_id: $session, trigger: "auto", transcript_path: $path
    }' | bash "$HOOK"
}

# $1 is the session id, $2 a SQL expression over the row's columns.
row() {
    usage_sql "SELECT $2 FROM compaction_events WHERE session_id = '$1';"
}

test_post_compact() {
    run_hook PostCompact one "$WORK/fixtures/one.jsonl"
    check "a boundary already in the transcript is not read" "" "$(row one real_pre_tokens)"
    check "real_post_tokens stays NULL" "" "$(row one real_post_tokens)"
    check "cumulative_dropped_tokens stays NULL" "" "$(row one cumulative_dropped_tokens)"
    check "duration_ms stays NULL" "" "$(row one duration_ms)"
    check "diag stamps the hook start" "1" \
        "$(row one "json_extract(raw_json, '$._diag.hook_started_at') GLOB '20??-??-??T??:??:??*Z'")"
    check "diag holds only the hook start" "hook_started_at" \
        "$(row one "(SELECT group_concat(key) FROM json_each(raw_json, '$._diag'))")"
    check "payload fields survive beside the diag" "PostCompact" \
        "$(row one "json_extract(raw_json, '$.hook_event_name')")"
    check "payload transcript_path survives for the resolver" "$WORK/fixtures/one.jsonl" \
        "$(row one "json_extract(raw_json, '$.transcript_path')")"

    run_hook PostCompact none "$WORK/fixtures/none.jsonl"
    check "a transcript with no boundary also inserts the row" "1" \
        "$(row none "count(*)")"
}

# Holds SQLite's exclusive lock so the hook's own reads and writes wait, then fail.
test_locked_db() {
    local started status=0
    # shellcheck disable=SC2153
    { printf 'BEGIN EXCLUSIVE;\n' && sleep 30; } | sqlite3 "$USAGE_DB" >/dev/null 2>&1 &
    local lock_pid=$!
    sleep 1
    started=$SECONDS
    run_hook PostCompact locked "$WORK/fixtures/one.jsonl" >/dev/null 2>&1 || status=$?
    local elapsed=$((SECONDS - started))
    kill "$lock_pid" 2>/dev/null || true
    wait "$lock_pid" 2>/dev/null || true
    check "a locked DB still exits 0" "0" "$status"
    check "a locked DB returns within the hook's limit" "yes" \
        "$( ((elapsed < 4)) && echo yes || echo no)"
    check "a locked DB loses the row" "0" "$(row locked "count(*)")"
}

test_unwritable_db() {
    local status=0
    : >"$WORK/not-a-dir"
    USAGE_DB_DIR="$WORK/not-a-dir/db" run_hook PostCompact bad "$WORK/fixtures/one.jsonl" \
        >/dev/null 2>&1 || status=$?
    check "an unwritable DB location still exits 0" "0" "$status"
}

test_pre_compact() {
    run_hook PreCompact pre "$WORK/fixtures/one.jsonl"
    check "PreCompact leaves real_pre_tokens NULL" "" "$(row pre real_pre_tokens)"
    check "PreCompact payload is stored untouched" "" "$(row pre "json_extract(raw_json, '$._diag')")"
}

write_fixtures
test_post_compact
test_pre_compact
test_locked_db
test_unwritable_db

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
