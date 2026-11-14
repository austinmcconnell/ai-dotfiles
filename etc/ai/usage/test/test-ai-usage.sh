#!/bin/bash
# Runs every bin/ai-usage report against a temp usage DB built from schema.sql, so a
# report whose SQL no longer matches the schema fails here. The real usage.db is never
# read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
AI_USAGE="$USAGE_DIR/../../../bin/ai-usage"
WORK="$(mktemp -d)"
# /bin/bash 3.2 exits 0 when set -u aborts a script that has an EXIT trap, so the trap
# fails any run that stopped before the summary.
SUMMARY_REACHED=false
trap 'rm -rf "$WORK"; [[ "$SUMMARY_REACHED" == true ]] || exit 1' EXIT
export USAGE_DB_DIR="$WORK/db"

# shellcheck disable=SC1091
source "$USAGE_DIR/lib.sh"

FAILURES=0

# Usage: check <name> <expected-exit> <expected-substring> -- <ai-usage args...>
check() {
    local name="$1" expected_rc="$2" expected_text="$3" output rc=0
    shift 4
    output="$("$AI_USAGE" "$@" 2>&1)" || rc=$?
    if [[ "$rc" -ne "$expected_rc" ]]; then
        printf 'FAIL  %s: expected exit %s, got %s\n%s\n' "$name" "$expected_rc" "$rc" "$output"
        FAILURES=$((FAILURES + 1))
    elif [[ "$output" != *"$expected_text"* ]]; then
        printf 'FAIL  %s: output lacks [%s]\n%s\n' "$name" "$expected_text" "$output"
        FAILURES=$((FAILURES + 1))
    else
        echo "ok    $name"
    fi
}

check "missing DB exits 0" 0 "No usage data yet" -- --summary
check "unknown flag exits 1" 1 "Usage:" -- --bogus

usage_db_init
check "empty summary" 0 "No sessions recorded yet." -- --summary
check "empty by-model" 0 "No cost snapshots recorded yet." -- --by-model
check "empty by-effort" 0 "No cost snapshots recorded yet." -- --by-effort
check "empty rate-limits" 0 "No rate-limit data recorded yet" -- --rate-limits
check "empty subagents" 0 "No subagent tasks recorded yet" -- --subagents

# shellcheck disable=SC2153 # USAGE_DB is set by lib.sh
sqlite3 "$USAGE_DB" "
    INSERT INTO sessions (tool, session_id, model, effort, started_at, updated_at,
        total_cost_usd, input_tokens, output_tokens)
    VALUES ('claude-code', 's1', 'claude-sonnet-5-5', 'medium',
        '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z', 1.25, 100, 50);
    INSERT INTO rate_limit_snapshots (tool, five_hour_used_percentage,
        seven_day_used_percentage, occurred_at)
    VALUES ('claude-code', 42, 7, '2026-01-01T00:00:00Z');
"
check "seeded summary" 0 "1.25" -- --summary
# sessions.input_tokens/output_tokens hold the latest call only, so a sum measures nothing.
summary_output="$("$AI_USAGE" --summary 2>&1)"
if [[ "$summary_output" == *input_tokens* ]]; then
    echo "FAIL  summary sums non-cumulative session token columns"
    FAILURES=$((FAILURES + 1))
else
    echo "ok    summary has no session token sums"
fi

# Session s1 switches from Sonnet at medium effort to Opus at high, so its 1.25 splits 0.50 and
# 0.75; s2 stays on Sonnet. Each report row is model, [effort,] sessions, cost.
snapshot() {
    printf "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
        VALUES ('claude-code', '%s', %s, '2026-01-01T00:00:00Z',
        '{\"model\":{\"id\":\"%s\"},\"effort\":{\"level\":\"%s\"}}');\n" "$@"
}
sqlite3 "$USAGE_DB" "
    $(snapshot s1 0.50 claude-sonnet-5-5 medium)
    $(snapshot s1 1.25 claude-opus-5-5 high)
    $(snapshot s2 2.00 claude-sonnet-5-5 medium)
    $(snapshot s2 2.00 claude-sonnet-5-5 medium)
"
check_row() {
    local name="$1" pattern="$2" output
    shift 2
    output="$("$AI_USAGE" "$@")"
    if grep -Eq "$pattern" <<<"$output"; then
        echo "ok    $name"
    else
        printf 'FAIL  %s: no row matches [%s]\n%s\n' "$name" "$pattern" "$output"
        FAILURES=$((FAILURES + 1))
    fi
}
check_row "by-model books a session's cost to each model it used" \
    '^claude-opus-5-5 +1 +0\.75 *$' --by-model
check_row "by-model counts distinct sessions and sums their deltas" \
    '^claude-sonnet-5-5 +2 +2\.50 *$' --by-model
check_row "by-effort splits a model switch by effort" \
    '^claude-opus-5-5 +high +1 +0\.75 *$' --by-effort
check_row "by-effort sums a model's cost at one effort" \
    '^claude-sonnet-5-5 +medium +2 +2\.50 *$' --by-effort
check "by-model notes how cost is booked" 0 "main session's model" -- --by-model
check "seeded rate-limits" 0 "42%" -- --rate-limits

# Costs 9.00 and 10.00 sort wrongly if compared as text; the third launch is unpriced with no
# agent type, name, or model.
sqlite3 "$USAGE_DB" "
    INSERT INTO subagent_tasks (tool, parent_session_id, task_id, name, agent_type, model,
        estimated_cost_usd, started_at, updated_at)
    VALUES ('claude-code', 's1', 't1', 'Review nine', 'doubt-reviewer', 'claude-opus-5-5', 9,
        '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'),
        ('claude-code', 's1', 't2', 'Review ten', 'doubt-reviewer', 'claude-opus-5-5', 10,
        '2026-01-02T00:00:00Z', '2026-01-02T00:00:00Z'),
        ('claude-code', 's1', 't3', NULL, NULL, NULL, NULL,
        '2026-01-03T00:00:00Z', '2026-01-03T00:00:00Z');
"
check "seeded subagents sums a type's cost" 0 "19.00" -- --subagents
check "seeded subagents shows an unknown agent type" 0 "(unknown)" -- --subagents
check "seeded subagents shows an unpriced launch" 0 "(unpriced)" -- --subagents
check "seeded subagents shows a launch name" 0 "Review ten" -- --subagents
check "seeded subagents shows an unnamed launch" 0 "(no name)" -- --subagents
check "seeded subagents keeps the cost caveat" 0 "informational only" -- --subagents
check "summary labels dollars as API-equivalent" 0 "API-equivalent" -- --summary

launch_order="$("$AI_USAGE" --subagents | grep -E 'Review (nine|ten)' | sed -E 's/.*(Review [a-z]+).*/\1/')"
if [[ "$launch_order" == $'Review ten\nReview nine' ]]; then
    echo "ok    subagent launches sort by numeric cost"
else
    printf 'FAIL  subagent launches sort by numeric cost: got [%s]\n' "$launch_order"
    FAILURES=$((FAILURES + 1))
fi

# Holds an exclusive lock on the DB for $1 seconds. Unlike a write lock, it blocks readers too.
hold_exclusive_lock() {
    { printf 'BEGIN EXCLUSIVE;\n' && sleep "$1"; } 2>/dev/null | sqlite3 "$USAGE_DB" >/dev/null 2>&1 &
    LOCK_PID=$!
    sleep 0.5
}

hold_exclusive_lock 2
started=$SECONDS
check "a report waits out a short lock" 0 "claude-sonnet-5-5" -- --by-model
if ((SECONDS - started >= 1)); then
    echo "ok    a report actually waited for the lock"
else
    echo "FAIL  a report actually waited for the lock: returned in under a second"
    FAILURES=$((FAILURES + 1))
fi
wait "$LOCK_PID" 2>/dev/null || true

hold_exclusive_lock 7
started=$SECONDS
rc=0
output="$("$AI_USAGE" --by-model 2>&1)" || rc=$?
waited=$((SECONDS - started))
kill "$LOCK_PID" 2>/dev/null || true
wait "$LOCK_PID" 2>/dev/null || true
if ((rc != 0 && waited >= 4)) && [[ "$output" == *"database is locked"* ]]; then
    echo "ok    a report fails after the timeout when the lock outlasts it"
else
    printf 'FAIL  a report fails after the timeout: exit %s after %ss\n%s\n' "$rc" "$waited" "$output"
    FAILURES=$((FAILURES + 1))
fi

SUMMARY_REACHED=true
if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
