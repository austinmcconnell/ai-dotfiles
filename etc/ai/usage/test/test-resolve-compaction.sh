#!/bin/bash
# Checks how usage_resolve_compaction_boundaries and resolve-compaction-boundaries.sh pair
# PostCompact rows with compact_boundary records. Builds synthetic transcripts and a temp usage DB,
# so the real ~/.claude and usage.db are never read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
SCRIPT="$USAGE_DIR/resolve-compaction-boundaries.sh"
WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null || true; rm -rf "$WORK"' EXIT
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

# One compact_boundary record: $1 timestamp, $2 preTokens, $3 postTokens or "null", $4 uuid.
boundary() {
    jq -cn --arg ts "$1" --argjson pre "$2" --argjson post "${3:-null}" --arg uuid "${4:-u-$1}" '{
        type: "system", subtype: "compact_boundary", timestamp: $ts, uuid: $uuid,
        compactMetadata: {trigger: "auto", preTokens: $pre, postTokens: $post,
            cumulativeDroppedTokens: 100, durationMs: 15}
    }'
}

# Starts each case from an empty DB and a fresh transcript directory.
new_case() {
    rm -rf "$WORK/db" "$WORK/t"
    mkdir -p "$WORK/t"
    usage_db_init
}

# $1 session, $2 event, $3 occurred_at, $4 transcript path, $5 stored real_pre_tokens or "".
add_row() {
    local payload
    payload="$(jq -cn --arg path "$4" '{transcript_path: $path}')"
    usage_sql "INSERT INTO compaction_events (tool, session_id, hook_event, occurred_at,
        real_pre_tokens, raw_json) VALUES ('claude-code', '$1', '$2', '$3',
        $(sql_num "$5"), $(sql_str "$payload"));"
}

# The real_pre_tokens column of every row, in id order, "-" for NULL.
pre_tokens() {
    usage_sql "SELECT group_concat(COALESCE(real_pre_tokens, '-'), ' ')
        FROM (SELECT real_pre_tokens FROM compaction_events ORDER BY id);"
}

# $1 is the mode. Leaves the function's status in RESOLVE_STATUS.
resolve() {
    RESOLVE_STATUS=0
    RESOLVE_OUT="$(usage_resolve_compaction_boundaries s1 "${1:-live}" 2>"$WORK/err")" ||
        RESOLVE_STATUS=$?
}

MAIN="$WORK/t/s1.jsonl"

test_pairs_two_rows() {
    new_case
    {
        boundary 2026-11-11T10:00:00.500Z 1000 100
        boundary 2026-11-11T11:00:00.250Z 2000 200
    } >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row s1 PostCompact 2026-11-11T11:00:00Z "$MAIN" ""
    resolve
    check "pairs each row with its own boundary" "1000 2000" "$(pre_tokens)"
    check "copies the other three columns" "100|100|15" "$(usage_sql "SELECT real_post_tokens,
        cumulative_dropped_tokens, duration_ms FROM compaction_events WHERE id = 1;")"
    resolve
    check "second run changes nothing" "1000 2000" "$(pre_tokens)"
}

test_subagent_only_boundary() {
    new_case
    mkdir -p "$WORK/t/s1/subagents"
    echo '{"type":"user"}' >"$MAIN"
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$WORK/t/s1/subagents/agent-a.jsonl"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    resolve
    check "finds a boundary that only a subagent transcript holds" "1000" "$(pre_tokens)"
}

test_duplicate_boundary_counts_once() {
    new_case
    mkdir -p "$WORK/t/s1/subagents"
    boundary 2026-11-11T10:00:00.500Z 1000 100 same-uuid >"$MAIN"
    boundary 2026-11-11T10:00:00.500Z 1000 100 same-uuid >"$WORK/t/s1/subagents/agent-a.jsonl"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    resolve
    check "a boundary in two files with one uuid is not ambiguous" "1000" "$(pre_tokens)"
}

test_live_fills_only_null() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" 777
    resolve
    check "live mode does not overwrite a stored value" "777" "$(pre_tokens)"
    resolve apply
    check "apply mode overwrites a wrong stored value" "1000" "$(pre_tokens)"
}

test_ignored_records() {
    new_case
    {
        echo '{"type":"user","message":{"content":[{"subtype":"compact_boundary","type":"system"}]}}'
        echo '{"type":"assistant","subtype":"compact_boundary","timestamp":"2026-11-11T10:00:00Z"}'
        boundary 2026-11-11T10:00:00.500Z 1000 100
    } >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    resolve
    check "only system boundaries count" "1000" "$(pre_tokens)"
    resolve report
    check "summary counts the rows, boundaries and pairs" "summary|1|1|1" \
        "$(grep '^summary' <<<"$RESOLVE_OUT")"
    check "report mode lists the row as same" "same|1|1000|1000" "$(grep '^same' <<<"$RESOLVE_OUT")"
}

test_outside_window() {
    new_case
    boundary 2026-11-11T10:00:00.000Z 1000 100 >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:06Z "$MAIN" ""
    resolve
    check "a boundary 6 s away is not paired" "-" "$(pre_tokens)"
}

test_ambiguous_burst() {
    new_case
    {
        boundary 2026-11-11T10:00:00.200Z 1000 100
        boundary 2026-11-11T10:00:00.800Z 2000 200
    } >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    resolve apply
    check "two compactions within a second are left alone" "- -" "$(pre_tokens)"
    check "the report names them ambiguous" "2" "$(grep -c '^ambiguous' <<<"$RESOLVE_OUT")"
}

test_unreadable_leaves_session() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" 777
    printf '{"type":"system","subtype":"compact_boundary","timestamp":"2026-11' >>"$MAIN"
    resolve apply
    check "a half-written boundary line skips the session" "3 777" "$RESOLVE_STATUS $(pre_tokens)"

    new_case
    mkdir -p "$WORK/t/s1/subagents"
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    echo x >"$WORK/t/s1/subagents/agent-a.jsonl"
    chmod 000 "$WORK/t/s1/subagents/agent-a.jsonl"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" 777
    resolve apply
    check "an unreadable subagent file skips the session" "3 777" "$RESOLVE_STATUS $(pre_tokens)"

    new_case
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$WORK/t/missing.jsonl" 777
    resolve apply
    check "a missing transcript skips the session" "3 777" "$RESOLVE_STATUS $(pre_tokens)"
}

test_neighbour_value() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    boundary 2026-11-11T11:00:00.500Z 2000 200 >>"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row s1 PostCompact 2026-11-11T11:00:01Z "$MAIN" 1000
    add_row s1 PostCompact 2026-11-11T12:00:00Z "$MAIN" 555
    add_row s1 PostCompact 2026-11-11T13:00:00Z "$MAIN" ""
    resolve
    check "live mode only fills the NULL row it can pair" "1000 1000 555 -" "$(pre_tokens)"
    resolve apply
    check "apply corrects a paired row, keeps an unrelated value" "1000 2000 555 -" "$(pre_tokens)"

    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    boundary 2026-11-11T11:00:00.500Z 2000 200 >>"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row s1 PostCompact 2026-11-11T12:00:00Z "$MAIN" 1000
    resolve apply
    check "apply clears an unmatched row holding another boundary's value" "1000 -" "$(pre_tokens)"
}

test_partial_metadata() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 null >"$MAIN"
    jq -cn '{type: "system", subtype: "compact_boundary", uuid: "no-pre",
        timestamp: "2026-11-11T11:00:00.500Z", compactMetadata: {postTokens: 5}}' >>"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    usage_sql "UPDATE compaction_events SET real_post_tokens = 42 WHERE id = 1;"
    add_row s1 PostCompact 2026-11-11T11:00:01Z "$MAIN" ""
    resolve
    check "an absent postTokens leaves that column alone" "1000|42" \
        "$(usage_sql "SELECT real_pre_tokens, real_post_tokens FROM compaction_events WHERE id = 1;")"
    check "a boundary without preTokens is not a candidate" "1000 -" "$(pre_tokens)"
}

test_other_rows_untouched() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    add_row s1 PreCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row other PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    resolve apply
    check "PreCompact and other sessions' rows are untouched" "- -" "$(pre_tokens)"
}

test_concurrent_resolvers() {
    new_case
    {
        boundary 2026-11-11T10:00:00.500Z 1000 100
        boundary 2026-11-11T11:00:00.500Z 2000 200
    } >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" ""
    add_row s1 PostCompact 2026-11-11T11:00:01Z "$MAIN" ""
    local pids=() pid
    for _ in 1 2 3; do
        usage_resolve_compaction_boundaries s1 live >/dev/null 2>&1 &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    check "simultaneous resolvers leave the single correct result" "1000 2000" "$(pre_tokens)"
}

test_script() {
    new_case
    boundary 2026-11-11T10:00:00.500Z 1000 100 >"$MAIN"
    add_row s1 PostCompact 2026-11-11T10:00:01Z "$MAIN" 777
    bash "$SCRIPT" >/dev/null 2>"$WORK/err"
    check "dry run writes nothing" "777" "$(pre_tokens)"
    check "dry run reports the correction" "1" "$(grep -c 'correct|1|777|1000' "$WORK/err")"
    check "dry run makes no backup" "0" "$(find "$WORK/db" -name 'usage.db.bak-*' | wc -l | tr -d ' ')"
    bash "$SCRIPT" --apply s1 >/dev/null 2>"$WORK/err"
    check "apply writes the correction" "1000" "$(pre_tokens)"
    check "apply makes one backup" "1" "$(find "$WORK/db" -name 'usage.db.bak-resolve-*' | wc -l | tr -d ' ')"
    bash "$SCRIPT" --apply >/dev/null 2>"$WORK/err"
    check "a second apply writes nothing" "1" "$(grep -c 'nothing to write' "$WORK/err")"
    check "a second apply makes no new backup" "1" \
        "$(find "$WORK/db" -name 'usage.db.bak-resolve-*' | wc -l | tr -d ' ')"
    usage_sql "UPDATE compaction_events SET real_pre_tokens = NULL;"
    check "live mode is silent" "" "$(bash "$SCRIPT" --live s1 2>&1)"
    check "live mode fills the row" "1000" "$(pre_tokens)"
    usage_sql "UPDATE compaction_events SET real_pre_tokens = 777;"
    bash "$SCRIPT" --live s1
    check "live mode keeps a stored value" "777" "$(pre_tokens)"
    check "live mode needs a session id" "2" "$(bash "$SCRIPT" --live >/dev/null 2>&1 || echo $?)"
    check "an unknown flag is refused" "2" "$(bash "$SCRIPT" --bogus >/dev/null 2>&1 || echo $?)"
}

test_pairs_two_rows
test_subagent_only_boundary
test_duplicate_boundary_counts_once
test_live_fills_only_null
test_ignored_records
test_outside_window
test_ambiguous_burst
test_unreadable_leaves_session
test_neighbour_value
test_partial_metadata
test_other_rows_untouched
test_concurrent_resolvers
test_script

if ((FAILURES > 0)); then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
