#!/bin/bash
# Runs every bin/ai-usage report against a temp usage DB built from schema.sql, so a
# report whose SQL no longer matches the schema fails here. The real usage.db is never
# read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
AI_USAGE="$USAGE_DIR/../../../bin/ai-usage"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
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
check "empty by-model" 0 "No sessions recorded yet." -- --by-model
check "empty by-effort" 0 "No sessions recorded yet." -- --by-effort
check "empty rate-limits" 0 "No rate-limit data recorded yet" -- --rate-limits

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
check "seeded by-model" 0 "claude-sonnet-5-5" -- --by-model
check "seeded by-effort" 0 "medium" -- --by-effort
check "seeded rate-limits" 0 "42%" -- --rate-limits

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
