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
    {
        boundary 2026-11-08T18:15:20.622Z 164657 31842
        echo '{"type":"user","message":{"content":"more"}}'
        boundary 2026-11-08T18:41:21.008Z 162020 35932
    } >"$dir/two.jsonl"
    # A record that only quotes the marker inside a string must not count as a boundary.
    {
        echo '{"type":"api-request-blob","message":"saw \"compact_boundary\" in text"}'
        boundary 2026-11-09T02:23:00.276Z 252086 39415
    } >"$dir/quoted.jsonl"
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
    check "boundary fills real_pre_tokens" "252086" "$(row one real_pre_tokens)"
    check "boundary fills real_post_tokens" "39415" "$(row one real_post_tokens)"
    check "diag counts the boundary" "1" "$(row one "json_extract(raw_json, '$._diag.boundary_count')")"
    check "diag keeps the boundary timestamp" "2026-11-09T02:23:00.276Z" \
        "$(row one "json_extract(raw_json, '$._diag.last_boundary.timestamp')")"
    check "diag keeps the boundary preTokens" "252086" \
        "$(row one "json_extract(raw_json, '$._diag.last_boundary.preTokens')")"
    check "diag stamps the hook start" "1" \
        "$(row one "json_extract(raw_json, '$._diag.hook_started_at') GLOB '20??-??-??T??:??:??*Z'")"
    check "payload fields survive beside the diag" "PostCompact" \
        "$(row one "json_extract(raw_json, '$.hook_event_name')")"

    run_hook PostCompact two "$WORK/fixtures/two.jsonl"
    check "last boundary wins" "162020" "$(row two real_pre_tokens)"
    check "diag counts both boundaries" "2" "$(row two "json_extract(raw_json, '$._diag.boundary_count')")"

    run_hook PostCompact quoted "$WORK/fixtures/quoted.jsonl"
    check "quoted marker is not a boundary" "1" "$(row quoted "json_extract(raw_json, '$._diag.boundary_count')")"
}

test_missing_boundary() {
    run_hook PostCompact none "$WORK/fixtures/none.jsonl"
    check "no boundary leaves real_pre_tokens NULL" "" "$(row none real_pre_tokens)"
    check "diag counts zero boundaries" "0" "$(row none "json_extract(raw_json, '$._diag.boundary_count')")"
    check "diag has no last boundary" "null" \
        "$(row none "json_type(raw_json, '$._diag.last_boundary')")"
}

test_pre_compact() {
    run_hook PreCompact pre "$WORK/fixtures/one.jsonl"
    check "PreCompact leaves real_pre_tokens NULL" "" "$(row pre real_pre_tokens)"
    check "PreCompact payload is stored untouched" "" "$(row pre "json_extract(raw_json, '$._diag')")"
}

write_fixtures
test_post_compact
test_missing_boundary
test_pre_compact

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
