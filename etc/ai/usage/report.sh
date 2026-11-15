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

# The one statement the page is built from, so every figure comes from one read transaction.
# Local-time formatting happens here; report.jq does no date handling. The heredoc expands
# $now and \$[...], so interpolate only validated numbers or sql_str output.
blob_sql() {
    local now="$1"
    cat <<SQL
WITH clock(offset_min) AS (
    SELECT CAST(round((julianday($now, 'unixepoch', 'localtime')
        - julianday($now, 'unixepoch')) * 1440) AS INTEGER)
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
    'models', (SELECT json_group_array(model) FROM (
        SELECT COALESCE(model, '(unknown)') AS model FROM sessions
        GROUP BY model ORDER BY max(updated_at) DESC))
);
SQL
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
    local should_open=true now blob arg
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

    mkdir -p "$REPORT_OUT_DIR" || report_fail "could not create $REPORT_OUT_DIR"
    trap 'rm -f "$REPORT_TMP"' EXIT
    REPORT_TMP="$(mktemp "$REPORT_OUT_DIR/report.XXXXXX")" ||
        report_fail "could not create a temp file"
    jq --join-output --rawfile tmpl "$REPORT_DIR/report.html.tmpl" \
        --from-file "$REPORT_DIR/report.jq" <<<"$blob" >"$REPORT_TMP" ||
        report_fail "could not render the report"
    mv "$REPORT_TMP" "$REPORT_OUT" || report_fail "could not write $REPORT_OUT"
    echo "$REPORT_OUT"
    if [[ "$should_open" == true ]]; then
        open_report "$REPORT_OUT"
    fi
}

main "$@"
