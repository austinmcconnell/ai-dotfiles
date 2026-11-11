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

# Runs the estimator; sets OUT (stdout and stderr) and RC.
run_estimator() {
    RC=0
    OUT="$(bash "$USAGE_DIR/estimate-session-cost.sh" "$@" 2>&1)" || RC=$?
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
}

test_priced_sessions() {
    run_estimator est-sonnet
    check "within band: report" "$(report est-sonnet 0.0260 0.0260 1.00)" "$OUT"
    check "within band: exits 0" 0 "$RC"

    run_estimator est-flagged
    check "outside band: ratio and flag" \
        "$(report est-flagged 0.0220 0.1000 0.22)
$FLAG_LINE" "$OUT"

    run_estimator est-version
    check "cache-read rate follows the payload version" \
        "$(report est-version 0.0300 0.0300 1.00)" "$OUT"

    run_estimator est-haiku
    check "haiku long-context tier is chosen per row" \
        "$(report est-haiku 0.0625 0.0625 1.00)" "$OUT"

    run_estimator est-unpriced
    check "unpriced model is counted and warned about" \
        "$(report est-unpriced 0.0220 0.0220 1.00)
$UNPRICED_LINE" "$OUT"

    run_estimator est-zero
    check "zero actual cost reports the ratio as n/a" \
        "$(report est-zero 0.0020 0.0000 "n/a (actual cost is \$0)")" "$OUT"
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
test_prefix_matching
test_refusals

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
