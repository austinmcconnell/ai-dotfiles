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
REPORT_TOP_PROJECTS=8
REPORT_TOP_ROWS=10
# The daily rate averages up to 7 complete days and needs at least 3.
REPORT_RATE_DAYS=7
REPORT_MIN_RATE_DAYS=3
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

# One rate-limit window ($1: five_hour or seven_day): the newest row with its percentage picks
# the window, and the tile shows the highest percentage recorded for that window. Every open
# session's statusline writes rows, and one can report a figure older and lower than another
# session already wrote. A payload carries a window's percentage and reset time together or
# omits the window, so a NULL-percentage row is skipped; a row without a reset time keeps its
# own figure.
window_row_sql() {
    local window="$1"
    cat <<SQL
SELECT '$window', CASE WHEN resets_at IS NULL THEN pct
        ELSE (SELECT max(${window}_used_percentage) FROM rate_limit_snapshots
            WHERE tool = 'claude-code' AND ${window}_resets_at = newest.resets_at) END,
    resets_at FROM (
    SELECT ${window}_used_percentage AS pct, ${window}_resets_at AS resets_at
    FROM rate_limit_snapshots
    WHERE tool = 'claude-code' AND ${window}_used_percentage IS NOT NULL
    ORDER BY id DESC LIMIT 1) AS newest
SQL
}

# The open 7d window's rows as [days into the window, highest used % so far], in the order they
# were written, plus the day quota was last observed, where the line ends. NULL when no 7d
# window is open.
burnup_sql() {
    cat <<SQL
json((SELECT json_object(
    'points', json((SELECT json_group_array(json_array(x, pct)) FROM (
        SELECT max(0, (CAST(strftime('%s', occurred_at) AS INTEGER)
                - (tiles.resets_at - $SEVEN_DAY_SECONDS)) / 86400.0) AS x,
            max(seven_day_used_percentage) OVER (ORDER BY id) AS pct
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

# A rate_limits field ($2, e.g. seven_day.resets_at) from a payload column ($1), NULL when the
# payload is not valid JSON.
payload_sql() {
    echo "json_extract(CASE WHEN json_valid($1) THEN $1 END, '\$.rate_limits.$2')"
}

# The smallest 1-2-5 step whose four multiples reach the bound ($1, a scalar subquery), for the
# y axis of a cost chart.
scale_step_sql() {
    cat <<SQL
SELECT min(column1) FROM (VALUES (0.01), (0.02), (0.05), (0.1), (0.2), (0.5), (1), (2), (5), (10),
    (20), (50), (100), (200), (500), (1000), (2000), (5000), (10000), (20000), (50000), (100000))
WHERE column1 * 4 >= $1
SQL
}

# The five y-axis labels, 0 to four steps, from a one-row scale CTE ($1).
scale_ticks_sql() {
    cat <<SQL
json((SELECT json_group_array(CASE WHEN step >= 1
        THEN printf('\$%d', CAST(step * column1 AS INTEGER))
        ELSE printf('\$%.2f', step * column1) END)
    FROM (SELECT column1 FROM (VALUES (0), (1), (2), (3), (4)) ORDER BY column1), $1))
SQL
}

# Cost per local day for the last 31 days, split into model series. Each snapshot's step is its
# total less the session's previous one, as in v_cost_deltas. A session that began before the
# window, or has no sessions row, steps its first row there from its last earlier snapshot, not
# from 0, or the window would book its whole earlier cost to one day. A session is a subscription session if any of its rows
# in the window carries rate_limits (a session's first snapshot never does).
cost_ctes_sql() {
    cat <<SQL
cost_clock(from_day, to_day, shown_from) AS (
    SELECT date($now, 'unixepoch', 'localtime', '-30 days'),
        date($now, 'unixepoch', 'localtime'),
        CASE WHEN (SELECT seen FROM quota_seen)
            THEN date($now, 'unixepoch', 'localtime', '-30 days')
            ELSE date($now, 'unixepoch', 'localtime', 'start of month') END
),
cost_steps(id, tool, session_id, at, day, delta) AS (
    SELECT c.id, c.tool, c.session_id, c.occurred_at, date(c.occurred_at, 'localtime'),
        c.total_cost_usd - CASE
            WHEN lag(c.id) OVER (PARTITION BY c.tool, c.session_id ORDER BY c.id) IS NOT NULL
            THEN lag(c.total_cost_usd) OVER (PARTITION BY c.tool, c.session_id ORDER BY c.id)
            WHEN COALESCE((SELECT started_at FROM sessions s WHERE s.tool = c.tool
                AND s.session_id = c.session_id), '') < (SELECT cost_from_iso FROM clock)
            THEN COALESCE((SELECT p.total_cost_usd FROM cost_snapshots p
                WHERE p.id <= (SELECT cost_id FROM cutoffs) AND p.tool = c.tool
                    AND p.session_id = c.session_id
                ORDER BY p.id DESC LIMIT 1), 0)
            ELSE 0 END
    FROM cost_snapshots c
    WHERE c.id > (SELECT cost_id FROM cutoffs) AND c.occurred_at <= (SELECT now_iso FROM clock)
),
cost_rows(tool, session_id, at, day, model, project, delta, subscription) AS (
    SELECT s.tool, s.session_id, s.at, s.day,
        COALESCE(CAST(json_extract(CASE WHEN json_valid(c.raw_json) THEN c.raw_json END,
            '\$.model.id') AS TEXT), '(unknown)'),
        CAST(json_extract(CASE WHEN json_valid(c.raw_json) THEN c.raw_json END,
            '\$.workspace.project_dir') AS TEXT),
        s.delta, $(carries_rate_limits_sql c.raw_json)
    FROM cost_steps s JOIN cost_snapshots c ON c.id = s.id, cost_clock
    WHERE s.day BETWEEN from_day AND to_day
),
-- The only CTE that reads cost_rows, so raw_json is parsed once however often the CTEs below
-- reference this. A negative or zero step adds nothing to a column.
cost_groups(tool, session_id, day, model, project, usd, subscription, last_at) AS (
    SELECT tool, session_id, day, model, project,
        sum(CASE WHEN delta > 0 THEN delta ELSE 0 END), max(subscription), max(at)
    FROM cost_rows GROUP BY tool, session_id, day, model, project
),
-- What the sections display: the local calendar month on a machine with no quota rows, else the
-- whole window. The daily rate reads cost_daily instead, so it keeps the whole window's history.
cost_shown(tool, session_id, day, model, project, usd, subscription, last_at) AS (
    SELECT g.* FROM cost_groups g, cost_clock WHERE g.day >= shown_from
),
cost_daily(day, usd) AS (
    SELECT day, sum(usd) FROM cost_groups WHERE usd > 0 GROUP BY day
),
cost_sessions(tool, session_id, subscription) AS (
    SELECT tool, session_id, max(subscription) FROM cost_groups GROUP BY tool, session_id
),
-- The three costliest models keep their own series and the rest share Other, slot 4, which
-- the page draws grey and stacks on top.
cost_models(model, total, rank) AS (
    SELECT model, sum(usd), row_number() OVER (ORDER BY sum(usd) DESC, model)
    FROM cost_shown WHERE usd > 0 GROUP BY model
),
cost_series(model, total, slot) AS (
    SELECT model, total, CASE WHEN rank <= 3 THEN rank ELSE 4 END FROM cost_models
),
cost_cells(day, slot, usd) AS (
    SELECT g.day, s.slot, sum(g.usd) FROM cost_shown g JOIN cost_series s ON s.model = g.model
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
    $(scale_step_sql "(SELECT max(usd) FROM cost_day_totals)")
),
cost_split(subscription_usd, other_usd) AS (
    SELECT COALESCE(sum(CASE WHEN p.subscription THEN g.usd END), 0),
        COALESCE(sum(CASE WHEN p.subscription THEN NULL ELSE g.usd END), 0)
    FROM cost_groups g JOIN cost_sessions p ON p.tool = g.tool AND p.session_id = g.session_id
),
$(project_ctes_sql),
$(session_ctes_sql),
$(burn_ctes_sql)
SQL
}

# The daily rate and month-end projection, from the daily totals above. A day with no cost counts
# as $0 from the first day with cost on, so the rate needs REPORT_MIN_RATE_DAYS complete days
# after that (a first day is often partial, and earlier days are unknown, not zero). All day
# arithmetic is on date strings, so a 23- or 25-hour DST day is still one day.
burn_ctes_sql() {
    cat <<SQL
cost_burn_hist(first_day, today, month_start, month_end, complete) AS (
    SELECT first_day, to_day, date(to_day, 'start of month'),
        date(to_day, 'start of month', '+1 month', '-1 day'),
        CASE WHEN first_day IS NULL THEN 0
            ELSE CAST(round(julianday(to_day) - julianday(first_day)) AS INTEGER) END
    FROM cost_clock, (SELECT min(day) AS first_day FROM cost_daily)
),
cost_burn(first_day, today, month_start, month_end, rate_days, rate, mtd, today_usd,
        days_after) AS (
    SELECT h.first_day, h.today, h.month_start, h.month_end,
        min($REPORT_RATE_DAYS, h.complete),
        CASE WHEN h.complete >= $REPORT_MIN_RATE_DAYS THEN round(COALESCE((
            SELECT sum(t.usd) FROM cost_daily t WHERE t.day < h.today
                AND t.day >= date(h.today, '-' || min($REPORT_RATE_DAYS, h.complete) || ' days')
            ), 0) / min($REPORT_RATE_DAYS, h.complete), 2) END,
        COALESCE((SELECT sum(usd) FROM cost_daily WHERE day >= h.month_start), 0),
        COALESCE((SELECT usd FROM cost_daily WHERE day = h.today), 0),
        CAST(round(julianday(h.month_end) - julianday(h.today)) AS INTEGER)
    FROM cost_burn_hist h
),
-- NULL until there is a daily rate.
cost_projection(usd) AS (
    SELECT CASE WHEN rate IS NULL THEN NULL
        ELSE (mtd - today_usd) + max(today_usd, rate) + rate * days_after END
    FROM cost_burn
),
-- Every local day of the month from the 1st to today, with its cost and the running total.
cost_month_days(day) AS (
    SELECT month_start FROM cost_burn
    UNION ALL
    SELECT date(day, '+1 day') FROM cost_month_days, cost_burn WHERE day < today
),
cost_month(day, n, usd, cum) AS (
    SELECT d.day, CAST(strftime('%d', d.day) AS INTEGER), COALESCE(t.usd, 0),
        sum(COALESCE(t.usd, 0)) OVER (ORDER BY d.day)
    FROM cost_month_days d LEFT JOIN cost_daily t ON t.day = d.day
),
cost_burn_scale(step) AS (
    $(scale_step_sql "(SELECT max(b.mtd, COALESCE(p.usd, 0)) FROM cost_burn b, cost_projection p)")
)
SQL
}

# The burn blob key. Display figures are strings, with '' for one that is not available, so no
# NULL reaches the page; chart geometry is numeric. Today counts as the larger of its cost so far and the daily rate, since the day is
# not over; the full days after it follow the rate.
burn_json_sql() {
    cat <<SQL
json((SELECT json_object(
    'state', CASE WHEN first_day IS NULL THEN 'none' WHEN rate IS NULL THEN 'history'
        ELSE 'ready' END,
    'mtd', printf('%.2f', mtd),
    'rate', CASE WHEN rate IS NULL THEN '' ELSE printf('%.2f', rate) END,
    'rate_days', printf('%d', rate_days), 'min_days', '$REPORT_MIN_RATE_DAYS',
    'projected', CASE WHEN rate IS NULL THEN ''
        ELSE printf('%.2f', (SELECT usd FROM cost_projection)) END,
    'month', strftime('%Y-%m', today), 'month_end', month_end,
    'chart', json_object(
        'days', CAST(round(julianday(month_end) - julianday(month_start)) AS INTEGER) + 1,
        'points', json((SELECT json_group_array(json_array(n, cum))
            FROM (SELECT n, cum FROM cost_month ORDER BY day))),
        'rows', json((SELECT json_group_array(json_object('day', day, 'usd', printf('%.2f', usd),
                'cum', printf('%.2f', cum)))
            FROM (SELECT * FROM cost_month ORDER BY day))),
        'projected_y', COALESCE((SELECT usd FROM cost_projection), 0),
        'scale_max', (SELECT step * 4 FROM cost_burn_scale),
        'ticks', $(scale_ticks_sql cost_burn_scale)))
    FROM cost_burn))
SQL
}

# A project path ($1) for display: under $HOME as ~, NULL for a temp-directory path (/tmp,
# $TMPDIR, either under /private). Needs the clock CTE in scope for home and tmpdir.
project_label_sql() {
    local path="$1"
    local bare="CASE WHEN substr($path, 1, 9) = '/private/' THEN substr($path, 9) ELSE $path END"
    cat <<SQL
CASE
            WHEN $path IS NULL OR $path = '' THEN '(unknown)'
            WHEN $bare IN ('/tmp', tmpdir) OR substr($bare, 1, 5) = '/tmp/'
                OR (tmpdir != '' AND substr($bare, 1, length(tmpdir) + 1) = tmpdir || '/')
                THEN NULL
            WHEN home = '' THEN $path
            WHEN $path = home THEN '~'
            WHEN substr($path, 1, length(home) + 1) = home || '/'
                THEN '~' || substr($path, length(home) + 1)
            ELSE $path END
SQL
}

# Cost per project over the same window. Temp-directory paths fold into Other with every
# project past the top REPORT_TOP_PROJECTS.
project_ctes_sql() {
    cat <<SQL
cost_project_rows(tool, session_id, project, usd) AS (
    SELECT tool, session_id, $(project_label_sql project), usd
    FROM cost_shown, clock WHERE usd > 0
),
cost_project_rank(project, rank) AS (
    SELECT project, row_number() OVER (ORDER BY sum(usd) DESC, project)
    FROM cost_project_rows WHERE project IS NOT NULL GROUP BY project
),
cost_project_slots(slot, project, usd, sessions) AS (
    SELECT CASE WHEN r.rank <= $REPORT_TOP_PROJECTS THEN r.rank
            ELSE $REPORT_TOP_PROJECTS + 1 END AS slot,
        CASE WHEN r.rank <= $REPORT_TOP_PROJECTS THEN r.project ELSE 'Other' END,
        sum(p.usd), COUNT(DISTINCT p.tool || ' ' || p.session_id)
    FROM cost_project_rows p LEFT JOIN cost_project_rank r ON r.project = p.project
    GROUP BY slot
)
SQL
}

# The costliest sessions over the same window, each with the model and project that carried
# most of its cost there.
session_ctes_sql() {
    cat <<SQL
top_sessions(tool, session_id, usd, last_at) AS (
    SELECT tool, session_id, sum(usd), max(last_at) FROM cost_shown
    GROUP BY tool, session_id HAVING sum(usd) > 0
    ORDER BY sum(usd) DESC, max(last_at) DESC LIMIT $REPORT_TOP_ROWS
)
SQL
}

# The top sessions blob key. A temp-directory project shows as such rather than as Other.
sessions_json_sql() {
    cat <<SQL
json((SELECT json_group_array(json_object('session_id', session_id,
        'last_active', strftime('%Y-%m-%d %H:%M', last_at, 'localtime'),
        'model', (SELECT model FROM cost_shown g WHERE g.tool = t.tool
            AND g.session_id = t.session_id GROUP BY model ORDER BY sum(usd) DESC, model LIMIT 1),
        'project', (SELECT COALESCE($(project_label_sql project), '(temp directory)')
            FROM cost_shown g, clock WHERE g.tool = t.tool AND g.session_id = t.session_id
            GROUP BY project ORDER BY sum(usd) DESC, project LIMIT 1),
        'total', printf('%.2f', usd)))
    FROM (SELECT * FROM top_sessions ORDER BY usd DESC, last_at DESC) t))
SQL
}

# Subagent launches started in the displayed window, which is the same local days the cost
# sections show.
window_launches_sql() {
    cat <<SQL
SELECT subagent_tasks.* FROM subagent_tasks, clock, cost_clock
    WHERE started_at >= strftime('%Y-%m-%dT%H:%M:%SZ', shown_from, 'utc')
        AND started_at <= now_iso
SQL
}

# Launch estimates per agent type, the costliest REPORT_TOP_ROWS types first and the rest as
# Other. A type sums its own priced launches; estimates are already inside their sessions'
# cost, so nothing here is summed across types.
agent_types_json_sql() {
    cat <<SQL
json((SELECT json_group_array(json_object('agent_type', label, 'launches', launches,
        'unpriced', unpriced, 'usd', usd,
        'estimate', CASE WHEN usd IS NULL THEN '(unpriced)' ELSE printf('\$%.2f', usd) END))
    FROM (SELECT CASE WHEN rank <= $REPORT_TOP_ROWS THEN agent_type ELSE 'Other' END AS label,
            CAST(sum(launches) AS TEXT) AS launches, CAST(sum(unpriced) AS TEXT) AS unpriced,
            sum(usd) AS usd, min(rank) AS first_rank
        FROM (SELECT agent_type, launches, unpriced, usd,
                row_number() OVER (ORDER BY usd IS NULL, usd DESC, agent_type) AS rank
            FROM (SELECT COALESCE(agent_type, '(unknown)') AS agent_type, COUNT(*) AS launches,
                    COUNT(*) - COUNT(estimated_cost_usd) AS unpriced,
                    sum(estimated_cost_usd) AS usd
                FROM ($(window_launches_sql)) GROUP BY 1))
        GROUP BY label ORDER BY first_rank)))
SQL
}

# Whether the window's priced launches came from subscription sessions, by their parent
# session. A parent with no cost in the window counts as not a subscription. NULL when none is
# priced.
launch_kind_sql() {
    cat <<SQL
(SELECT CASE WHEN COUNT(*) = 0 THEN NULL
        WHEN sum(COALESCE(p.subscription, 0)) = COUNT(*) THEN 'subscription'
        WHEN sum(COALESCE(p.subscription, 0)) = 0 THEN 'api' ELSE 'mixed' END
    FROM ($(window_launches_sql)) l LEFT JOIN cost_sessions p
        ON p.tool = l.tool AND p.session_id = l.parent_session_id
    WHERE l.estimated_cost_usd IS NOT NULL)
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
            'label', CASE WHEN slot < 4 THEN first_model ELSE 'Other' END,
            'members', json(member_list), 'total', printf('%.2f', total)))
        FROM (SELECT slot, min(model) AS first_model,
                json_group_array(model) AS member_list, sum(total) AS total
            FROM (SELECT * FROM cost_series ORDER BY total DESC, model)
            GROUP BY slot ORDER BY slot))),
    'scale_max', (SELECT step * 4 FROM cost_scale),
    'ticks', $(scale_ticks_sql cost_scale),
    'kind', (SELECT CASE WHEN other_usd = 0 THEN 'subscription'
            WHEN subscription_usd = 0 THEN 'api' ELSE 'mixed' END FROM cost_split),
    'subscription_usd', (SELECT printf('%.2f', subscription_usd) FROM cost_split),
    'other_usd', (SELECT printf('%.2f', other_usd) FROM cost_split),
    'projects', json((SELECT json_group_array(json_object('project', project,
            'usd', usd, 'total', printf('%.2f', usd),
            'sessions', printf('%d', sessions)))
        FROM (SELECT * FROM cost_project_slots ORDER BY slot))),
    'top_sessions', $(sessions_json_sql),
    'agent_types', $(agent_types_json_sql),
    'launch_kind', $(launch_kind_sql),
    'burn', $(burn_json_sql))
SQL
}

# The one statement the page is built from, so every figure comes from one read transaction.
# Local-time formatting happens here; report.jq does no date handling. The heredoc expands
# $now and \$[...], so interpolate only validated numbers or sql_str output. A subquery's JSON
# result can lose its JSON type and nest as a quoted string, so json() wraps each one.
blob_sql() {
    local now="$1" home="${HOME:-}" tmpdir="${TMPDIR:-}"
    home="${home%/}"
    tmpdir="${tmpdir%/}"
    tmpdir="${tmpdir#/private}"
    cat <<SQL
WITH RECURSIVE clock(offset_min, now_iso, scan_from_iso, cost_from_iso, home, tmpdir) AS (
    SELECT CAST(round((julianday($now, 'unixepoch', 'localtime')
        - julianday($now, 'unixepoch')) * 1440) AS INTEGER),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now, 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ', $now - 8 * 86400, 'unixepoch'),
        strftime('%Y-%m-%dT%H:%M:%SZ',
            date($now, 'unixepoch', 'localtime', '-30 days'), 'utc'),
        COALESCE($(sql_str "$home"), ''), COALESCE($(sql_str "$tmpdir"), '')
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
-- The last row carrying the 7d tile's figure is when this machine last saw it: a later, lower
-- figure is another session's stale report. Rate-limit rows are written only when a percentage
-- changes, so a later cost snapshot whose payload carried the same figure can be later still. Its
-- raw_json scan covers the last 8 days, enough for the current 7d window.
observed(at) AS (
    SELECT min(max(
        COALESCE((SELECT max(r.occurred_at) FROM rate_limit_snapshots r
            WHERE r.tool = 'claude-code' AND r.seven_day_resets_at IS w.resets_at
                AND r.seven_day_used_percentage = w.pct), ''),
        COALESCE((SELECT occurred_at FROM cost_snapshots
            WHERE id > (SELECT scan_id FROM cutoffs) AND tool = 'claude-code'
                AND occurred_at >= scan_from_iso
                AND $(payload_sql raw_json seven_day.used_percentage) = w.pct
                AND $(payload_sql raw_json seven_day.resets_at) IS w.resets_at
            ORDER BY id DESC LIMIT 1), '')), now_iso)
    FROM clock, windows w WHERE w.name = 'seven_day'
),
quota_seen(seen) AS (
    SELECT EXISTS (SELECT 1 FROM rate_limit_snapshots
        WHERE tool = 'claude-code' AND seven_day_used_percentage IS NOT NULL)
),
$(cost_ctes_sql)
SELECT json_object(
    'generated_at', datetime($now, 'unixepoch', 'localtime'),
    'utc_offset', (SELECT 'UTC' || CASE WHEN offset_min = 0 THEN ''
        ELSE CASE WHEN offset_min < 0 THEN '−' ELSE '+' END || (abs(offset_min) / 60)
            || CASE WHEN abs(offset_min) % 60 = 0 THEN ''
                ELSE printf(':%02d', abs(offset_min) % 60) END
        END FROM clock),
    'quota_observed', (SELECT seen FROM quota_seen),
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
    local used="" left="" pace="" level="" delta points
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
            points=points
            ((delta == 1 || delta == -1)) && points=point
            if ((delta > 0)); then
                pace="$delta $points over an even pace"
            elif ((delta < 0)); then
                pace="${delta#-} $points under an even pace"
            else
                pace="Level with an even pace"
            fi
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
