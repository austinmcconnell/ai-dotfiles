#!/bin/bash
# Checks estimate-session-cost.sh output against hand-computed prices from pricing.json.
# Builds a temp usage DB with fixture sessions and snapshots, so the real usage.db is never
# read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export USAGE_DB_DIR="$WORK/db"

# shellcheck disable=SC1091
source "$USAGE_DIR/lib.sh"

FAILURES=0
OUT=""
BASE=""
RC=0
FLAG_LINE="flag:     ratio outside 0.85-1.15 -- estimate and actual disagree, "
FLAG_LINE+="see etc/ai/usage/README.md"
UNPRICED_LINE="warning:  1 of 2 snapshots used a model with no pricing.json entry; "
UNPRICED_LINE+="estimate is incomplete"

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# The estimator's four-line report: session, estimate, actual, ratio.
report() {
    printf "session:  %s\nestimate: \$%s\nactual:   \$%s\nratio:    %s" "$@"
}

# Runs the estimator; sets OUT (stdout and stderr), BASE (OUT without the advisor line, which
# is what the estimator printed before that line existed) and RC.
run_estimator() {
    RC=0
    OUT="$(bash "$USAGE_DIR/estimate-session-cost.sh" "$@" 2>&1)" || RC=$?
    BASE="$(grep -v '^advisor:' <<<"$OUT" || true)"
}

advisor_line() {
    grep '^advisor:' <<<"$OUT" || true
}

# A statusline payload: session, model, Claude Code version, cache TTL, then the four
# current_usage token counts. An empty version or TTL leaves that field out.
payload() {
    jq -cn --arg model "$1" --arg version "$2" --arg ttl "$3" \
        --argjson in "$4" --argjson out "$5" --argjson cw "$6" --argjson cr "$7" '{
            model: {id: $model},
            context_window: {current_usage: {
                input_tokens: $in, output_tokens: $out,
                cache_creation_input_tokens: $cw, cache_read_input_tokens: $cr}}
        }
        + (if $version == "" then {} else {version: $version} end)
        + (if $ttl == "" then {} else {prompt_cache: {ttl: $ttl}} end)'
}

add_session() {
    usage_sql "INSERT INTO sessions (tool, session_id, started_at, updated_at, total_cost_usd)
        VALUES ('claude-code', $(sql_str "$1"), '2026-11-01T00:00:00Z', '2026-11-01T00:00:00Z', $2);"
}

add_snapshot() {
    usage_sql "INSERT INTO cost_snapshots (tool, session_id, occurred_at, raw_json)
        VALUES ('claude-code', $(sql_str "$1"), '2026-11-01T00:00:00Z', $(sql_str "$2"));"
}

set_transcript_path() {
    usage_sql "UPDATE sessions SET raw_json = $(sql_str "$(jq -cn --arg p "$2" \
        '{transcript_path: $p}')") WHERE session_id = $(sql_str "$1");"
}

# One advisor_message iteration. An empty model leaves the field out.
advisor_entry() {
    jq -cn --arg model "$1" --argjson usage "$2" '
        {type: "advisor_message"} + (if $model == "" then {} else {model: $model} end) + $usage'
}

# One assistant transcript record: requestId, Claude Code version, isSidechain, iterations.
# An empty requestId or version leaves that field out.
record() {
    jq -cn --arg id "$1" --arg version "$2" --argjson side "$3" --argjson iterations "$4" '{
        type: "assistant", isSidechain: $side,
        message: {model: "claude-sonnet-5-5",
            usage: {input_tokens: 1, output_tokens: 1, iterations: $iterations}}}
        + (if $id == "" then {} else {requestId: $id} end)
        + (if $version == "" then {} else {version: $version} end)'
}

# Opus 5.5 advisor passes: (100000 * 4.0 + 1000 * 20.0) / 1e6 = 0.42, and a 1h cache write of
# 1000 tokens, 1000 * 4.0 * 2.0 / 1e6 = 0.008. A Sonnet 5.5 pass reading 100000 cached tokens at
# the current 0.05x: 100000 * 2.0 * 0.05 / 1e6 = 0.01.
write_transcripts() {
    local dir="$WORK/transcripts" opus="claude-opus-5-5" sonnet="claude-sonnet-5-5"
    local big_pass pass_042 pass_1h pass_cached
    mkdir -p "$dir"
    big_pass='{"type":"message","input_tokens":5000000,"output_tokens":5000000}'
    pass_042="$(advisor_entry "$opus" '{"input_tokens":100000,"output_tokens":1000}')"
    pass_1h="$(advisor_entry "$opus" '{"cache_creation_input_tokens":1000,
        "cache_creation":{"ephemeral_5m_input_tokens":0,"ephemeral_1h_input_tokens":1000}}')"
    pass_cached="$(advisor_entry "$sonnet" '{"cache_read_input_tokens":100000}')"

    # Priced: a duplicated record, a 1h split, a versioned Sonnet pass, and a malformed last
    # line. Ignored: a message pass, an unknown entry type, a sidechain record, and a request
    # with no iterations.
    {
        record r1 2.1.311 false "[$big_pass,$pass_042,{\"type\":\"future\",\"input_tokens\":9}]"
        record r1 2.1.311 false "[$big_pass,$pass_042,{\"type\":\"future\",\"input_tokens\":9}]"
        record r2 2.1.311 false "[$pass_1h]"
        record r3 2.1.311 false "[$pass_cached]"
        record r4 2.1.311 true "[$pass_042]"
        record r5 2.1.311 false "[]"
        echo '{"type":"assistant","requestId":"r6","message":{"usa'
    } >"$dir/priced.jsonl"

    record r1 2.1.311 false "[]" >"$dir/none.jsonl"

    # Unpriceable: an unknown model, a missing model, and a record with no requestId. A message
    # pass at an unknown model beside a priced advisor pass must not hide the priced one.
    {
        record p1 2.1.311 false \
            "[{\"type\":\"message\",\"model\":\"claude-unknown-9\",\"input_tokens\":1},$pass_042]"
        record p2 2.1.311 false "[$(advisor_entry claude-unknown-9 '{"input_tokens":1}')]"
        record p3 2.1.311 false "[$(advisor_entry '' '{"input_tokens":1}')]"
        record '' 2.1.311 false "[$pass_042]"
    } >"$dir/partial.jsonl"

    # A Sonnet 5.5 cache read needs a version to pick its rate, and this record has none.
    record n1 '' false "[$pass_cached]" >"$dir/no-version.jsonl"
}

write_fixtures() {
    usage_db_init

    # Sonnet 5.5, 5m write: (1000 * 2 + 500 * 10 + 2000 * 2 * 1.25 + 100000 * 2 * 0.05) / 1e6
    # = 0.022. The 1h write: 1000 * 2 * 2.0 / 1e6 = 0.004.
    add_session est-sonnet 0.026
    add_snapshot est-sonnet "$(payload claude-sonnet-5-5 2.1.311 5m 1000 500 2000 100000)"
    add_snapshot est-sonnet "$(payload claude-sonnet-5-5 2.1.311 1h 0 0 1000 0)"

    add_session est-flagged 0.1
    add_snapshot est-flagged "$(payload claude-sonnet-5-5 2.1.311 5m 1000 500 2000 100000)"

    # Cache reads of 100000 at $2/Mtok: 0.1x before 2.1.296 is 0.02, the current 0.05x is 0.01.
    # A row with no version, like one with no prompt_cache, takes the current rates.
    add_session est-version 0.03
    add_snapshot est-version "$(payload claude-sonnet-5-5 2.1.295 5m 0 0 0 100000)"
    add_snapshot est-version "$(payload claude-sonnet-5-5 '' '' 0 0 0 100000)"

    # Haiku 5.5: a prompt of exactly 100000 stays at base rates, 100000 * 0.1 / 1e6 = 0.01.
    # A prompt of 100001 uses the long-context rates, (100001 * 0.5 + 1000 * 2.5) / 1e6 = 0.0525005.
    add_session est-haiku 0.0625005
    add_snapshot est-haiku "$(payload claude-haiku-5-5 2.1.311 5m 100000 0 0 0)"
    add_snapshot est-haiku "$(payload claude-haiku-5-5 2.1.311 5m 100001 1000 0 0)"

    add_session est-unpriced 0.022
    add_snapshot est-unpriced "$(payload claude-sonnet-5-5 2.1.311 5m 1000 500 2000 100000)"
    add_snapshot est-unpriced "$(payload claude-unknown-9 2.1.311 5m 1000 500 0 0)"

    add_session est-zero 0
    add_snapshot est-zero "$(payload claude-sonnet-5-5 2.1.311 5m 1000 0 0 0)"

    add_session est-nocost NULL
    add_snapshot est-nocost "$(payload claude-sonnet-5-5 2.1.311 5m 1000 0 0 0)"

    add_session est-nosnap 1.0

    add_session amb-one 1.0
    add_session amb-two 1.0

    write_advisor_sessions
}

# Sessions with a 0.002 snapshot (1000 * 2.0 / 1e6) and a transcript path, or without one.
add_advisor_session() {
    add_session "$1" "$2"
    add_snapshot "$1" "$(payload claude-sonnet-5-5 2.1.311 5m 1000 0 0 0)"
    if [[ -n "${3:-}" ]]; then
        set_transcript_path "$1" "$3"
    fi
}

write_advisor_sessions() {
    local dir="$WORK/transcripts"
    write_transcripts
    add_advisor_session est-adv-ok 0.002 "$dir/priced.jsonl"
    add_advisor_session est-adv-none 0.002 "$dir/none.jsonl"
    add_advisor_session est-adv-partial 0.002 "$dir/partial.jsonl"
    add_advisor_session est-adv-noversion 0.002 "$dir/no-version.jsonl"
    add_advisor_session est-adv-missing 0.002 "$dir/absent.jsonl"
    add_advisor_session est-adv-zero-actual 0 "$dir/priced.jsonl"
    add_advisor_session est-adv-nopath 0.002
    usage_sql "UPDATE sessions SET raw_json = '{}' WHERE session_id = 'est-adv-nopath';"
    add_advisor_session est-adv-badjson 0.002
    usage_sql "UPDATE sessions SET raw_json = 'not json' WHERE session_id = 'est-adv-badjson';"
}

test_priced_sessions() {
    run_estimator est-sonnet
    check "within band: report" "$(report est-sonnet 0.0260 0.0260 1.00)" "$BASE"
    check "within band: exits 0" 0 "$RC"

    run_estimator est-flagged
    check "outside band: ratio and flag" \
        "$(report est-flagged 0.0220 0.1000 0.22)
$FLAG_LINE" "$BASE"

    run_estimator est-version
    check "cache-read rate follows the payload version" \
        "$(report est-version 0.0300 0.0300 1.00)" "$BASE"

    run_estimator est-haiku
    check "haiku long-context tier is chosen per row" \
        "$(report est-haiku 0.0625 0.0625 1.00)" "$BASE"

    run_estimator est-unpriced
    check "unpriced model is counted and warned about" \
        "$(report est-unpriced 0.0220 0.0220 1.00)
$UNPRICED_LINE" "$BASE"

    run_estimator est-zero
    check "zero actual cost reports the ratio as n/a" \
        "$(report est-zero 0.0020 0.0000 "n/a (actual cost is \$0)")" "$BASE"
}

test_advisor_line() {
    run_estimator est-adv-ok
    check "advisor: priced passes, duplicates and ignored entries" \
        "advisor:  \$0.4380 (3 passes)" "$(advisor_line)"
    check "advisor: cost is not added to the estimate" \
        "$(report est-adv-ok 0.0020 0.0020 1.00)" "$BASE"

    run_estimator est-adv-none
    check "advisor: readable transcript with no passes" \
        "advisor:  \$0.0000 (0 passes)" "$(advisor_line)"

    run_estimator est-adv-partial
    check "advisor: unpriceable passes are reported, not dropped" \
        "advisor:  incomplete -- \$0.4200 for 1 pass; 3 passes could not be priced" \
        "$(advisor_line)"
    check "advisor: a partial sum never reaches the report" \
        "$(report est-adv-partial 0.0020 0.0020 1.00)" "$BASE"

    run_estimator est-adv-noversion
    check "advisor: version-dependent rate without a version is unpriced" \
        "advisor:  incomplete -- \$0.0000 for 0 passes; 1 pass could not be priced" \
        "$(advisor_line)"

    run_estimator est-adv-missing
    check "advisor: missing transcript" \
        "advisor:  unavailable (transcript not readable: $WORK/transcripts/absent.jsonl)" \
        "$(advisor_line)"

    for session in est-sonnet est-adv-nopath est-adv-badjson; do
        run_estimator "$session"
        check "advisor: no transcript path ($session)" \
            "advisor:  unavailable (session has no transcript path)" "$(advisor_line)"
    done

    run_estimator est-adv-zero-actual
    check "advisor: zero actual cost still reports the advisor line" \
        "$(report est-adv-zero-actual 0.0020 0.0000 "n/a (actual cost is \$0)")
advisor:  \$0.4380 (3 passes)" "$OUT"
}

test_prefix_matching() {
    run_estimator est-son
    check "unique prefix resolves to the session" "session:  est-sonnet" "$(head -1 <<<"$OUT")"
}

test_refusals() {
    run_estimator no-such-session
    check "no match: message" "No session matches 'no-such-session'" "$OUT"
    check "no match: exits 1" 1 "$RC"

    run_estimator amb
    check "ambiguous prefix: message" \
        "$(printf "Ambiguous prefix 'amb', matches:\namb-one\namb-two")" "$OUT"
    check "ambiguous prefix: exits 1" 1 "$RC"

    run_estimator est-nocost
    check "session without a total cost: message" \
        "Session est-nocost has no recorded total_cost_usd" "$OUT"
    check "session without a total cost: exits 1" 1 "$RC"

    run_estimator est-nosnap
    check "session without snapshots: message" \
        "Session est-nosnap has no cost_snapshots rows to estimate from" "$OUT"
    check "session without snapshots: exits 1" 1 "$RC"
}

write_fixtures
test_priced_sessions
test_advisor_line
test_prefix_matching
test_refusals

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
