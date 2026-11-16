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

# The one statement the page is built from, so every figure comes from one read transaction.
# Local-time formatting happens here; report.jq does no date handling. The heredoc expands
# $now and \$[...], so interpolate only validated numbers or sql_str output. A subquery's JSON
# result can lose its JSON type and nest as a quoted string, so json() wraps each one.
blob_sql() {
    local now="$1"
    cat <<SQL
WITH clock(offset_min, now_iso, scan_from_iso) AS (
    SELECT CAST(round((julianday($now, 'unixepoch', 'localtime')
        - julianday($now, 'unixepoch')) * 1440) AS INTEGER),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now, 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now - 8 * 86400, 'unixepoch')
),
-- Rate-limit rows are written only when a percentage changes, so a later cost snapshot whose
-- payload carried rate_limits can be the last time this machine saw quota. Its raw_json scan
-- covers the last 8 days, enough for the current 7d window.
observed(at) AS (
    SELECT min(max(
        COALESCE((SELECT max(occurred_at) FROM rate_limit_snapshots
            WHERE tool = 'claude-code'), ''),
        COALESCE((SELECT max(occurred_at) FROM cost_snapshots
            WHERE tool = 'claude-code' AND occurred_at >= scan_from_iso
                AND json_type(CASE WHEN json_valid(raw_json) THEN raw_json END,
                    '\$.rate_limits') IS NOT NULL), '')), now_iso)
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
)
SELECT json_object(
    'generated_at', datetime($now, 'unixepoch', 'localtime'),
    'utc_offset', (SELECT 'UTC' || CASE WHEN offset_min = 0 THEN ''
        ELSE CASE WHEN offset_min < 0 THEN '−' ELSE '+' END || (abs(offset_min) / 60)
            || CASE WHEN abs(offset_min) % 60 = 0 THEN ''
                ELSE printf(':%02d', abs(offset_min) % 60) END
        END FROM clock),
    'sessions', (SELECT printf('%d session%s', COUNT(*), CASE WHEN COUNT(*) = 1 THEN ''
        ELSE 's' END) FROM sessions),
    'models', json((SELECT json_group_array(model) FROM (
        SELECT COALESCE(model, '(unknown)') AS model FROM sessions
        GROUP BY model ORDER BY max(updated_at) DESC))),
    'quota_observed', (SELECT EXISTS (
        SELECT 1 FROM rate_limit_snapshots
        WHERE tool = 'claude-code' AND seven_day_used_percentage IS NOT NULL)),
    'last_observed', (SELECT strftime('%Y-%m-%d %H:%M', at, 'localtime') FROM observed
        WHERE at != ''),
    'last_observed_epoch', (SELECT strftime('%s', at) FROM observed WHERE at != ''),
    'burnup', $(burnup_sql),
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
