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

# Create the DB directory and apply the schema. Safe to call on every
# invocation: CREATE TABLE IF NOT EXISTS makes this idempotent.
#
# CREATE TABLE IF NOT EXISTS never adds columns to a table that already
# exists on disk, so new nullable columns on an existing table need an
# explicit ALTER TABLE here. sqlite has no "ADD COLUMN IF NOT EXISTS", so
# each ALTER is run unconditionally and its "duplicate column" error (on a
# DB that already has the column) is swallowed — this is the repo's first
# schema migration; add future ones the same way.
usage_db_init() {
    mkdir -p "$USAGE_DB_DIR"
    sqlite3 "$USAGE_DB" <"$USAGE_SCHEMA"
    sqlite3 "$USAGE_DB" "ALTER TABLE compaction_events ADD COLUMN real_pre_tokens INTEGER;" 2>/dev/null || true
    sqlite3 "$USAGE_DB" "ALTER TABLE compaction_events ADD COLUMN real_post_tokens INTEGER;" 2>/dev/null || true
    sqlite3 "$USAGE_DB" "ALTER TABLE compaction_events ADD COLUMN cumulative_dropped_tokens INTEGER;" 2>/dev/null || true
    sqlite3 "$USAGE_DB" "ALTER TABLE compaction_events ADD COLUMN duration_ms INTEGER;" 2>/dev/null || true
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
# in the column order the read loop in claude-subagent-statusline.sh expects.
usage_subagent_task_rows() {
    jq -r '.tasks[]? | [
        .id, .label, .agentType, .model, null, .tokenCount,
        .contextWindowSize, (if .startTime then (.startTime / 1000 | todate) else null end),
        .status
    ] | join("\u001f")' <<<"$1"
}

# Prices a subagent transcript request by request, mirroring pricing.json. Inputs: $pricing (the
# slurped file) and $transcript (raw text). Malformed lines are skipped because the file may be
# mid-write. Emits nothing when there are no requests, a request lacks requestId, or any model is
# unpriced: a partial total is never reported as the task's cost.
# shellcheck disable=SC2016
USAGE_TRANSCRIPT_COST_JQ='
def is_version: (. // "") | test("^[0-9]+(\\.[0-9]+)*$");
def version_key: split(".") | map(tonumber);
def read_multiplier($m; $version):
    if $m.cache_read_multiplier_before_version != null
        and ($version | is_version)
        and ($version | version_key)
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
    | rates($m; $in + $read + $write) as $rate
    | (($in * $rate[0]) + ($out * $rate[1])
        + ($writes[0] * $rate[0] * $pricing[0].cache_write_multiplier_5m)
        + ($writes[1] * $rate[0] * $pricing[0].cache_write_multiplier_1h)
        + ($read * $rate[0] * read_multiplier($m; $r.version))) / 1000000;
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
