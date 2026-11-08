#!/bin/bash
# Checks the status line text claude-statusline.sh prints, including the 7d
# pace delta and its colors. Payloads carry no session_id, so nothing is
# written to a DB; USAGE_DB_DIR points at a temp dir regardless.

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
        USAGE_DB_DIR="$WORK" /bin/bash "$USAGE_DIR/claude-statusline.sh"
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

if ((FAILURES > 0)); then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "All statusline checks passed"
