#!/bin/bash
set -euo pipefail

# Writes the static HTML usage report behind `ai-usage --html`. One read-only SQL statement
# emits a JSON blob, report.jq renders it into report.html.tmpl, and this script owns the
# clock, the output file, and the opener. bin/ai-usage checks that the DB exists first.

REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$REPORT_DIR/lib.sh"

# Migration 0003 adds v_cost_deltas, which the report reads.
REPORT_MIN_USER_VERSION=3
REPORT_OUT_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ai-usage"
REPORT_OUT="$REPORT_OUT_DIR/report.html"
# Global, so the EXIT trap can still see it after main returns.
REPORT_TMP=""

report_fail() {
    echo "ai-usage --html: $*" >&2
    exit 1
}

# Never usage_sql: that opens the DB read-write, and the report must not create or migrate it.
# -init /dev/null skips ~/.sqliterc, whose .headers or .mode would corrupt the JSON output.
report_sql() {
    sqlite3 -init /dev/null -readonly -bail -cmd ".timeout $USAGE_DB_BUSY_TIMEOUT_MS" \
        "$USAGE_DB" "$@"
}

# sqlite3's own error (e.g. "database is locked") reaches stderr before this message.
read_db() {
    report_sql "$1" || report_fail "could not read $USAGE_DB"
}

check_schema_version() {
    local version
    version="$(read_db 'PRAGMA user_version;')" || exit 1
    if ((version < REPORT_MIN_USER_VERSION)); then
        report_fail "$USAGE_DB is at schema version $version; this report needs" \
            "$REPORT_MIN_USER_VERSION or later. The next Claude Code statusline render upgrades it."
    fi
}

# The newest row with a used percentage for one rate-limit window ($1: five_hour or seven_day).
# A payload carries a window's percentage and reset time together or omits the window, so a
# NULL-percentage row is skipped rather than read as data.
window_row_sql() {
    local window="$1"
    cat <<SQL
SELECT '$window', * FROM (
    SELECT ${window}_used_percentage, ${window}_resets_at FROM rate_limit_snapshots
    WHERE tool = 'claude-code' AND ${window}_used_percentage IS NOT NULL
    ORDER BY id DESC LIMIT 1)
SQL
}

# The open 7d window's rows as [days into the window, used %], in the order they were written,
# plus the day quota was last observed, where the line ends. NULL when no 7d window is open.
burnup_sql() {
    cat <<SQL
json((SELECT json_object(
    'points', json((SELECT json_group_array(json_array(x, pct)) FROM (
        SELECT max(0, (CAST(strftime('%s', occurred_at) AS INTEGER)
                - (tiles.resets_at - $SEVEN_DAY_SECONDS)) / 86400.0) AS x,
            seven_day_used_percentage AS pct
        FROM rate_limit_snapshots
        WHERE tool = 'claude-code' AND seven_day_resets_at = tiles.resets_at
            AND seven_day_used_percentage IS NOT NULL
        ORDER BY id))),
    'end_x', (SELECT (CAST(strftime('%s', at) AS INTEGER)
        - (tiles.resets_at - $SEVEN_DAY_SECONDS)) / 86400.0 FROM observed WHERE at != ''))
    FROM tiles WHERE name = 'seven_day' AND state = 'current'))
SQL
}

# True when a payload carries the rate_limits object, which only a subscription session's
# statusline receives. An explicit null is not a subscription.
carries_rate_limits_sql() {
    echo "json_type(CASE WHEN json_valid($1) THEN $1 END, '\$.rate_limits') = 'object'"
}

# Cost per local day for the last 30 days, split into model series. Each snapshot's step is its
# total less the session's previous one, as in v_cost_deltas. A session that began before the
# window steps its first row there from its last earlier snapshot, not from 0, or the window would
# book its whole earlier cost to one day. A session is a subscription session if any of its rows
# in the window carries rate_limits (a session's first snapshot never does).
cost_ctes_sql() {
    cat <<SQL
cost_clock(from_day, to_day) AS (
    SELECT date($now, 'unixepoch', 'localtime', '-29 days'),
        date($now, 'unixepoch', 'localtime')
),
cost_steps(id, tool, session_id, day, delta) AS (
    SELECT c.id, c.tool, c.session_id, date(c.occurred_at, 'localtime'),
        c.total_cost_usd - CASE
            WHEN lag(c.id) OVER (PARTITION BY c.tool, c.session_id ORDER BY c.id) IS NOT NULL
            THEN lag(c.total_cost_usd) OVER (PARTITION BY c.tool, c.session_id ORDER BY c.id)
            WHEN (SELECT started_at FROM sessions s WHERE s.tool = c.tool
                AND s.session_id = c.session_id) < (SELECT cost_from_iso FROM clock)
            THEN COALESCE((SELECT p.total_cost_usd FROM cost_snapshots p
                WHERE p.id <= (SELECT cost_id FROM cutoffs) AND p.tool = c.tool
                    AND p.session_id = c.session_id
                ORDER BY p.id DESC LIMIT 1), 0)
            ELSE 0 END
    FROM cost_snapshots c
    WHERE c.id > (SELECT cost_id FROM cutoffs) AND c.occurred_at <= (SELECT now_iso FROM clock)
),
cost_rows(tool, session_id, day, model, delta, subscription) AS (
    SELECT s.tool, s.session_id, s.day,
        COALESCE(json_extract(CASE WHEN json_valid(c.raw_json) THEN c.raw_json END,
            '\$.model.id'), '(unknown)'),
        s.delta, $(carries_rate_limits_sql c.raw_json)
    FROM cost_steps s JOIN cost_snapshots c ON c.id = s.id, cost_clock
    WHERE s.day BETWEEN from_day AND to_day
),
-- The only CTE that reads cost_rows, so raw_json is parsed once however often the CTEs below
-- reference this. A negative or zero step adds nothing to a column.
cost_groups(tool, session_id, day, model, usd, subscription) AS (
    SELECT tool, session_id, day, model, sum(CASE WHEN delta > 0 THEN delta ELSE 0 END),
        max(subscription)
    FROM cost_rows GROUP BY tool, session_id, day, model
),
cost_sessions(tool, session_id, subscription) AS (
    SELECT tool, session_id, max(subscription) FROM cost_groups GROUP BY tool, session_id
),
-- At most four series: past four models, the top three keep their own and the rest share Other.
cost_models(model, total, rank) AS (
    SELECT model, sum(usd), row_number() OVER (ORDER BY sum(usd) DESC, model)
    FROM cost_groups WHERE usd > 0 GROUP BY model
),
cost_series(model, total, slot) AS (
    SELECT model, total,
        CASE WHEN (SELECT COUNT(*) FROM cost_models) <= 4 OR rank <= 3 THEN rank ELSE 4 END
    FROM cost_models
),
cost_cells(day, slot, usd) AS (
    SELECT g.day, s.slot, sum(g.usd) FROM cost_groups g JOIN cost_series s ON s.model = g.model
    WHERE g.usd > 0 GROUP BY g.day, s.slot
),
-- One row per day with cost. cells is JSON text here: a CTE drops the JSON subtype, so the
-- reader wraps it in json().
cost_day_totals(day, usd, cells) AS (
    SELECT day, sum(usd), json_group_array(json_array(slot, usd, printf('%.2f', usd)))
    FROM (SELECT * FROM cost_cells ORDER BY day, slot) GROUP BY day
),
-- Every local day from the first with cost to today, stepped on date strings so a 25-hour
-- DST day is still one day.
cost_days(day) AS (
    SELECT first_day FROM (SELECT min(day) AS first_day FROM cost_day_totals)
    WHERE first_day IS NOT NULL
    UNION ALL
    SELECT date(day, '+1 day') FROM cost_days, cost_clock WHERE day < to_day
),
-- The y axis runs to four steps of the smallest 1-2-5 step that fits the costliest day.
cost_scale(step) AS (
    SELECT min(column1) FROM (VALUES (0.01), (0.02), (0.05), (0.1), (0.2), (0.5), (1), (2),
        (5), (10), (20), (50), (100), (200), (500), (1000), (2000), (5000), (10000), (20000),
        (50000), (100000))
    WHERE column1 * 4 >= (SELECT max(usd) FROM cost_day_totals)
),
cost_split(subscription_usd, other_usd) AS (
    SELECT COALESCE(sum(CASE WHEN p.subscription THEN g.usd END), 0),
        COALESCE(sum(CASE WHEN p.subscription THEN NULL ELSE g.usd END), 0)
    FROM cost_groups g JOIN cost_sessions p ON p.tool = g.tool AND p.session_id = g.session_id
)
SQL
}

# The cost section's blob key. Amounts arrive twice: a number for geometry and a printf string
# for display.
cost_json_sql() {
    cat <<SQL
json_object(
    'days', json((SELECT json_group_array(json_object('day', d.day,
            'label', strftime('%m-%d', d.day), 'total', printf('%.2f', COALESCE(t.usd, 0)),
            'cells', json(COALESCE(t.cells, '[]'))))
        FROM (SELECT day FROM cost_days ORDER BY day) d LEFT JOIN cost_day_totals t
            ON t.day = d.day)),
    'series', json((SELECT json_group_array(json_object('slot', slot,
            'label', CASE WHEN members = 1 THEN first_model ELSE 'Other' END,
            'members', json(member_list), 'total', printf('%.2f', total)))
        FROM (SELECT slot, COUNT(*) AS members, min(model) AS first_model,
                json_group_array(model) AS member_list, sum(total) AS total
            FROM (SELECT * FROM cost_series ORDER BY total DESC, model)
            GROUP BY slot ORDER BY slot))),
    'scale_max', (SELECT step * 4 FROM cost_scale),
    'ticks', json((SELECT json_group_array(CASE WHEN step >= 1
            THEN printf('\$%d', CAST(step * column1 AS INTEGER))
            ELSE printf('\$%.2f', step * column1) END)
        FROM (SELECT column1 FROM (VALUES (0), (1), (2), (3), (4)) ORDER BY column1), cost_scale)),
    'kind', (SELECT CASE WHEN other_usd = 0 THEN 'subscription'
            WHEN subscription_usd = 0 THEN 'api' ELSE 'mixed' END FROM cost_split),
    'subscription_usd', (SELECT printf('%.2f', subscription_usd) FROM cost_split),
    'other_usd', (SELECT printf('%.2f', other_usd) FROM cost_split))
SQL
}

# The one statement the page is built from, so every figure comes from one read transaction.
# Local-time formatting happens here; report.jq does no date handling. The heredoc expands
# $now and \$[...], so interpolate only validated numbers or sql_str output. A subquery's JSON
# result can lose its JSON type and nest as a quoted string, so json() wraps each one.
blob_sql() {
    local now="$1"
    cat <<SQL
WITH RECURSIVE clock(offset_min, now_iso, scan_from_iso, cost_from_iso) AS (
    SELECT CAST(round((julianday($now, 'unixepoch', 'localtime')
        - julianday($now, 'unixepoch')) * 1440) AS INTEGER),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now, 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now - 8 * 86400, 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ',
            date($now, 'unixepoch', 'localtime', '-29 days'), 'utc')
),
-- cost_snapshots has no date index, but rows are appended in time order, so the newest id
-- before a bound lets a scan seek by rowid instead of reading the whole table. Each lookup reads
-- backwards only through the rows after its bound. Readers use these as uncorrelated scalar
-- subqueries, which SQLite evaluates once rather than once per row.
cutoffs(scan_id, cost_id) AS (
    SELECT COALESCE((SELECT id FROM cost_snapshots WHERE occurred_at < scan_from_iso
            ORDER BY id DESC LIMIT 1), 0),
        COALESCE((SELECT id FROM cost_snapshots WHERE occurred_at < cost_from_iso
            ORDER BY id DESC LIMIT 1), 0)
    FROM clock
),
-- Rate-limit rows are written only when a percentage changes, so a later cost snapshot whose
-- payload carried rate_limits can be the last time this machine saw quota. Its raw_json scan
-- covers the last 8 days, enough for the current 7d window.
observed(at) AS (
    SELECT min(max(
        COALESCE((SELECT max(occurred_at) FROM rate_limit_snapshots
            WHERE tool = 'claude-code'), ''),
        COALESCE((SELECT occurred_at FROM cost_snapshots
            WHERE id > (SELECT scan_id FROM cutoffs) AND tool = 'claude-code'
                AND occurred_at >= scan_from_iso AND $(carries_rate_limits_sql raw_json)
            ORDER BY id DESC LIMIT 1), '')), now_iso)
    FROM clock
),
windows(name, pct, resets_at) AS (
    $(window_row_sql seven_day)
    UNION ALL
    $(window_row_sql five_hour)
),
-- A window is current while its reset time is still ahead of the clock.
tiles(name, state, pct, resets_at) AS (
    SELECT name, CASE WHEN resets_at IS NULL THEN 'unknown'
            WHEN resets_at > $now THEN 'current' ELSE 'reset' END,
        CAST(pct AS TEXT), resets_at
    FROM windows
),
$(cost_ctes_sql)
SELECT json_object(
    'generated_at', datetime($now, 'unixepoch', 'localtime'),
    'utc_offset', (SELECT 'UTC' || CASE WHEN offset_min = 0 THEN ''
        ELSE CASE WHEN offset_min < 0 THEN '−' ELSE '+' END || (abs(offset_min) / 60)
            || CASE WHEN abs(offset_min) % 60 = 0 THEN ''
                ELSE printf(':%02d', abs(offset_min) % 60) END
        END FROM clock),
    'quota_observed', (SELECT EXISTS (
        SELECT 1 FROM rate_limit_snapshots
        WHERE tool = 'claude-code' AND seven_day_used_percentage IS NOT NULL)),
    'last_observed', (SELECT strftime('%Y-%m-%d %H:%M', at, 'localtime') FROM observed
        WHERE at != ''),
    'last_observed_epoch', (SELECT strftime('%s', at) FROM observed WHERE at != ''),
    'burnup', $(burnup_sql),
    'cost', $(cost_json_sql),
    'quota', json_object(
        'seven_day', json((SELECT json_object('state', state, 'pct', pct,
            'resets_at', CAST(resets_at AS TEXT),
            'resets_local', strftime('%Y-%m-%d %H:%M', resets_at, 'unixepoch', 'localtime'))
            FROM tiles WHERE name = 'seven_day')),
        'five_hour', json((SELECT json_object('state', state, 'pct', pct,
            'resets_at', CAST(resets_at AS TEXT),
            'resets_local', strftime('%Y-%m-%d %H:%M', resets_at, 'unixepoch', 'localtime'))
            FROM tiles WHERE name = 'five_hour')))
);
SQL
}

# Seconds as "2d 5h" from a day up, else "3h 20m".
format_left() {
    local seconds="$1"
    if ((seconds >= 86400)); then
        printf '%dd %dh' $((seconds / 86400)) $((seconds % 86400 / 3600))
    else
        printf '%dh %dm' $((seconds / 3600)) $((seconds % 3600 / 60))
    fi
}

# One quota tile as JSON. SQL decides the state (current, reset, or unknown when the row has no
# reset time); a window with no row is none. Used % and pace are formatted here, not in SQL or
# jq, which round 12.5 up where bash and the statusline round it to 12. Pace is taken at the
# last observation, since a figure held since then says nothing about usage after it.
tile_json() {
    local blob="$1" window="$2" now="$3" fields state pct resets_at observed
    local used="" left="" pace="" level="" delta
    local LC_ALL=C
    fields="$(jq -r --arg window "$window" '
        (.quota[$window] // {}) as $tile
        | [$tile.state // "none", $tile.pct // "", $tile.resets_at // "",
            .last_observed_epoch // ""]
        | join("\u001f")' <<<"$blob")" || return 1
    # A unit separator, not a tab: tab is IFS whitespace, so read would collapse an empty field.
    IFS=$'\x1f' read -r state pct resets_at observed <<<"$fields"
    [[ -n "$pct" ]] && used="$(printf '%.0f%%' "$pct")"
    if [[ "$state" == current ]]; then
        left="$(format_left $((resets_at - now)))"
        if [[ "$window" == seven_day ]]; then
            delta="$(pace_delta "$pct" "$resets_at" "${observed:-$now}")"
            level="$(pace_level "$delta")"
            level="${level:-on}"
            pace="$(printf '%+d' "$delta")"
            pace="${pace/-/−}"
        fi
    fi
    jq -n --arg state "$state" --arg used "$used" --arg left "$left" --arg pace "$pace" \
        --arg level "$level" '{state: $state, used: $used, left: $left, pace: $pace, level: $level}'
}

tiles_json() {
    local blob="$1" now="$2" seven_day five_hour
    seven_day="$(tile_json "$blob" seven_day "$now")" || return 1
    five_hour="$(tile_json "$blob" five_hour "$now")" || return 1
    jq -n --argjson seven_day "$seven_day" --argjson five_hour "$five_hour" \
        '{seven_day: $seven_day, five_hour: $five_hour}'
}

open_report() {
    local opener
    case "$(uname -s)" in
    Darwin) opener=open ;;
    Linux) opener=xdg-open ;;
    *) return 0 ;;
    esac
    command -v "$opener" >/dev/null 2>&1 || return 0
    "$opener" "$1" >/dev/null 2>&1 ||
        echo "ai-usage --html: $opener failed; open the path above yourself." >&2
}

main() {
    local should_open=true now blob tiles arg
    for arg in "$@"; do
        case "$arg" in
        --no-open) should_open=false ;;
        *) report_fail "unknown option $arg (usage: ai-usage --html [--no-open])" ;;
        esac
    done

    now="${USAGE_NOW_EPOCH:-$(date +%s)}"
    [[ "$now" =~ ^[0-9]+$ ]] || report_fail "USAGE_NOW_EPOCH must be epoch seconds, got [$now]"
    now=$((10#$now))

    check_schema_version
    blob="$(read_db "$(blob_sql "$now")")" || exit 1
    tiles="$(tiles_json "$blob" "$now")" || report_fail "could not compute the quota tiles"

    mkdir -p "$REPORT_OUT_DIR" || report_fail "could not create $REPORT_OUT_DIR"
    trap 'rm -f "$REPORT_TMP"' EXIT
    REPORT_TMP="$(mktemp "$REPORT_OUT_DIR/report.XXXXXX")" ||
        report_fail "could not create a temp file"
    jq --join-output --rawfile tmpl "$REPORT_DIR/report.html.tmpl" --argjson tiles "$tiles" \
        --from-file "$REPORT_DIR/report.jq" <<<"$blob" >"$REPORT_TMP" ||
        report_fail "could not render the report"
    mv "$REPORT_TMP" "$REPORT_OUT" || report_fail "could not write $REPORT_OUT"
    echo "$REPORT_OUT"
    if [[ "$should_open" == true ]]; then
        open_report "$REPORT_OUT"
    fi
}

main "$@"
