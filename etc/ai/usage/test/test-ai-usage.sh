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
# --html writes under XDG_CACHE_HOME and formats local time; pin both, and the clock.
export XDG_CACHE_HOME="$WORK/cache"
export TZ=America/Chicago
REPORT="$XDG_CACHE_HOME/ai-usage/report.html"

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

# Epochs come from sqlite, since BSD and GNU date disagree on parsing flags.
epoch() {
    sqlite3 :memory: "SELECT CAST(strftime('%s', '$1') AS INTEGER);"
}
export USAGE_NOW_EPOCH
USAGE_NOW_EPOCH="$(epoch '2026-01-02 18:00:00')"

# Usage: check_page <name> present|absent <substring>, against the last rendered report.
check_page() {
    local name="$1" want="$2" text="$3" found=absent
    [[ "$(cat "$REPORT")" == *"$text"* ]] && found=present
    if [[ "$found" == "$want" ]]; then
        echo "ok    $name"
    else
        printf 'FAIL  %s: expected [%s] %s in %s\n' "$name" "$text" "$want" "$REPORT"
        FAILURES=$((FAILURES + 1))
    fi
}

check "missing DB exits 0" 0 "No usage data yet" -- --summary
check "html with a missing DB exits 0" 0 "No usage data yet" -- --html --no-open
check "unknown flag exits 1" 1 "Usage:" -- --bogus

usage_db_init
check "empty summary" 0 "No sessions recorded yet." -- --summary
check "empty by-model" 0 "No cost snapshots recorded yet." -- --by-model
check "empty by-effort" 0 "No cost snapshots recorded yet." -- --by-effort
check "empty rate-limits" 0 "No rate-limit data recorded yet" -- --rate-limits
check "empty subagents" 0 "No subagent tasks recorded yet" -- --subagents
rm -f "$REPORT"
check "empty html" 0 "$REPORT" -- --html --no-open
check_page "html names a machine with no quota data" present "No quota data on this machine"
check_page "html charts nothing without quota data" absent "How has 7-day usage"
check_page "html names an empty cost chart" present "No cost is recorded yet this month."
check_page "html names an empty subagent table" present \
    "No subagent launch is recorded yet this month."
check_page "html does not name a 31-day window without cost" absent "last 31 days"

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

check "html rejects an unknown option" 1 "unknown option --bogus" -- --html --no-open --bogus
# Each render first removes the last page, so check_page never reads a stale one.
rm -f "$REPORT"
check "html prints the report path" 0 "$REPORT" -- --html --no-open
csp="default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none';"
csp+=" form-action 'none'"
check_page "html sets the full CSP" present "Content-Security-Policy\" content=\"$csp\""
check_page "html has no script" absent "<script"
check_page "html shows generated-at in local time" present "Generated 2026-01-02 12:00:00 (UTC−6)"
check_page "html lists page caveats" present "Quota is account-wide"

# The page wraps hyphenated ids, dates, and amounts in a no-wrap span.
nw() { printf '<span class="nw">%s</span>' "$1"; }

# Model ids reach the page as series labels; a hostile one must render inert. It costs the
# most, so it keeps its own series while the two cheapest models share Other.
hostile='</script><!--&"'
cost_row() {
    printf "('claude-code', '%s', %s, '2026-01-02T00:00:00Z', %s)" "$1" "$2" "$(sql_str "$3")"
}
sqlite3 "$USAGE_DB" "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at,
    raw_json) VALUES $(cost_row hostile 5 "$(jq -nc --arg id "$hostile" '{model: {id: $id}}')"),
    $(cost_row no-model 0.10 '{}'), $(cost_row haiku 0.05 '{"model":{"id":"claude-haiku-5-5"}}');"
# An unpriced launch inside the window with a hostile name, and a priced one before the window.
sqlite3 "$USAGE_DB" "INSERT INTO subagent_tasks (tool, parent_session_id, task_id, name,
        estimated_cost_usd, started_at, updated_at)
    VALUES ('claude-code', 's1', 't4', $(sql_str "$hostile"), NULL, '2026-01-02T01:00:00Z',
        '2026-01-02T01:00:00Z'),
        ('claude-code', 's1', 't5', 'Old review', 50, '2025-11-01T00:00:00Z',
        '2025-11-01T00:00:00Z');"
rm -f "$REPORT"
check "html renders a seeded DB" 0 "$REPORT" -- --html --no-open
check_page "html escapes a hostile model id" present "&lt;/script&gt;&lt;!--&amp;&quot;"
check_page "html never emits a hostile model id raw" absent "$hostile"
check_page "html shows a missing model as (unknown)" present "(unknown)"
check_page "html never renders null" absent "null"
check_page "html folds models past the fourth into Other" present "<th scope=\"col\">Other</th>"
# s1 and s2 cost 3.25 on 2025-12-31 local time; the other three 5.15 on 2026-01-01.
check_page "html books a day's cost per model" present \
    "2025-12-31</span></th><td></td><td>\$2.50</td><td>\$0.75</td><td></td><td>\$3.25</td>"
check_page "html fills a day with no cost" present \
    "2026-01-02</span></th><td></td><td></td><td></td><td></td><td>\$0.00</td>"
check_page "html scales the cost axis to a 1-2-5 step" present ">\$8</text>"
check_page "html leaves a 2px gap under each upper segment" present \
    '<rect class="s3" x="84.2" y="140.6" width="131.6" height="18.6">'
check_page "html stacks the grey Other on top" present \
    '<rect class="s4" x="272.2" y="88.4" width="131.6" height="2.1">'
check_page "html labels API-rate dollars" present "Dollars are at API rates."
check_page "html never calls cost spend" absent "spend"
# The seeded DB has quota rows, so the page shows the quota tiles and no cost pace.
check_page "html keeps the quota heading when quota rows exist" present \
    "Am I on pace to run out of quota?"
check_page "html shows no cost pace beside quota tiles" absent "How fast is cost building up?"
check_page "html keeps the 31-day wording beside quota tiles" present "for up to 31 days."
check_page "html does not word the daily chart for the month beside quota tiles" absent \
    "yet this month"
check_page "html shows no month cost chart beside the quota burn-up" absent \
    "How has cost built up this month?"
check_page "html lists the costliest session first" present \
    "Cost at API rates</th></tr></thead><tbody><tr><th scope=\"row\"><code title=\"hostile\">"
check_page "html gives a session its costliest model and last activity" present \
    "<code title=\"s1\">s1</code></th><td>$(nw "2025-12-31") $(nw "18:00")</td>"
check_page "html keeps a model id on one line" present \
    "<td class=\"text\">$(nw "claude-opus-5-5")</td>"
check_page "html shows a session's missing project as (unknown)" present \
    "<td class=\"text\">(unknown)</td><td>$(nw "\$1.25")</td>"
# 9.00 and 10.00 sum to 19.00 per type, not as text; the unpriced launch has no agent type.
check_page "html sums a type's priced launches, costliest first" present \
    "<tr><th scope=\"row\">$(nw "doubt-reviewer")</th><td>2</td><td>0</td><td>$(nw "\$19.00")</td>\
<td class=\"bar-cell\" aria-hidden=\"true\"><span class=\"bar\" style=\"width: 100%\">"
check_page "html lists an unpriced type last, with no bar" present \
    "<tr><th scope=\"row\">$(nw "(unknown)")</th><td>1</td><td>1</td><td>$(nw "(unpriced)")</td>\
<td class=\"bar-cell\" aria-hidden=\"true\"></td></tr></tbody>"
check_page "html never lists launch names" absent "Review ten"
check_page "html leaves out launches outside the window" absent "Old review"
check_page "html leaves out launches after the clock" absent "(no name)"
check_page "html marks launches as partial" present "Partial: subagents that finish quickly"
check_page "html notes API-rate launch estimates" present "Estimates are at API rates."
check_page "html heads API-rate launch estimates" present "Estimate at API rates</th>"
check_page "html titles the cost chart by main-session model" present \
    "What did each day cost, by main-session model?"
check_page "html says a window reopened at the same figure shows Reset" present \
    "a tile can show Reset for a window that has already reopened"
# The seeded rate-limit row has percentages but no reset times.
check_page "html shows a 7d figure with an unknown reset" present \
    "7% used</p><p>Reset time unknown."
check_page "html shows a 5h figure with an unknown reset" present \
    "42% used</p><p>Reset time unknown."

# Usage: rate_row <5h pct> <7d pct> <5h resets_at> <7d resets_at> [<seconds before now>];
# NULL for a missing value. A row is observed at the clock unless an age is given.
rate_row() {
    sqlite3 "$USAGE_DB" "INSERT INTO rate_limit_snapshots (tool, five_hour_used_percentage,
        seven_day_used_percentage, five_hour_resets_at, seven_day_resets_at, occurred_at)
        VALUES ('claude-code', $1, $2, $3, $4,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - ${5:-0})), 'unixepoch'));"
}

# Observed a day ago at 2.5 days in: an even pace was 36%, so 50% then was +14. Pacing that
# figure against the clock instead would read 0, on pace, from data a day old.
rate_row 32 50 $((USAGE_NOW_EPOCH + 4500)) $((USAGE_NOW_EPOCH + 302400)) 86400
rm -f "$REPORT"
check "html renders a day-old figure" 0 "$REPORT" -- --html --no-open
check_page "html paces a figure when it was observed" present "14 points over an even pace"
check_page "html names the yellow level in text" present "level-yellow\">14 points over"
check_page "html dates a day-old observation" present "most recently 2026-01-01 12:00."

# A later cost snapshot that carried the same figure shows it still held at the clock.
sqlite3 "$USAGE_DB" "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at,
    raw_json) VALUES ('claude-code', 's1', 1.25,
    strftime('%Y-%m-%dT%H:%M:%SZ', $USAGE_NOW_EPOCH, 'unixepoch'),
    '{\"rate_limits\":{\"seven_day\":{\"used_percentage\":50,
        \"resets_at\":$((USAGE_NOW_EPOCH + 302400))}}}');"
rm -f "$REPORT"
check "html renders a figure held until the clock" 0 "$REPORT" -- --html --no-open
check_page "html takes the last observation from cost snapshots" present \
    "most recently 2026-01-02 12:00."
check_page "html shows on pace in text" present "level-on\">Level with an even pace"
split="\$1.25 from subscription sessions is an API-equivalent estimate, not money spent;"
check_page "html splits subscription dollars from API-rate dollars" present \
    "$split the other \$7.15 is at API rates."
check_page "html notes launch estimates by their own sessions" present \
    "Their sessions ran on a subscription, so these are API-equivalent estimates"
check_page "html heads subscription launch estimates" present "API-equivalent estimate</th>"

# 3.5 days into the 7d window, so an even pace is 50%. 12.5 rounds to 12 as in the statusline,
# including under a decimal-comma locale. The earlier 50% row is cleared: a lower figure in the
# same window would read as a stale report.
sqlite3 "$USAGE_DB" "DELETE FROM rate_limit_snapshots;"
rate_row 30 12.5 $((USAGE_NOW_EPOCH + 4500)) $((USAGE_NOW_EPOCH + 302400))
rm -f "$REPORT"
LC_ALL=de_DE.UTF-8 check "html renders open windows" 0 "$REPORT" -- --html --no-open
check_page "html rounds a 7d half like the statusline" present "12% used"
check_page "html shows the 7d reset in local time" present "Resets 2026-01-06 00:00, 3d 12h left"
check_page "html dates relative figures" present "left as of 2026-01-02 12:00:00."
check_page "html shows 7d pace with room" present "38 points under an even pace"
check_page "html names the room-to-ramp level" present "level-green"
check_page "html shows the 5h reset" present "Resets 2026-01-02 13:15, 1h 15m left"
check_page "html dates the last observation" present "most recently 2026-01-02 12:00."
if [[ "$(grep -o 'an even pace when' "$REPORT" | wc -l | tr -d ' ')" == 1 ]]; then
    echo "ok    html gives the 5h window no pace"
else
    echo "FAIL  html gives the 5h window no pace"
    FAILURES=$((FAILURES + 1))
fi

rate_row 31 80 $((USAGE_NOW_EPOCH + 4500)) $((USAGE_NOW_EPOCH + 302400))
rm -f "$REPORT"
check "html renders a tight 7d window" 0 "$REPORT" -- --html --no-open
check_page "html shows 7d pace over" present "30 points over an even pace"
check_page "html names the red level in text" present "well over pace"

# The 5h window resets exactly at the clock, which counts as closed. The newest row of each
# closed window is lower than the one before it, so the tiles keep the higher figures.
rate_row 35 65 "$USAGE_NOW_EPOCH" $((USAGE_NOW_EPOCH - 3600)) 60
rate_row 34 60 "$USAGE_NOW_EPOCH" $((USAGE_NOW_EPOCH - 3600))
rm -f "$REPORT"
check "html renders closed windows" 0 "$REPORT" -- --html --no-open
check_page "html shows a closed 7d window" present \
    "Reset at 2026-01-02 11:00. No figure for the new window is recorded here."
check_page "html keeps the window's highest 7d figure as secondary" present \
    "highest figure recorded for that window was 65%."
check_page "html keeps the window's highest 5h figure as secondary" present \
    "highest figure recorded for that window was 35%."
check_page "html closes a window that resets at the clock" present "Reset at 2026-01-02 12:00."
check_page "html gives a closed window no pace" absent "an even pace when"
check_page "html charts no closed window" present "No open 7-day window is recorded"

# A newer payload without the 7d window doesn't hide the older 7d row.
rate_row 20 NULL $((USAGE_NOW_EPOCH + 1800)) NULL
rm -f "$REPORT"
check "html renders a 5h-only row" 0 "$REPORT" -- --html --no-open
check_page "html keeps the 7d tile from the last 7d row" present "for that window was 65%."
check_page "html reads the 5h tile from the 5h-only row" present "20% used"

# The newest row wins even without a reset time.
rate_row 21 70 NULL NULL
rm -f "$REPORT"
check "html renders a row with no reset times" 0 "$REPORT" -- --html --no-open
check_page "html reads an unknown reset from the newest row" present \
    "70% used</p><p>Reset time unknown."

# A machine whose payloads never carried the 5h window.
mkdir -p "$WORK/seven-only"
cp "$USAGE_DB" "$WORK/seven-only/usage.db"
sqlite3 "$WORK/seven-only/usage.db" "DELETE FROM rate_limit_snapshots;
    INSERT INTO rate_limit_snapshots (tool, seven_day_used_percentage, seven_day_resets_at,
    occurred_at) VALUES ('claude-code', 5, $((USAGE_NOW_EPOCH + 3600)), '2026-01-02T18:00:00Z');"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/seven-only" check "html renders 7d data alone" 0 "$REPORT" \
    -- --html --no-open
check_page "html shows a window with no data" present \
    "<p class=\"figure\">No data</p>"

# Burn-up over a window opened 3.5 days before the clock. Each row is [<5h pct>, <7d pct>,
# <7d resets_at>, <seconds before now>]; only rows of the open window with a 7d figure plot.
window_end=$((USAGE_NOW_EPOCH + 302400))
mkdir -p "$WORK/burnup"
cp "$USAGE_DB" "$WORK/burnup/usage.db"
burnup_rows=""
for row in "5 90 $((window_end - 604800)) $((4 * 86400))" "6 10 $window_end $((3 * 86400))" \
    "7 NULL NULL $((2 * 86400))" "8 10 $window_end 129600" "9 30 $window_end 86400"; do
    read -r five seven resets age <<<"$row"
    burnup_rows+="('claude-code', $five, $seven, $resets,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - age)), 'unixepoch')),"
done
sqlite3 "$WORK/burnup/usage.db" "DELETE FROM rate_limit_snapshots; DELETE FROM cost_snapshots;
    INSERT INTO rate_limit_snapshots (tool, five_hour_used_percentage,
        seven_day_used_percentage, seven_day_resets_at, occurred_at) VALUES ${burnup_rows%,};
    INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
    VALUES ('claude-code', 's1', 1, strftime('%Y-%m-%dT%H:%M:%SZ', $USAGE_NOW_EPOCH, 'unixepoch'),
        '{\"rate_limits\":{\"seven_day\":{\"used_percentage\":30,\"resets_at\":$window_end}}}');"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/burnup" check "html renders a burn-up" 0 "$REPORT" -- --html --no-open
# Day 0.5 at 10%, a repeat of 10% that adds no step, day 2.5 at 30%, then held to day 3.5. The
# previous window's 90% and the row without a 7d figure stay off the line.
check_page "html steps the burn-up from the first figure to the last observation" present \
    'd="M81.4,208H247.1V164H330"'
check_page "html draws the even-pace diagonal" present 'x1="40" y1="230" x2="620" y2="10"'
check_page "html marks steps as observed changes" present "Steps mark when this machine observed"
check_page "html labels the burn-up for screen readers" present 'aria-labelledby="burnup-title'
check_page "html labels subscription dollars" present \
    "the dollars are an API-equivalent estimate, not money spent."
check_page "html heads subscription dollars" present "API-equivalent cost</th>"
check_page "html describes subscription dollars to screen readers" present \
    "not money spent. The figures are in the table below.</desc>"
check_page "html labels the burn-up's current figure" present \
    '<text class="end-label" x="336" y="168">30%</text>'

# Another session's stale 20% and 40% after 50% and 60% in the same windows, with no cost
# snapshot after it. The tiles, pace, and line keep the higher figures as last seen an hour
# ago, when an even 7d pace was 49%.
mkdir -p "$WORK/stale"
cp "$USAGE_DB" "$WORK/stale/usage.db"
stale_rows=""
for row in "30 40 7200" "50 60 3600" "20 40 0"; do
    read -r five seven age <<<"$row"
    stale_rows+="('claude-code', $five, $seven, $((USAGE_NOW_EPOCH + 4500)), $window_end,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - age)), 'unixepoch')),"
done
sqlite3 "$WORK/stale/usage.db" "DELETE FROM rate_limit_snapshots; DELETE FROM cost_snapshots;
    INSERT INTO rate_limit_snapshots (tool, five_hour_used_percentage,
        seven_day_used_percentage, five_hour_resets_at, seven_day_resets_at, occurred_at)
    VALUES ${stale_rows%,};"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/stale" check "html renders a stale lower figure" 0 "$REPORT" \
    -- --html --no-open
check_page "html keeps the highest 7d figure over a stale one" present "60% used"
check_page "html keeps the highest 5h figure over a stale one" present "50% used"
check_page "html dates the observation to the highest figure" present \
    "most recently 2026-01-02 11:00."
check_page "html paces the highest figure when it was seen" present \
    "11 points over an even pace"
check_page "html holds the burn-up line over a stale figure" present \
    'd="M323.1,142H326.5V98H326.5"'
check_page "html says each quota figure is the window's highest" present \
    "A quota figure with a reset time is the highest recorded for its window"

# Cost snapshots carrying the 60% figure half an hour ago and the stale 40% ten minutes ago:
# only the first moves the observation.
stale_payload() {
    jq -nc --argjson pct "$1" --argjson resets "$window_end" \
        '{rate_limits: {seven_day: {used_percentage: $pct, resets_at: $resets}}}'
}
sqlite3 "$WORK/stale/usage.db" "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd,
        occurred_at, raw_json)
    VALUES ('claude-code', 'fresh', 1, strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 1800)),
            'unixepoch'), $(sql_str "$(stale_payload 60)")),
        ('claude-code', 'stale', 1, strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 600)),
            'unixepoch'), $(sql_str "$(stale_payload 40)"));"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/stale" check "html renders stale cost snapshots" 0 "$REPORT" \
    -- --html --no-open
check_page "html dates the observation by a payload with the highest figure" present \
    "most recently 2026-01-02 11:30."

# A fourth model alone still folds into Other, so slot 4 always means Other.
mkdir -p "$WORK/four"
cp "$USAGE_DB" "$WORK/four/usage.db"
four_rows=""
for row in "5be12826-7786-4294-a90e-03d9d18cb72b 4 opus" "b 3 sonnet" "c 2 fable" "d 1 haiku"; do
    read -r session usd family <<<"$row"
    four_rows+="$(cost_row "$session" "$usd" "{\"model\":{\"id\":\"claude-$family\"}}"),"
done
# Session b ran on a subscription; the seeded launches' session s1 has no cost here.
sqlite3 "$WORK/four/usage.db" "DELETE FROM cost_snapshots;
    INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
    VALUES ${four_rows%,};
    UPDATE cost_snapshots SET raw_json = json_set(raw_json, '\$.rate_limits', json('{}'))
        WHERE session_id = 'b';
    INSERT INTO subagent_tasks (tool, parent_session_id, task_id, name, estimated_cost_usd,
        started_at, updated_at)
    VALUES ('claude-code', 'b', 't6', 'Subscription review', 1, '2026-01-02T00:00:00Z',
        '2026-01-02T00:00:00Z');"
# Eleven more agent types at 1.00 each: the last three past the top 10 share Other.
type_rows=""
for n in 01 02 03 04 05 06 07 08 09 10 11; do
    type_rows+="('claude-code', 'c', 'type$n', 'type$n', 1, '2026-01-02T00:00:00Z',
        '2026-01-02T00:00:00Z'),"
done
sqlite3 "$WORK/four/usage.db" "INSERT INTO subagent_tasks (tool, parent_session_id, task_id,
    agent_type, estimated_cost_usd, started_at, updated_at) VALUES ${type_rows%,};"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/four" check "html renders four models" 0 "$REPORT" -- --html --no-open
check_page "html shortens a session id, keeping the full id as its title" present \
    "<code title=\"5be12826-7786-4294-a90e-03d9d18cb72b\">5be12826</code>"
check_page "html names at most three models" present \
    "<span class=\"swatch s3\"></span>claude-fable: \$2.00"
check_page "html folds a lone fourth model into Other" present \
    "<span class=\"swatch s4\"></span>Other (claude-haiku): \$1.00"
check_page "html folds agent types past the top 10 into Other" present \
    "<tr><th scope=\"row\">$(nw "Other")</th><td>3</td><td>0</td><td>$(nw "\$3.00")</td>"
check_page "html heads mixed dollars plainly" present "<th scope=\"col\">Cost</th>"
check_page "html notes mixed launch estimates" present \
    "Estimates from subscription sessions are API-equivalent, not money spent"

# Burn-rate scenarios, each on a copy of the seeded DB with its own local clock. A machine with no
# quota rows (Enterprise) has no rate_limits in any payload, so every scenario is API-rate. Rows
# are "<local date> <cost>", one session a day at local noon, so a DST day still buckets to its date.
local_epoch() {
    sqlite3 :memory: "SELECT CAST(strftime('%s', '$1', 'utc') AS INTEGER);"
}
burn_page() {
    local name="$1" now="$2" dir="$WORK/burn" rows="" day usd
    rm -rf "$dir"
    mkdir -p "$dir"
    cp "$USAGE_DB" "$dir/usage.db"
    while read -r day usd; do
        rows+="('claude-code', 'day-$day', $usd,
            strftime('%Y-%m-%dT%H:%M:%SZ', '$day 12:00:00', 'utc'),
            '{\"model\":{\"id\":\"claude-opus-5-5\"}}'),"
    done
    sqlite3 "$dir/usage.db" "DELETE FROM cost_snapshots; DELETE FROM rate_limit_snapshots;
        INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
        VALUES ${rows%,};"
    [[ -z "${BURN_EXTRA_SQL:-}" ]] || sqlite3 "$dir/usage.db" "$BURN_EXTRA_SQL"
    rm -f "$REPORT"
    USAGE_NOW_EPOCH="$(local_epoch "$now")" USAGE_DB_DIR="$dir" check "$name" 0 "$REPORT" \
        -- --html --no-open
}
burn_tile_html() {
    printf '<div class="tile"><h3>%s</h3><p class="figure">%s</p><p>%s</p></div>' "$@"
}
same_cost_days() {
    local month="$1" first="$2" last="$3" usd="$4" day
    for ((day = first; day <= last; day++)); do
        printf '%s-%02d %s\n' "$month" "$day" "$usd"
    done
}
rate_detail() { printf 'Mean of the last %s complete days, not counting today.' "$1"; }
month_detail() { printf 'Local calendar month %s, through today.' "$1"; }
projection_detail() {
    printf 'By %s, if the rate holds. Today counts as at least one day at the rate.' "$1"
}

# 2026-03-18: seven complete days from 03-11 cost 42 with two days at 0, so the rate is 6.00; the
# 50.00 days before them stay out of it. Today's 4.00 is under the rate, so it counts as 6.00 and
# 13 days follow: 142 + 6 + 78.
mid_month() {
    printf '%s\n' "2026-03-09 50" "2026-03-10 50" "2026-03-11 7" "2026-03-13 14" "2026-03-14 7" \
        "2026-03-16 7" "2026-03-17 7" "2026-03-18 $1"
}
burn_page "html renders a burn rate mid-month" "2026-03-18 15:00:00" < <(mid_month 4)
check_page "html averages the 7 complete days before today" present \
    "$(burn_tile_html 'Daily rate' "\$6.00 a day" "$(rate_detail 7)")"
check_page "html books the month to date mid-month" present \
    "$(burn_tile_html 'Month to date' "\$146.00" "$(month_detail 2026-03)")"
check_page "html counts today at the rate when it is under it" present \
    "$(burn_tile_html 'Projected month end' "\$226.00" "$(projection_detail 2026-03-31)")"
check_page "html puts cost pace in the quota section's slot" present \
    "<h2>How fast is cost building up?</h2>"
check_page "html drops the quota heading without quota rows" absent \
    "Am I on pace to run out of quota?"
check_page "html names a machine with no quota data beside cost" present \
    "No quota data on this machine"
check_page "html labels Enterprise-style dollars as API rates" present "Dollars are at API rates."
check_page "html never calls the projection spend" absent "spend"
burn_page "html renders a day that costs more than the rate" "2026-03-18 15:00:00" < <(mid_month 9)
check_page "html counts today at its own cost when over the rate" present \
    "$(burn_tile_html 'Projected month end' "\$229.00" "$(projection_detail 2026-03-31)")"

# 2026-03-18 charts 31 days: the 1st to the 18th solid, then dashed to the 31st. The y axis fits
# the 226.00 projection (four steps of 100), so the solid line ends at 146/400 of the plot height
# and the dashed line at 226/400.
burn_page "html charts the month so far with a projection" "2026-03-18 15:00:00" < <(mid_month 4)
check_page "html puts the month chart in the burn-up slot" present \
    "<h2>How has cost built up this month?</h2>"
check_page "html drops the quota burn-up without quota rows" absent \
    "How has 7-day usage built up this window?"
check_page "html draws the projection as its own dashed path" present \
    '<path class="proj" d="M383.5,149.7L620,105.7"/>'
check_page "html labels the end of the dashed line with the projection" present \
    "text-anchor=\"end\">\$226.00</text>"
check_page "html scales the month axis to the projection" present ">\$400</text>"
check_page "html figures the month day by day" present "<td>\$4.00</td><td>\$146.00</td>"
check_page "html describes the projection in the chart" present \
    "continues from there to a projected \$226.00 on 2026-03-31"

# The daily chart and table show the month, but the rate keeps the whole window's history: on
# 2026-03-02 the seven complete days run back into February, so the rate is still 14.00 a day.
# The month to date is 14 + 2, and 29 days follow: 14 + 14 + 14 * 29.
# Launches start well inside each month so the local boundary cannot move them: one in February,
# one in March.
BURN_EXTRA_SQL="INSERT INTO subagent_tasks (tool, parent_session_id, task_id, name, agent_type,
        estimated_cost_usd, started_at, updated_at)
    VALUES ('claude-code', 'day-2026-02-23', 'feb', 'Feb launch', 'feb-agent', 5,
        '2026-02-26T12:00:00Z', '2026-02-26T12:00:00Z'),
        ('claude-code', 'day-2026-03-01', 'mar', 'Mar launch', 'mar-agent', 7,
        '2026-03-01T18:00:00Z', '2026-03-01T18:00:00Z');" \
    burn_page "html keeps the rate's history across the month boundary" "2026-03-02 15:00:00" <<EOF
2026-02-23 14
2026-02-24 14
2026-02-25 14
2026-02-26 14
2026-02-27 14
2026-02-28 14
2026-03-01 14
2026-03-02 2
EOF
check_page "html still rates the days before the 1st" present \
    "$(burn_tile_html 'Daily rate' "\$14.00 a day" "$(rate_detail 7)")"
check_page "html still projects from the days before the 1st" present \
    "$(burn_tile_html 'Projected month end' "\$434.00" "$(projection_detail 2026-03-31)")"
check_page "html leaves last month out of the daily table" absent \
    "<th scope=\"row\">$(nw "2026-02-28")</th>"
check_page "html words the daily chart for the month" present \
    "from the first day with cost this month."
check_page "html does not call the month 31 days" absent "for up to 31 days."
check_page "html totals the projects for the month only" absent "\$100.00"
check_page "html leaves last month's sessions out of the top sessions" absent \
    "title=\"day-2026-02-28\""
check_page "html keeps this month's sessions in the top sessions" present \
    "title=\"day-2026-03-01\""
check_page "html leaves last month's launches out of the agent types" absent \
    "<th scope=\"row\">$(nw "feb-agent")</th>"
check_page "html keeps this month's launches in the agent types" present \
    "<th scope=\"row\">$(nw "mar-agent")</th>"
check_page "html words the lower sections for the month" present \
    "The costliest sessions this month, counting only their cost this month."

# The 1st before any cost: the chart has nothing to show, and the rate still has its history. The
# nine complete days from 02-20 give a 3.00 rate: 0 + 3 + 3 * 30.
burn_page "html renders the 1st before any cost" "2026-03-01 09:00:00" < <(same_cost_days 2026-02 20 28 3)
check_page "html says no cost is recorded yet this month" present \
    "No cost is recorded yet this month."
check_page "html still projects on the 1st from last month's rate" present \
    "$(burn_tile_html 'Projected month end' "\$93.00" "$(projection_detail 2026-03-31)")"

# 2026-12-31: the 31-day window reaches the 1st, so its 99.00 counts and the month is whole. No
# day follows today, so the projection is 140 + the larger of today's 2.00 and the 3.00 rate.
burn_page "html renders the last day of a 31-day month" "2026-12-31 15:00:00" <<EOF
2026-11-30 500
2026-12-01 99
2026-12-05 10
2026-12-20 10
2026-12-24 7
2026-12-30 14
2026-12-31 2
EOF
check_page "html books the whole month on the 31st" present \
    "$(burn_tile_html 'Month to date' "\$142.00" "$(month_detail 2026-12)")"
check_page "html projects the last day of the month from the rate" present \
    "$(burn_tile_html 'Projected month end' "\$143.00" "$(projection_detail 2026-12-31)")"

# A first cost after the 1st: the month to date starts there, and the rate uses fewer days.
burn_page "html renders a first cost after the 1st" "2026-11-16 15:00:00" <<EOF
2026-11-10 6
2026-11-11 6
2026-11-12 6
2026-11-13 6
2026-11-15 6
EOF
check_page "html uses the days since the first cost when under 7" present \
    "$(burn_tile_html 'Daily rate' "\$5.00 a day" "$(rate_detail 6)")"
check_page "html projects a day with no cost so far at the rate" present \
    "$(burn_tile_html 'Projected month end' "\$105.00" "$(projection_detail 2026-11-30)")"

echo "2026-01-02 3" | burn_page "html renders a single day of cost" "2026-01-02 15:00:00"
check_page "html shows no rate for a first day" present \
    "$(burn_tile_html 'Daily rate' 'Not enough history' 'Needs 3 complete days; 0 so far.')"
check_page "html still books a single day" present \
    "$(burn_tile_html 'Month to date' "\$3.00" "$(month_detail 2026-01)")"
check_page "html draws no projection before there is a rate" absent '<path class="proj"'
check_page "html says why no projection is drawn" present "No projection is drawn"
check_page "html labels the month to date when there is no projection" present \
    "text-anchor=\"end\">\$3.00</text>"

# A leap February ends on the 29th: 19 days follow the 10th.
burn_page "html renders a leap February" "2028-02-10 15:00:00" < <(same_cost_days 2028-02 1 9 2)
check_page "html projects to the 29th of a leap February" present \
    "$(burn_tile_html 'Projected month end' "\$58.00" "$(projection_detail 2028-02-29)")"

# Spring forward on 2026-03-08 makes a 23-hour day; fall back on 2026-11-01 a 25-hour one. Each
# is still one day, and the fall-back window straddles two months.
burn_page "html renders across spring-forward" "2026-03-12 15:00:00" < <(same_cost_days 2026-03 5 11 3)
check_page "html counts a 23-hour day as one day" present \
    "$(burn_tile_html 'Projected month end' "\$81.00" "$(projection_detail 2026-03-31)")"
burn_page "html renders across fall-back" "2026-11-04 15:00:00" <<EOF
2026-10-30 4
2026-10-31 4
2026-11-01 4
2026-11-02 4
2026-11-03 4
EOF
check_page "html counts a 25-hour day as one day" present \
    "$(burn_tile_html 'Daily rate' "\$4.00 a day" "$(rate_detail 5)")"
check_page "html leaves the day before the 1st out of the daily table" absent \
    "<th scope=\"row\">$(nw "2026-10-31")</th>"
check_page "html books only this month to the month to date" present \
    "$(burn_tile_html 'Month to date' "\$12.00" "$(month_detail 2026-11)")"
check_page "html projects across fall-back" present \
    "$(burn_tile_html 'Projected month end' "\$120.00" "$(projection_detail 2026-11-30)")"

# The window is 31 days, so on the 31st of a month it still reaches the 1st; the day before that
# is out. One session a day, at local noon.
mkdir -p "$WORK/window"
cp "$USAGE_DB" "$WORK/window/usage.db"
sqlite3 "$WORK/window/usage.db" "DELETE FROM cost_snapshots;
    INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
    VALUES ('claude-code', 'before', 5,
        strftime('%Y-%m-%dT%H:%M:%SZ', '2026-11-30 12:00:00', 'utc'),
        '{\"model\":{\"id\":\"claude-opus-5-5\"}}'),
        ('claude-code', 'first', 7,
        strftime('%Y-%m-%dT%H:%M:%SZ', '2026-12-01 12:00:00', 'utc'),
        '{\"model\":{\"id\":\"claude-opus-5-5\"}}');"
rm -f "$REPORT"
USAGE_NOW_EPOCH="$(sqlite3 :memory: "SELECT CAST(strftime('%s', '2026-12-31 15:00:00', 'utc')
    AS INTEGER);")" USAGE_DB_DIR="$WORK/window" check "html renders the 31st of a month" 0 \
    "$REPORT" -- --html --no-open
check_page "html reaches the 1st from the 31st" present "$(nw "2026-12-01")"
check_page "html leaves out the day before the 31-day window" absent "$(nw "2026-11-30")"
check_page "html no longer calls the window 30 days" absent "last 30 days"

# A session that began before the 31-day window adds only its in-window step there; sessions
# that began inside it (every other fixture) step from 0. An explicit null rate_limits is not a
# subscription.
mkdir -p "$WORK/straddle"
cp "$USAGE_DB" "$WORK/straddle/usage.db"
sqlite3 "$WORK/straddle/usage.db" "DELETE FROM cost_snapshots;
    INSERT INTO sessions (tool, session_id, started_at, updated_at)
    VALUES ('claude-code', 'old',
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 40 * 86400)), 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ', $USAGE_NOW_EPOCH, 'unixepoch'));
    INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
    VALUES ('claude-code', 'old', 100,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 40 * 86400)), 'unixepoch'),
        '{\"model\":{\"id\":\"claude-opus-5-5\"}}'),
        ('claude-code', 'old', 101,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 3600)), 'unixepoch'),
        '{\"model\":{\"id\":\"claude-opus-5-5\"},\"rate_limits\":null}');"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/straddle" check "html renders a session older than the window" 0 "$REPORT" \
    -- --html --no-open
check_page "html books only the in-window step" present "claude-opus-5-5: \$1.00</li>"
check_page "html never books earlier cost to the window" absent "\$101.00"

check_page "html reads a null rate_limits as API rates" present "Dollars are at API rates."

# The same session with no sessions row still steps from its earlier snapshot.
sqlite3 "$WORK/straddle/usage.db" "DELETE FROM sessions WHERE session_id = 'old';"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/straddle" check "html renders a session with no sessions row" 0 "$REPORT" \
    -- --html --no-open
check_page "html books only the in-window step without a sessions row" present \
    "claude-opus-5-5: \$1.00</li>"

# A payload whose model and project are numbers still renders.
sqlite3 "$WORK/straddle/usage.db" "INSERT INTO cost_snapshots (tool, session_id,
        total_cost_usd, occurred_at, raw_json)
    VALUES ('claude-code', 'numeric', 0.5,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 3600)), 'unixepoch'),
        '{\"model\":{\"id\":42},\"workspace\":{\"project_dir\":7}}');"
rm -f "$REPORT"
USAGE_DB_DIR="$WORK/straddle" check "html renders numeric payload strings" 0 "$REPORT" \
    -- --html --no-open
check_page "html renders a numeric model id" present "42: \$0.50</li>"

# Project paths with a fake HOME and TMPDIR. Each row is <session> <cost> <project_dir>, all on
# Opus an hour before the clock; "-" leaves project_dir out of the payload. Nine projects outside
# the temp directories rank, so the two cheapest fold into Other with the three temp paths.
mkdir -p "$WORK/projects"
cp "$USAGE_DB" "$WORK/projects/usage.db"
project_rows=""
while read -r session cost dir; do
    payload="$(jq -nc --arg dir "$dir" '{model: {id: "claude-opus-5-5"}}
        + if $dir == "-" then {} else {workspace: {project_dir: $dir}} end')"
    project_rows+="('claude-code', '$session', $cost,
        strftime('%Y-%m-%dT%H:%M:%SZ', $((USAGE_NOW_EPOCH - 3600)), 'unixepoch'),
        $(sql_str "$payload")),"
done <<EOF
a1 5 /home/tester/a
a1 10 /home/tester/a
home 1 /home/tester
near 2 /home/testerx/b
hostile 6 /srv/$hostile
none 0.7 -
p1 0.5 /srv/p1
p2 0.5 /srv/p2
p3 0.5 /srv/p3
p4 0.5 /srv/p4
p5 0.5 /srv/p5
tmp 3 /tmp/x
private 4 /private/tmp
tmpdir 5 /var/tmpx/y
realtmp 1 /private/var/tmpx/z
EOF
sqlite3 "$WORK/projects/usage.db" "DELETE FROM cost_snapshots;
    INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at, raw_json)
    VALUES ${project_rows%,};"
rm -f "$REPORT"
HOME=/home/tester TMPDIR=/var/tmpx/ USAGE_DB_DIR="$WORK/projects" \
    check "html renders cost by project" 0 "$REPORT" -- --html --no-open
check_page "html shows a project under HOME with ~" present \
    "<th scope=\"row\">~/<wbr>a</th><td>1</td><td>$(nw "\$10.00")</td>"
check_page "html shows HOME itself as ~" present \
    "<th scope=\"row\">~</th><td>1</td><td>$(nw "\$1.00")</td>"
check_page "html keeps a sibling of HOME whole" present \
    '<th scope="row">/<wbr>home/<wbr>testerx/<wbr>b</th>'
check_page "html escapes a hostile project path" present \
    "/<wbr>srv/<wbr>&lt;/<wbr>script&gt;&lt;!--&amp;&quot;"
check_page "html shows a missing project as (unknown)" present '<th scope="row">(unknown)</th>'
check_page "html folds temp paths and the tail into Other" present \
    "<th scope=\"row\">Other</th><td>6</td><td>$(nw "\$14.00")</td>"
check_page "html never lists a temp path" absent "/tmp/x"
check_page "html folds TMPDIR into Other" absent "/var/tmpx"
check_page "html lists Other last, scaled to the costliest row" present \
    'width: 100%"></span></td></tr></tbody>'
check_page "html shows a temp-directory session as such" present \
    "<code title=\"tmp\">tmp</code></th><td>$(nw "2026-01-02") $(nw "11:00")</td>\
<td class=\"text\">$(nw "claude-opus-5-5")</td><td class=\"text\">(temp directory)</td>"
if [[ "$(grep -o '<th scope="row"><code title=' "$REPORT" | wc -l | tr -d ' ')" == 10 ]]; then
    echo "ok    html lists at most 10 sessions"
else
    echo "FAIL  html lists at most 10 sessions"
    FAILURES=$((FAILURES + 1))
fi

rm -f "$REPORT"
USAGE_NOW_EPOCH="$(epoch '2026-07-01 17:00:00')" \
    check "html renders in daylight time" 0 "$REPORT" -- --html --no-open
check_page "html labels the daylight offset" present "Generated 2026-07-01 12:00:00 (UTC−5)"
USAGE_NOW_EPOCH=soon check "html rejects a non-numeric clock" 1 "USAGE_NOW_EPOCH" \
    -- --html --no-open

# A render that fails after the temp file exists must exit 1 and remove it. Only the final
# render passes --rawfile, so the fake jq fails there and defers to the real one elsewhere.
mkdir -p "$WORK/failing-jq"
cat >"$WORK/failing-jq/jq" <<EOF
#!/bin/bash
if [[ " \$* " == *" --rawfile "* ]]; then
    echo partial
    exit 5
fi
exec "$(command -v jq)" "\$@"
EOF
chmod +x "$WORK/failing-jq/jq"
PATH="$WORK/failing-jq:$PATH" check "html names a failed render" 1 "could not render" \
    -- --html --no-open
if find "$XDG_CACHE_HOME/ai-usage" -type f ! -name report.html | grep -q .; then
    echo "FAIL  html removes its temp file after a failed render"
    FAILURES=$((FAILURES + 1))
else
    echo "ok    html removes its temp file after a failed render"
fi

# The opener fails, which must not fail the report once its path is printed.
mkdir -p "$WORK/fake-bin"
for opener in open xdg-open; do
    printf '#!/bin/bash\ntouch "%s/opened"\nexit 1\n' "$WORK" >"$WORK/fake-bin/$opener"
    chmod +x "$WORK/fake-bin/$opener"
done
rc=0
output="$(PATH="$WORK/fake-bin:$PATH" "$AI_USAGE" --html 2>&1)" || rc=$?
if ((rc == 0)) && [[ "$output" == *"$REPORT"* && -f "$WORK/opened" ]]; then
    echo "ok    html survives a failing opener"
else
    printf 'FAIL  html survives a failing opener: exit %s\n%s\n' "$rc" "$output"
    FAILURES=$((FAILURES + 1))
fi

mkdir -p "$WORK/v2" "$WORK/garbage"
sqlite3 "$WORK/v2/usage.db" 'PRAGMA user_version = 2;'
USAGE_DB_DIR="$WORK/v2" check "html names an old schema version" 1 "schema version 2" \
    -- --html --no-open
printf 'not a database' >"$WORK/garbage/usage.db"
USAGE_DB_DIR="$WORK/garbage" check "html names an unreadable DB" 1 "could not read" \
    -- --html --no-open

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

hold_exclusive_lock 2
check "html waits out a short lock" 0 "$REPORT" -- --html --no-open
wait "$LOCK_PID" 2>/dev/null || true

# Usage: check_lock_timeout <name> <expected-substring> <ai-usage args...>
check_lock_timeout() {
    local name="$1" expected_text="$2" output rc=0 started=$SECONDS waited
    shift 2
    output="$("$AI_USAGE" "$@" 2>&1)" || rc=$?
    waited=$((SECONDS - started))
    if ((rc != 0 && waited >= 4)) && [[ "$output" == *"database is locked"* &&
        "$output" == *"$expected_text"* ]]; then
        echo "ok    $name"
    else
        printf 'FAIL  %s: exit %s after %ss\n%s\n' "$name" "$rc" "$waited" "$output"
        FAILURES=$((FAILURES + 1))
    fi
}

# Long enough to outlast two 5-second busy timeouts in a row, with margin.
hold_exclusive_lock 14
check_lock_timeout "a report fails after the timeout when the lock outlasts it" "" --by-model
check_lock_timeout "html fails after the timeout with a clear message" "could not read" \
    --html --no-open
kill "$LOCK_PID" 2>/dev/null || true
wait "$LOCK_PID" 2>/dev/null || true

SUMMARY_REACHED=true
if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
