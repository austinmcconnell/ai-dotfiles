#!/bin/bash
# Checks usage_db_init's user_version migration runner: new, untracked, and
# versioned DBs, failed and concurrent migrations. Every DB lives in a temp dir,
# so the real usage.db is never read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILURES=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# Run usage_db_init in a fresh /bin/bash, as the statusline does, so set -e
# applies inside it and macOS's bash 3.2 is what runs it. $1 names the DB
# directory; $2 is a copy of the usage dir with extra migrations, if any.
run_init() {
    USAGE_DB_DIR="$WORK/$1" /bin/bash -c 'source "$1/lib.sh"; usage_db_init' _ "${2:-$USAGE_DIR}"
}

db() {
    sqlite3 "$WORK/$1/usage.db" "$2"
}

version() {
    db "$1" 'PRAGMA user_version;'
}

schema_text() {
    db "$1" 'SELECT name, sql FROM sqlite_master ORDER BY name;'
}

# Column order differs between CREATE TABLE and ALTER TABLE ADD COLUMN, and
# every writer names its columns, so compare columns as a sorted set.
shape() {
    db "$1" "
        SELECT m.type, m.name, p.name, p.type, p.\"notnull\", p.dflt_value, p.pk
        FROM sqlite_master m LEFT JOIN pragma_table_info(m.name) p
        ORDER BY m.name, p.name;"
}

# An untracked DB in $1, as the old code left it: the version 1 baseline,
# altered by the SQL in $2.
untracked_db() {
    mkdir -p "$WORK/$1"
    {
        cat "$USAGE_DIR"/migrations/0001-*.sql
        printf '%s\n' "$2"
    } | sqlite3 "$WORK/$1/usage.db"
}

# A copy of the usage dir in $1 whose migrations add the SQL in $2 as the migration after the
# newest real one.
usage_dir_with_next_migration() {
    mkdir -p "$WORK/$1/migrations"
    cp "$USAGE_DIR"/lib.sh "$USAGE_DIR"/schema.sql "$WORK/$1/"
    cp "$USAGE_DIR"/migrations/*.sql "$WORK/$1/migrations/"
    printf '%s\n' "$2" >"$WORK/$1/migrations/${next_prefix}-test.sql"
}

DROP_0001_COLUMNS="
    ALTER TABLE compaction_events DROP COLUMN real_pre_tokens;
    ALTER TABLE compaction_events DROP COLUMN real_post_tokens;
    ALTER TABLE compaction_events DROP COLUMN cumulative_dropped_tokens;
    ALTER TABLE compaction_events DROP COLUMN duration_ms;"

latest="$(find "$USAGE_DIR/migrations" -name '[0-9][0-9][0-9][0-9]-*.sql' | sort | tail -n 1)"
latest="$((10#$(basename "$latest" | cut -c 1-4)))"
next="$((latest + 1))"
printf -v next_prefix '%04d' "$next"
printf -v after_next_prefix '%04d' "$((next + 1))"

run_init new
check "new DB is at the newest version" "$latest" "$(version new)"
check "new DB has every table" 5 "$(db new "
    SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name != 'sqlite_sequence';")"
before="$(schema_text new)"
run_init new
check "re-running on a current DB changes nothing" "$before" "$(schema_text new)"

untracked_db legacy "$DROP_0001_COLUMNS
    INSERT INTO compaction_events (tool, session_id, hook_event, occurred_at)
        VALUES ('claude-code', 's1', 'PreCompact', '2026-09-01T00:00:00Z');"
run_init legacy
check "untracked DB without the compaction columns reaches the newest version" "$latest" \
    "$(version legacy)"
check "migrated DB has the same shape as a new one" "$(shape new)" "$(shape legacy)"
check "migration keeps existing rows" 1 "$(db legacy 'SELECT count(*) FROM compaction_events;')"

untracked_db current "
    INSERT INTO sessions (tool, session_id, started_at, updated_at)
        VALUES ('claude-code', 's1', '2026-11-01T00:00:00Z', '2026-11-01T00:00:00Z');"
before="$(schema_text current)"
run_init current
check "untracked DB with the compaction columns keeps its schema" "$before" \
    "$(schema_text current)"
check "stamped DB is at the newest version" "$latest" "$(version current)"
check "stamping keeps existing rows" 1 "$(db current 'SELECT count(*) FROM sessions;')"

untracked_db partial "
    ALTER TABLE compaction_events DROP COLUMN real_pre_tokens;
    ALTER TABLE compaction_events DROP COLUMN duration_ms;"
run_init partial
check "untracked DB with some compaction columns gets the rest" "$(shape new)" "$(shape partial)"

untracked_db missing-tables "DROP TABLE rate_limit_snapshots; DROP TABLE compaction_events;"
run_init missing-tables
check "untracked DB gets tables it lacks" "$(shape new)" "$(shape missing-tables)"

# The subagent name backfill: a description replaces the stored name, and every row it cannot
# read keeps its name without failing the migration.
subagent_row() {
    printf "INSERT INTO subagent_tasks (tool, parent_session_id, task_id, name, started_at,
        updated_at, raw_json) VALUES ('claude-code', 's', '%s', 'keep', '2026-11-01T00:00:00Z',
        '2026-11-01T00:00:00Z', %s);\n" "$1" "$2"
}
untracked_db names "
    $(subagent_row m1 "'{\"tasks\":[{\"id\":\"m1\",\"label\":\"activity\",\"description\":\"Launch\"}]}'")
    $(subagent_row m2 "'{\"tasks\":[{\"id\":\"m2\",\"label\":\"activity\"}]}'")
    $(subagent_row m3 'NULL')
    $(subagent_row m4 "'not json'")
    $(subagent_row m5 "'{\"tasks\":5}'")
    $(subagent_row m6 "'{\"tasks\":[\"x\",1,null]}'")
    $(subagent_row m7 "'{\"tasks\":[{\"id\":\"other\",\"description\":\"Other\"}]}'")
    $(subagent_row m8 "'{\"tasks\":[{\"id\":\"m8\",\"description\":\"\"}]}'")
    $(subagent_row m9 "'{\"tasks\":[{\"id\":\"m9\",\"description\":5}]}'")
    $(subagent_row m10 "'{\"tasks\":[{\"id\":\"m10\",\"description\":\"First\"},
        {\"id\":\"m10\",\"description\":\"Second\"}]}'")
    $(subagent_row m11 "'{\"tasks\":[{\"id\":\"x\"},{\"id\":\"m11\",\"description\":\"Second task\"}]}'")"
rc=0
run_init names 2>"$WORK/names.err" || rc=$?
check "name backfill migration succeeds on malformed rows" "0 $latest" "$rc $(version names)"
check "name backfill sets a description and keeps every unreadable row's name" \
    "m1=Launch m10=First m11=Second task m2=keep m3=keep m4=keep m5=keep m6=keep m7=keep m8=keep m9=keep" \
    "$(db names "SELECT group_concat(task_id || '=' || name, ' ') FROM
        (SELECT task_id, name FROM subagent_tasks ORDER BY task_id);")"
check "name backfill migration leaves the same shape as a new DB" "$(shape new)" "$(shape names)"

# A later migration must apply on top of an adopted DB that lacked the table
# it changes, which it could not if adoption used the newest schema.sql.
usage_dir_with_next_migration later-dir 'ALTER TABLE rate_limit_snapshots ADD COLUMN later INTEGER;'
untracked_db later "DROP TABLE rate_limit_snapshots;"
run_init later "$WORK/later-dir"
check "a later migration applies to an adopted DB that lacked its table" "$next" "$(version later)"

run_init failing
usage_dir_with_next_migration failing-dir \
    'CREATE TABLE half_done (a); SELECT * FROM missing_table;'
rc=0
run_init failing "$WORK/failing-dir" 2>"$WORK/failing.err" || rc=$?
check "failed migration returns non-zero" 1 "$rc"
check "failed migration leaves the version alone" "$latest" "$(version failing)"
check "failed migration leaves no partial schema" 0 \
    "$(db failing "SELECT count(*) FROM sqlite_master WHERE name = 'half_done';")"
check "failed migration reports the SQL error" 1 \
    "$(grep -c 'no such table: missing_table' "$WORK/failing.err")"

run_init gap
usage_dir_with_next_migration gap-dir 'SELECT 1;'
mv "$WORK/gap-dir/migrations/${next_prefix}-test.sql" \
    "$WORK/gap-dir/migrations/${after_next_prefix}-test.sql"
rc=0
run_init gap "$WORK/gap-dir" 2>/dev/null || rc=$?
check "a missing migration number fails" 1 "$rc"
check "a missing migration number leaves the version alone" "$latest" "$(version gap)"

run_init newer
db newer 'PRAGMA user_version = 99;'
rc=0
run_init newer || rc=$?
check "a DB newer than the migrations is left alone" "0 99" "$rc $(version newer)"

# Concurrent callers: every one must succeed quietly and the change must
# apply once. Prints the failed-caller count, then the stderr line count.
race() {
    local dir="$1" usage_dir="${2:-$USAGE_DIR}" pids=() pid failed=0
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do
        run_init "$dir" "$usage_dir" 2>>"$WORK/$dir.err" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=$((failed + 1))
    done
    echo "$failed $(wc -l <"$WORK/$dir.err" | tr -d ' ')"
}

check "concurrent callers on a new DB all succeed quietly" "0 0" "$(race race-new)"
check "concurrent callers on a new DB reach the newest version" "$latest" "$(version race-new)"

run_init race-migrate
usage_dir_with_next_migration race-dir 'ALTER TABLE sessions ADD COLUMN race_column INTEGER;'
check "concurrent migrators all succeed quietly" "0 0" "$(race race-migrate "$WORK/race-dir")"
check "concurrent migrators reach the new version" "$next" "$(version race-migrate)"
check "concurrent migrators add the column once" 1 "$(db race-migrate "
    SELECT count(*) FROM pragma_table_info('sessions') WHERE name = 'race_column';")"

if ((FAILURES > 0)); then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
