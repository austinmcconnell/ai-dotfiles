#!/bin/bash
# Shared helpers for the local AI usage/cost tracking store.
# Sourced by per-tool ingestion scripts (e.g. claude-statusline.sh).
# Not meant to be executed directly.

set -euo pipefail

USAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DB_DIR="${USAGE_DB_DIR:-$HOME/.local/share/ai-usage}"
USAGE_DB="$USAGE_DB_DIR/usage.db"
USAGE_SCHEMA="$USAGE_DIR/schema.sql"
USAGE_PRICING="$USAGE_DIR/pricing.json"
USAGE_MIGRATIONS="$USAGE_DIR/migrations"
USAGE_DB_BUSY_TIMEOUT_MS=5000

# Bring the DB to the newest schema version. PRAGMA user_version holds the
# DB's version, and migrations/NNNN-*.sql takes a DB from version NNNN-1 to
# NNNN. A DB already at the newest version costs one sqlite3 read, so this is
# safe to call on every statusline render. A DB newer than this checkout's
# migrations is left alone, since migrations only add.
usage_db_init() {
    local latest current=0
    usage_latest_version latest
    if [[ -f "$USAGE_DB" ]]; then
        current="$(usage_sql 'PRAGMA user_version;')" || return 1
    fi
    ((current >= latest)) && return 0
    mkdir -p "$USAGE_DB_DIR"
    if ((current == 0)); then
        usage_db_init_unversioned "$latest"
    fi
    usage_db_migrate "$latest"
}

# Wait out another session's write lock rather than fail on it.
usage_sql() {
    sqlite3 -bail -cmd ".timeout $USAGE_DB_BUSY_TIMEOUT_MS" "$USAGE_DB" "$@"
}

# Set the variable named by $1 to the highest migration number, without
# spawning a process: the glob expands in lexical order, which the 4-digit
# prefix makes numeric order.
usage_latest_version() {
    local files count last
    files=("$USAGE_MIGRATIONS"/????-*.sql)
    if [[ ! -f "${files[0]}" ]]; then
        echo "usage_db_init: no migrations in $USAGE_MIGRATIONS" >&2
        return 1
    fi
    count="${#files[@]}"
    last="${files[count - 1]##*/}"
    printf -v "$1" '%d' "$((10#${last%%-*}))"
}

# Version 0 is either a new DB or one created before user_version was
# tracked. A new DB gets schema.sql and jumps straight to the newest version.
# An untracked DB becomes exactly version 1, whatever the old code left: the
# frozen 0001 baseline creates missing tables, and compaction_events gets
# whichever of its later columns it lacks. schema.sql can't serve here, since
# its newer shape would collide with the migrations after 0001.
usage_db_init_unversioned() {
    local latest="$1" tables missing column body
    tables="$(usage_sql "SELECT count(*) FROM sqlite_master WHERE type = 'table';")"
    if ((tables == 0)); then
        body="$(cat "$USAGE_SCHEMA")"
        usage_db_step 0 "$latest" "$body"
        return
    fi
    missing="$(usage_sql "
        SELECT column1 FROM (VALUES ('real_pre_tokens'), ('real_post_tokens'),
            ('cumulative_dropped_tokens'), ('duration_ms'))
        WHERE EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'compaction_events')
            AND column1 NOT IN (SELECT name FROM pragma_table_info('compaction_events'));")"
    body="$(cat "$USAGE_MIGRATIONS"/0001-*.sql)"
    for column in $missing; do
        body+=$'\n'"ALTER TABLE compaction_events ADD COLUMN $column INTEGER;"
    done
    usage_db_step 0 1 "$body"
}

# Apply each migration after the DB's current version, up to $1.
usage_db_migrate() {
    local latest="$1" current next prefix files body
    current="$(usage_sql 'PRAGMA user_version;')" || return 1
    while ((current < latest)); do
        next=$((current + 1))
        printf -v prefix '%04d' "$next"
        files=("$USAGE_MIGRATIONS/$prefix"-*.sql)
        if [[ ${#files[@]} -ne 1 || ! -f "${files[0]}" ]]; then
            echo "usage_db_init: need exactly one $USAGE_MIGRATIONS/$prefix-*.sql" >&2
            return 1
        fi
        body="$(cat "${files[0]}")"
        usage_db_step "$current" "$next" "$body" || return 1
        current="$(usage_sql 'PRAGMA user_version;')" || return 1
    done
}

# Run the SQL in $3 and set user_version to $2 in one transaction, which
# rolls back unless user_version is still $1. A concurrent caller that got
# there first is not a failure. Callers read SQL files up front, because a
# file that failed to read mid-pipe would still let COMMIT bump the version.
usage_db_step() {
    local from="$1" to="$2" body="$3" err current
    if err="$({
        printf 'BEGIN IMMEDIATE;\n'
        printf 'CREATE TEMP TABLE usage_version_guard (v CHECK (v = %d));\n' "$from"
        printf 'INSERT INTO usage_version_guard SELECT user_version FROM pragma_user_version;\n'
        printf '%s\n' "$body"
        printf 'PRAGMA user_version = %d;\nCOMMIT;\n' "$to"
    } | usage_sql 2>&1)"; then
        return 0
    fi
    current="$(usage_sql 'PRAGMA user_version;')" || return 1
    ((current >= to)) && return 0
    echo "usage_db_init: $USAGE_DB version $from -> $to failed: $err" >&2
    return 1
}

# Render a value as a single-quoted, escaped SQL string literal.
# Empty/absent input, or jq's "null", becomes the SQL literal NULL.
sql_str() {
    local value="${1:-}"
    if [[ -z "$value" || "$value" == "null" ]]; then
        printf 'NULL'
    else
        printf "'%s'" "$(printf '%s' "$value" | sed "s/'/''/g")"
    fi
}

# Pass a number through as a bare SQL literal, or NULL when absent/non-numeric.
sql_num() {
    local value="${1:-}"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        printf 'NULL'
    fi
}

# One unit-separator-joined row per subagent task in a subagentStatusLine payload,
# in the column order the read loop in claude-subagent-statusline.sh expects. The name is the
# launch description, which is fixed, not `.label`, which tracks the live activity. Newlines and
# unit separators in it would split the row, so they become spaces.
usage_subagent_task_rows() {
    jq -r '.tasks[]? | [
        .id,
        ((.description // null) | if type == "string" then gsub("[\n\r\u001f]"; " ") else . end),
        .agentType, .model, null, .tokenCount,
        .contextWindowSize, (if .startTime then (.startTime / 1000 | todate) else null end),
        .status
    ] | join("\u001f")' <<<"$1"
}

# Prices a subagent transcript request by request, mirroring pricing.json. Inputs: $pricing (the
# slurped file) and $transcript (raw text). Malformed lines are skipped because the file may be
# mid-write. Emits nothing when there are no requests, a request lacks requestId, any model is
# unpriced, or a request bills cache reads at a version-dependent multiplier its version cannot
# resolve: a partial total is never reported as the task's cost.
# shellcheck disable=SC2016
USAGE_TRANSCRIPT_COST_JQ='
def is_version: (. // "") | test("^[0-9]+(\\.[0-9]+)*$");
def version_key: split(".") | map(tonumber);
def read_multiplier($m; $version):
    if $m.cache_read_multiplier_before_version == null
    then ($m.cache_read_multiplier // $pricing[0].cache_read_multiplier)
    elif ($version | is_version | not)
    then error("unusable version for a version-dependent cache-read multiplier")
    elif ($version | version_key)
        < ($m.cache_read_multiplier_before_version.version | version_key)
    then $m.cache_read_multiplier_before_version.multiplier
    else ($m.cache_read_multiplier // $pricing[0].cache_read_multiplier)
    end;
def rates($m; $prompt):
    if $m.long_context != null and $prompt > $m.long_context.prompt_tokens_over
    then [$m.long_context.input_per_mtok, $m.long_context.output_per_mtok]
    else [$m.input_per_mtok, $m.output_per_mtok]
    end;
def request_usd($r):
    ($r.message.model // $r.requestedModel) as $name
    | $pricing[0].models[$name] as $m
    | if $m == null then error("unpriced model") else . end
    | $r.message.usage as $u
    | ($u.input_tokens // 0) as $in
    | ($u.output_tokens // 0) as $out
    | ($u.cache_read_input_tokens // 0) as $read
    | ($u.cache_creation_input_tokens // 0) as $write
    | ($u.cache_creation // {}) as $split
    | (if $split.ephemeral_5m_input_tokens == null and $split.ephemeral_1h_input_tokens == null
        then [$write, 0]
        else [$split.ephemeral_5m_input_tokens // 0, $split.ephemeral_1h_input_tokens // 0]
        end) as $writes
    | rates($m; $in + $read + $writes[0] + $writes[1]) as $rate
    | (($in * $rate[0]) + ($out * $rate[1])
        + ($writes[0] * $rate[0] * $pricing[0].cache_write_multiplier_5m)
        + ($writes[1] * $rate[0] * $pricing[0].cache_write_multiplier_1h)
        + (if $read == 0 then 0
            else $read * $rate[0] * read_multiplier($m; $r.version)
            end)) / 1000000;
[$transcript | split("\n")[] | fromjson?
    | select(type == "object" and .type == "assistant"
        and ((.message | type) == "object") and ((.message.usage | type) == "object"))]
    as $requests
| if ($requests | length) == 0 or any($requests[]; (.requestId // "") == "") then empty
    else
        [$requests | group_by(.requestId)[] | last]
        | map(try request_usd(.) catch null)
        | if any(. == null) then empty else add end
    end
'

# Path of a subagent's own transcript, from the parent session's transcript_path.
usage_subagent_transcript_path() {
    local parent_transcript="${1:-}" task_id="${2:-}"
    [[ -z "$parent_transcript" || -z "$task_id" ]] && return 0
    printf '%s/subagents/agent-%s.jsonl' "${parent_transcript%.jsonl}" "$task_id"
}

# Dollar cost of one subagent transcript (see USAGE_TRANSCRIPT_COST_JQ). Prints nothing when the
# file is unreadable or the cost cannot be fully priced; never fails the caller.
usage_transcript_cost() {
    local path="${1:-}" usd
    [[ -r "$path" ]] || return 0
    usd="$(jq -n --slurpfile pricing "$USAGE_PRICING" --rawfile transcript "$path" \
        "$USAGE_TRANSCRIPT_COST_JQ" 2>/dev/null)" || return 0
    if [[ -n "$usd" ]]; then
        printf '%.10f' "$usd"
    fi
    return 0
}

# SQL INSERTs for the compact_boundary records among the grep-filtered lines on stdin. A boundary
# without a numeric preTokens is not a candidate; the other metadata fields may be NULL. The
# uuid and timestamp are pattern-checked because they are interpolated into SQL. $q is a single
# quote, passed in because the program itself sits inside shell single quotes.
# shellcheck disable=SC2016
USAGE_BOUNDARY_INSERT_JQ='
def num: if type == "number" then floor | tostring else "NULL" end;
fromjson? | select(type == "object" and .type == "system" and .subtype == "compact_boundary")
| (.uuid // .timestamp) as $key
| select(($key | type) == "string" and ($key | test("^[A-Za-z0-9._:-]+$"))
    and (.timestamp | type) == "string" and (.timestamp | test("^[0-9T:.Z+-]+$"))
    and (.compactMetadata.preTokens | type) == "number")
| .compactMetadata as $m
| "INSERT OR IGNORE INTO b VALUES (\($q)\($key)\($q), \($q)\(.timestamp)\($q), "
    + "\($m.preTokens | num), \($m.postTokens | num), \($m.cumulativeDroppedTokens | num), "
    + "\($m.durationMs | num));"
'

# Prints the transcript paths that can hold a session's compact_boundary records: the main
# transcript, then the subagent transcripts beside it. Fails when the main one is unreadable.
usage_compaction_transcripts() {
    local main="$1" subagents="${1%.jsonl}/subagents"
    [[ -r "$main" ]] || return 1
    printf '%s\n' "$main"
    if [[ -d "$subagents" ]]; then
        find "$subagents" -maxdepth 1 -type f -name 'agent-*.jsonl' || return 1
    fi
}

# Prints the boundary INSERTs for one transcript. Fails, so the caller leaves the session alone,
# when grep errors (anything but a clean match or no match), jq errors, or the last line holds a
# boundary that does not parse yet, which means Claude Code is still writing it.
usage_compaction_boundary_inserts() {
    local file="$1" matches last status=0
    matches="$(grep --fixed-strings '"compact_boundary"' "$file")" || status=$?
    if ((status > 1)); then
        return 1
    fi
    last="$(tail -n 1 "$file")" || return 1
    if [[ "$last" == *'"compact_boundary"'* ]]; then
        jq --exit-status . <<<"$last" >/dev/null 2>&1 || return 1
    fi
    [[ -n "$matches" ]] || return 0
    jq --raw-input --raw-output --arg q "'" "$USAGE_BOUNDARY_INSERT_JQ" <<<"$matches"
}

# The SQL that pairs one session's PostCompact rows with its boundaries and, depending on $2,
# reports and writes. $3 holds the boundary INSERTs. A row and a boundary pair only when each is
# the other's single candidate within 5 seconds; anything with two candidates is ambiguous and is
# left alone. Modes:
#   live    fill rows whose real_pre_tokens is NULL; never overwrite or clear
#   report  write nothing; print one "class|row id|before|after" line per row
#   apply   report, then fill and correct paired rows, and NULL a row only when it has no
#           candidate and holds another boundary's preTokens (a neighbour's value)
usage_compaction_resolve_sql() {
    local session mode="$2" inserts="$3"
    session="$(sql_str "$1")"
    printf '%s\n%s\n' "CREATE TEMP TABLE b (uuid TEXT PRIMARY KEY, ts TEXT, pre INTEGER,
        post INTEGER, dropped INTEGER, dur INTEGER);" "$inserts"
    [[ "$mode" == report ]] || printf 'BEGIN IMMEDIATE;\n'
    cat <<SQL
CREATE TEMP TABLE r AS
    SELECT id, occurred_at, real_pre_tokens AS pre, real_post_tokens AS post,
        cumulative_dropped_tokens AS dropped, duration_ms AS dur
    FROM compaction_events
    WHERE tool = 'claude-code' AND session_id = $session AND hook_event = 'PostCompact';
CREATE TEMP TABLE cand AS
    SELECT r.id AS row_id, b.uuid AS uuid FROM r JOIN b
        ON abs(julianday(b.ts) - julianday(r.occurred_at)) * 86400 <= 5;
CREATE TEMP TABLE pairs AS
    SELECT r.id AS row_id, b.pre AS n_pre, COALESCE(b.post, r.post) AS n_post,
        COALESCE(b.dropped, r.dropped) AS n_dropped, COALESCE(b.dur, r.dur) AS n_dur,
        r.pre AS o_pre, r.post AS o_post, r.dropped AS o_dropped, r.dur AS o_dur
    FROM cand JOIN r ON r.id = cand.row_id JOIN b ON b.uuid = cand.uuid
    WHERE cand.row_id IN (SELECT row_id FROM cand GROUP BY row_id HAVING count(*) = 1)
        AND cand.uuid IN (SELECT uuid FROM cand GROUP BY uuid HAVING count(*) = 1);
CREATE TEMP TABLE neighbours AS
    SELECT id FROM r
    WHERE pre IS NOT NULL AND id NOT IN (SELECT row_id FROM cand) AND pre IN (SELECT pre FROM b);
SQL
    if [[ "$mode" != live ]]; then
        usage_compaction_report_sql
    fi
    case "$mode" in
    live) usage_compaction_write_sql 'AND real_pre_tokens IS NULL' ;;
    apply)
        usage_compaction_write_sql ''
        printf 'UPDATE compaction_events SET real_pre_tokens = NULL, real_post_tokens = NULL,
            cumulative_dropped_tokens = NULL, duration_ms = NULL
            WHERE id IN (SELECT id FROM neighbours);\n'
        ;;
    esac
    [[ "$mode" == report ]] || printf 'COMMIT;\n'
}

# One line per PostCompact row of the session, then a count summary.
usage_compaction_report_sql() {
    cat <<'SQL'
SELECT * FROM (
    SELECT 'fill' AS class, row_id, o_pre, n_pre FROM pairs WHERE o_pre IS NULL
    UNION ALL
    SELECT 'correct', row_id, o_pre, n_pre FROM pairs
        WHERE o_pre IS NOT NULL AND NOT (o_pre IS n_pre AND o_post IS n_post
            AND o_dropped IS n_dropped AND o_dur IS n_dur)
    UNION ALL
    SELECT 'same', row_id, o_pre, n_pre FROM pairs
        WHERE o_pre IS NOT NULL AND o_pre IS n_pre AND o_post IS n_post
            AND o_dropped IS n_dropped AND o_dur IS n_dur
    UNION ALL
    SELECT 'ambiguous', id, pre, NULL FROM r
        WHERE id IN (SELECT row_id FROM cand) AND id NOT IN (SELECT row_id FROM pairs)
    UNION ALL
    SELECT 'neighbour', id, pre, NULL FROM r WHERE id IN (SELECT id FROM neighbours)
    UNION ALL
    SELECT 'unmatched', id, pre, NULL FROM r
        WHERE id NOT IN (SELECT row_id FROM cand) AND id NOT IN (SELECT id FROM neighbours)
) ORDER BY 2;
SELECT 'summary', (SELECT count(*) FROM r), (SELECT count(*) FROM b), (SELECT count(*) FROM pairs);
SQL
}

# Copies each paired row's boundary into its four real_* columns. $1 adds a condition on the row.
usage_compaction_write_sql() {
    local column from
    printf 'UPDATE compaction_events SET\n'
    for column in real_pre_tokens:n_pre real_post_tokens:n_post \
        cumulative_dropped_tokens:n_dropped duration_ms:n_dur; do
        from="${column#*:}"
        printf '    %s = (SELECT %s FROM pairs WHERE row_id = compaction_events.id)' \
            "${column%:*}" "$from"
        [[ "$column" == duration_ms:* ]] && printf '\n' || printf ',\n'
    done
    printf 'WHERE id IN (SELECT row_id FROM pairs) %s;\n' "$1"
}

# Fills compaction_events.real_* for one session's PostCompact rows from the compact_boundary
# records in its transcripts. Claude Code writes a boundary after the PostCompact hook runs, so the
# hook cannot read its own. $2 is the mode (see usage_compaction_resolve_sql; default live).
# Reads and parses the transcripts before the one write transaction. Returns 3, writing nothing,
# when the session's files cannot all be read cleanly; any other failure returns 1.
usage_resolve_compaction_boundaries() {
    local session="$1" mode="${2:-live}" quoted transcript files file part inserts="" sql
    quoted="$(sql_str "$session")"
    transcript="$(usage_sql "
        WITH paths AS (
            SELECT 1 AS rank, id, CASE WHEN json_valid(raw_json)
                THEN json_extract(raw_json, '\$.transcript_path') END AS path
            FROM compaction_events
            WHERE tool = 'claude-code' AND session_id = $quoted AND hook_event = 'PostCompact'
            UNION ALL
            SELECT 2, 0, CASE WHEN json_valid(raw_json)
                THEN json_extract(raw_json, '\$.transcript_path') END
            FROM sessions WHERE tool = 'claude-code' AND session_id = $quoted)
        SELECT path FROM paths WHERE path IS NOT NULL ORDER BY rank, id DESC LIMIT 1;")" ||
        return 1
    if [[ -z "$transcript" ]]; then
        echo "no transcript path recorded for session $session" >&2
        return 3
    fi
    files="$(usage_compaction_transcripts "$transcript")" || {
        echo "transcript unreadable for session $session: $transcript" >&2
        return 3
    }
    while IFS= read -r file; do
        part="$(usage_compaction_boundary_inserts "$file")" || {
            echo "transcript unreadable or mid-write for session $session: $file" >&2
            return 3
        }
        inserts+="$part"$'\n'
    done <<<"$files"
    sql="$(usage_compaction_resolve_sql "$session" "$mode" "$inserts")" || return 1
    usage_sql <<<"$sql"
}
