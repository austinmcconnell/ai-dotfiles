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
check_page "html names an empty cost chart" present "No cost is recorded for the last 30 days."

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

# Model ids reach the page as series labels; a hostile one must render inert. It costs the
# most, so it keeps its own series while the two cheapest models share Other.
hostile='</script><!--&"'
cost_row() {
    printf "('claude-code', '%s', %s, '2026-01-02T00:00:00Z', %s)" "$1" "$2" "$(sql_str "$3")"
}
sqlite3 "$USAGE_DB" "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at,
    raw_json) VALUES $(cost_row hostile 5 "$(jq -nc --arg id "$hostile" '{model: {id: $id}}')"),
    $(cost_row no-model 0.10 '{}'), $(cost_row haiku 0.05 '{"model":{"id":"claude-haiku-5-5"}}');"
rm -f "$REPORT"
check "html renders a seeded DB" 0 "$REPORT" -- --html --no-open
check_page "html escapes a hostile model id" present "&lt;/script&gt;&lt;!--&amp;&quot;"
check_page "html never emits a hostile model id raw" absent "$hostile"
check_page "html shows a missing model as (unknown)" present "(unknown)"
check_page "html never renders null" absent "null"
check_page "html folds models past the fourth into Other" present "<th scope=\"col\">Other</th>"
# s1 and s2 cost 3.25 on 2025-12-31 local time; the other three 5.15 on 2026-01-01.
check_page "html books a day's cost per model" present \
    "2025-12-31</th><td></td><td>\$2.50</td><td>\$0.75</td><td></td><td>\$3.25</td>"
check_page "html fills a day with no cost" present \
    "2026-01-02</th><td></td><td></td><td></td><td></td><td>\$0.00</td>"
check_page "html scales the cost axis to a 1-2-5 step" present ">\$8</text>"
check_page "html labels API-rate dollars" present "Dollars are at API rates."
check_page "html never calls cost spend" absent "spend"
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
check_page "html paces a figure when it was observed" present "+14 points against an even pace"
check_page "html names the yellow level in text" present "level-yellow\">+14"
check_page "html dates a day-old observation" present "most recently 2026-01-01 12:00."

# A later cost snapshot that carried rate_limits shows the figure still held at the clock.
sqlite3 "$USAGE_DB" "INSERT INTO cost_snapshots (tool, session_id, total_cost_usd, occurred_at,
    raw_json) VALUES ('claude-code', 's1', 1.25,
    strftime('%Y-%m-%dT%H:%M:%SZ', $USAGE_NOW_EPOCH, 'unixepoch'), '{\"rate_limits\":{}}');"
rm -f "$REPORT"
check "html renders a figure held until the clock" 0 "$REPORT" -- --html --no-open
check_page "html takes the last observation from cost snapshots" present \
    "most recently 2026-01-02 12:00."
check_page "html shows on pace in text" present "level-on\">+0 points against an even pace"
split="\$1.25 from subscription sessions is an API-equivalent estimate, not money spent;"
check_page "html splits subscription dollars from API-rate dollars" present \
    "$split the other \$7.15 is at API rates."

# 3.5 days into the 7d window, so an even pace is 50%. 12.5 rounds to 12 as in the statusline,
# including under a decimal-comma locale.
rate_row 30 12.5 $((USAGE_NOW_EPOCH + 4500)) $((USAGE_NOW_EPOCH + 302400))
rm -f "$REPORT"
LC_ALL=de_DE.UTF-8 check "html renders open windows" 0 "$REPORT" -- --html --no-open
check_page "html rounds a 7d half like the statusline" present "12% used"
check_page "html shows the 7d reset in local time" present "Resets 2026-01-06 00:00, 3d 12h left"
check_page "html dates relative figures" present "left as of 2026-01-02 12:00:00."
check_page "html shows 7d pace with room" present "−38 points against an even pace"
check_page "html names the room-to-ramp level" present "level-green"
check_page "html shows the 5h reset" present "Resets 2026-01-02 13:15, 1h 15m left"
check_page "html dates the last observation" present "most recently 2026-01-02 12:00."
if [[ "$(grep -o 'points against' "$REPORT" | wc -l | tr -d ' ')" == 1 ]]; then
    echo "ok    html gives the 5h window no pace"
else
    echo "FAIL  html gives the 5h window no pace"
    FAILURES=$((FAILURES + 1))
fi

rate_row 31 80 $((USAGE_NOW_EPOCH + 4500)) $((USAGE_NOW_EPOCH + 302400))
rm -f "$REPORT"
check "html renders a tight 7d window" 0 "$REPORT" -- --html --no-open
check_page "html shows 7d pace over" present "+30 points against an even pace"
check_page "html names the red level in text" present "well over pace"

# The 5h window resets exactly at the clock, which counts as closed.
rate_row 34 60 "$USAGE_NOW_EPOCH" $((USAGE_NOW_EPOCH - 3600))
rm -f "$REPORT"
check "html renders closed windows" 0 "$REPORT" -- --html --no-open
check_page "html shows a closed 7d window" present \
    "Reset at 2026-01-02 11:00. No figure for the new window is recorded here."
check_page "html keeps the last 7d figure as secondary" present \
    "last recorded figure before the reset was 60%."
check_page "html closes a window that resets at the clock" present "Reset at 2026-01-02 12:00."
check_page "html gives a closed window no pace" absent "points against"
check_page "html charts no closed window" present "No open 7-day window is recorded"

# A newer payload without the 7d window doesn't hide the older 7d row.
rate_row 20 NULL $((USAGE_NOW_EPOCH + 1800)) NULL
rm -f "$REPORT"
check "html renders a 5h-only row" 0 "$REPORT" -- --html --no-open
check_page "html keeps the 7d tile from the last 7d row" present "before the reset was 60%."
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
        '{\"rate_limits\":{}}');"
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

# A session that began before the 30-day window adds only its in-window step there; sessions
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
