#!/bin/bash
# Checks the status line text claude-statusline.sh prints, including the 7d
# pace delta, its colors, and the monthly credits segment. Payloads carry no
# session_id, so nothing is written to a DB; USAGE_DB_DIR points at a temp dir
# regardless. Credits fixtures are written into that temp dir, never read from
# the real ~/.claude.json, and CREDITS_NOW pins the clock.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0
YELLOW=$'\033[33m'
RED=$'\033[31m'
GREEN=$'\033[32m'
RESET=$'\033[0m'
DAY=86400
# The extra 30 minutes keeps the rendered "(6d 0h)" and "(3d 0h)" stable while the clock
# moves a few seconds between building the payload and the script reading it.
SIX_DAYS_LEFT=$((6 * DAY + 1800))
THREE_DAYS_LEFT=$((3 * DAY + 1800))
# Mid-November in Chicago, so the calendar month runs Nov 1 to Dec 1 and 15d 12h remain.
FIXED_NOW="$(TZ=UTC /bin/date -j -f '%Y-%m-%d %H:%M:%S' '2026-11-15 18:00:00' +%s)"
ENTERPRISE_EXTRA='{"is_enabled": true, "used_credits": 5446, "monthly_limit": 20000,
    "decimal_places": 2}'
DISABLED_EXTRA='{"is_enabled": false, "used_credits": 5446, "monthly_limit": 20000,
    "decimal_places": 2}'
NULL_LIMIT_EXTRA='{"is_enabled": true, "used_credits": 5446, "monthly_limit": null,
    "decimal_places": 2}'

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# $1 is the jq object for .rate_limits, or null to leave it out.
render() {
    jq --null-input --compact-output --argjson rate_limits "$1" '{
        model: {display_name: "Opus 5.5"},
        effort: {level: "medium"},
        context_window: {used_percentage: 9}
    } + (if $rate_limits == null then {} else {rate_limits: $rate_limits} end)' |
        USAGE_DB_DIR="$WORK" USAGE_CLAUDE_JSON="${CREDITS_FIXTURE:-$WORK/absent.json}" \
            USAGE_NOW_EPOCH="${CREDITS_NOW:-}" /bin/bash "$USAGE_DIR/claude-statusline.sh"
}

# $1 is the extra_usage object, $2 the cache fetchedAtMs.
credits_fixture() {
    jq --null-input --argjson extra "$1" --argjson fetched "$2" '{
        cachedUsageUtilization: {fetchedAtMs: $fetched, utilization: {extra_usage: $extra}}
    }' >"$WORK/claude.json"
}

# $1 is the extra_usage object, $2 the cache fetchedAtMs, $3 the payload rate_limits.
credits_render() {
    credits_fixture "$1" "$2"
    CREDITS_FIXTURE="$WORK/claude.json" CREDITS_NOW="$FIXED_NOW" render "$3"
}

# $1 is the 7d used percentage, $2 the seconds until the 7d window resets.
seven_day() {
    printf '{"seven_day": {"used_percentage": %s, "resets_at": %s}}' \
        "$1" "$(($(date +%s) + $2))"
}

line() {
    printf 'Opus 5.5 | 5h ?%% | %s | 9%% ctx | effort:medium' "$1"
}

check "on pace is uncolored" \
    "$(line '7d 15% (6d 0h) +1')" "$(render "$(seven_day 15 "$SIX_DAYS_LEFT")")"
check "yellow at the +10 threshold" \
    "$(line "${YELLOW}7d 24% (6d 0h) +10${RESET}")" "$(render "$(seven_day 24 "$SIX_DAYS_LEFT")")"
check "yellow below red" \
    "$(line "${YELLOW}7d 26% (6d 0h) +12${RESET}")" "$(render "$(seven_day 26 "$SIX_DAYS_LEFT")")"
check "red at +20 and above" \
    "$(line "${RED}7d 40% (6d 0h) +26${RESET}")" "$(render "$(seven_day 40 "$SIX_DAYS_LEFT")")"
check "green with room to ramp" \
    "$(line "${GREEN}7d 15% (3d 0h) -42${RESET}")" "$(render "$(seven_day 15 "$THREE_DAYS_LEFT")")"
check "just short of green is uncolored" \
    "$(line '7d 43% (3d 0h) -14')" "$(render "$(seven_day 43 "$THREE_DAYS_LEFT")")"
check "fractional usage rounds" \
    "$(line '7d 15% (6d 0h) +1')" "$(render "$(seven_day 14.6 "$SIX_DAYS_LEFT")")"
check "no resets_at, no delta" \
    "$(line '7d 15%')" "$(render '{"seven_day": {"used_percentage": 15}}')"
check "no rate_limits falls back to cost" \
    "Opus 5.5 | \$0.00 | 9% ctx | effort:medium" "$(render null)"

COST_ONLY="Opus 5.5 | \$0.00 | 9% ctx | effort:medium"
CREDITS_SEGMENT="${GREEN}usage 27% (15d 12h) -21${RESET}"
CREDITS_FRESH=$((FIXED_NOW * 1000))
check "month segment sits between cost and context" \
    "Opus 5.5 | \$0.00 | $CREDITS_SEGMENT | 9% ctx | effort:medium" \
    "$(credits_render "$ENTERPRISE_EXTRA" "$CREDITS_FRESH" null)"
check "month segment shows for a cache 20 minutes old" \
    "Opus 5.5 | \$0.00 | $CREDITS_SEGMENT | 9% ctx | effort:medium" \
    "$(credits_render "$ENTERPRISE_EXTRA" "$(((FIXED_NOW - 1200) * 1000))" null)"
check "cache from before this month is hidden" \
    "$COST_ONLY" "$(credits_render "$ENTERPRISE_EXTRA" "$(((FIXED_NOW - 20 * DAY) * 1000))" null)"
check "disabled credits are hidden" \
    "$COST_ONLY" "$(credits_render "$DISABLED_EXTRA" "$CREDITS_FRESH" null)"
check "present rate_limits without percentages hides credits" \
    "$COST_ONLY" "$(credits_render "$ENTERPRISE_EXTRA" "$CREDITS_FRESH" '{}')"
check "null monthly_limit hides credits" \
    "$COST_ONLY" "$(credits_render "$NULL_LIMIT_EXTRA" "$CREDITS_FRESH" null)"
check "missing config hides credits" \
    "$COST_ONLY" "$(CREDITS_FIXTURE="$WORK/none.json" CREDITS_NOW="$FIXED_NOW" render null)"
printf '{not json' >"$WORK/claude.json"
check "malformed config hides credits" \
    "$COST_ONLY" "$(CREDITS_FIXTURE="$WORK/claude.json" CREDITS_NOW="$FIXED_NOW" render null)"

LOCK_DB_DIR="$WORK/locked"
LOCK_DB="$LOCK_DB_DIR/usage.db"
# Pins the pace delta to nothing so the line depends only on the payload's own fields.
SESSION_PAYLOAD='{"session_id": "lock-test", "model": {"display_name": "Opus 5.5"},
    "effort": {"level": "medium"}, "context_window": {"used_percentage": 9},
    "cost": {"total_cost_usd": 1.5}, "transcript_path": "/nonexistent.jsonl", "tasks": []}'

# $1 is the script, $2 the payload. Leaves stdout in $WORK/out and stderr in $WORK/err, and sets
# RUN_STATUS and RUN_SECONDS.
run_script() {
    local started=$SECONDS
    RUN_STATUS=0
    USAGE_DB_DIR="$LOCK_DB_DIR" /bin/bash "$USAGE_DIR/$1" <<<"$2" >"$WORK/out" 2>"$WORK/err" ||
        RUN_STATUS=$?
    RUN_SECONDS=$((SECONDS - started))
}

# Holds SQLite's exclusive lock until release_write_lock, so readers wait too.
hold_write_lock() {
    { printf 'BEGIN EXCLUSIVE;\n' && sleep 30; } | sqlite3 "$LOCK_DB" >/dev/null 2>&1 &
    LOCK_PID=$!
    sleep 1
}

release_write_lock() {
    kill "$LOCK_PID" 2>/dev/null || true
    wait "$LOCK_PID" 2>/dev/null || true
}

mkdir -p "$LOCK_DB_DIR"
run_script claude-statusline.sh "$SESSION_PAYLOAD"
UNLOCKED_LINE="$(cat "$WORK/out")"
check "unlocked render exits 0" "0" "$RUN_STATUS"
check "unlocked render writes the session row" "1" \
    "$(sqlite3 "$LOCK_DB" "SELECT count(*) FROM sessions WHERE session_id = 'lock-test';")"
check "unlocked render writes the cost snapshot" "1" \
    "$(sqlite3 "$LOCK_DB" "SELECT count(*) FROM cost_snapshots WHERE session_id = 'lock-test';")"

hold_write_lock
run_script claude-statusline.sh "$SESSION_PAYLOAD"
check "locked render exits 0" "0" "$RUN_STATUS"
check "locked render prints the same line" "$UNLOCKED_LINE" "$(cat "$WORK/out")"
check "locked render writes nothing to stderr" "" "$(cat "$WORK/err")"
check "locked render returns within 2 seconds" "yes" "$( ((RUN_SECONDS < 2)) && echo yes || echo no)"
run_script claude-subagent-statusline.sh "$SESSION_PAYLOAD"
check "locked subagent render exits 0" "0" "$RUN_STATUS"
check "locked subagent render prints nothing" "" "$(cat "$WORK/out")"
check "locked subagent render writes nothing to stderr" "" "$(cat "$WORK/err")"
check "locked subagent render returns within 2 seconds" "yes" \
    "$( ((RUN_SECONDS < 2)) && echo yes || echo no)"
release_write_lock

if ((FAILURES > 0)); then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "All statusline checks passed"
