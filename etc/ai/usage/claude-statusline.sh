#!/bin/bash
# Claude Code "statusLine" integration: records this session's cumulative
# cost/token usage to the local ai-usage SQLite store as a side effect, then
# prints the status line text Claude Code displays. Also appends a
# cost_snapshots row whenever total_cost_usd has changed since this
# session's last recorded snapshot, preserving the trajectory that the
# upsert-only sessions table would otherwise overwrite.
#
# Wired via etc/claude-code/settings.json "statusLine". Payload arrives as
# JSON on stdin; see https://code.claude.com/docs/en/statusline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

PAYLOAD=$(cat)

# Unit separator, not tab: tab is IFS whitespace, so read would collapse empty fields.
IFS=$'\x1f' read -r SESSION_ID CWD PROJECT_DIR MODEL_ID MODEL_DISPLAY EFFORT \
    COST_USD DURATION_MS API_DURATION_MS INPUT_TOKENS OUTPUT_TOKENS \
    CACHE_CREATION CACHE_READ CTX_USED_PCT FIVE_HOUR_PCT SEVEN_DAY_PCT \
    FIVE_HOUR_RESETS SEVEN_DAY_RESETS <<<"$(
        printf '%s' "$PAYLOAD" | jq -r '[
        .session_id, .workspace.current_dir, .workspace.project_dir,
        .model.id, .model.display_name, .effort.level,
        .cost.total_cost_usd, .cost.total_duration_ms, .cost.total_api_duration_ms,
        .context_window.total_input_tokens, .context_window.total_output_tokens,
        .context_window.current_usage.cache_creation_input_tokens,
        .context_window.current_usage.cache_read_input_tokens,
        .context_window.used_percentage,
        .rate_limits.five_hour.used_percentage, .rate_limits.seven_day.used_percentage,
        .rate_limits.five_hour.resets_at, .rate_limits.seven_day.resets_at
    ] | join("\u001f")'
    )"

if [[ -n "$SESSION_ID" ]]; then
    usage_db_init
    NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    sqlite3 "$USAGE_DB" "
        INSERT INTO sessions (
            tool, session_id, cwd, project_dir, model, effort,
            started_at, updated_at, total_cost_usd, input_tokens, output_tokens,
            last_turn_cache_creation_tokens, last_turn_cache_read_tokens,
            total_duration_ms, total_api_duration_ms, credits, raw_json
        ) VALUES (
            'claude-code', $(sql_str "$SESSION_ID"), $(sql_str "$CWD"), $(sql_str "$PROJECT_DIR"),
            $(sql_str "$MODEL_ID"), $(sql_str "$EFFORT"),
            $(sql_str "$NOW"), $(sql_str "$NOW"), $(sql_num "$COST_USD"),
            $(sql_num "$INPUT_TOKENS"), $(sql_num "$OUTPUT_TOKENS"),
            $(sql_num "$CACHE_CREATION"), $(sql_num "$CACHE_READ"),
            $(sql_num "$DURATION_MS"), $(sql_num "$API_DURATION_MS"),
            NULL, $(sql_str "$PAYLOAD")
        )
        ON CONFLICT(tool, session_id) DO UPDATE SET
            cwd = excluded.cwd,
            project_dir = excluded.project_dir,
            model = excluded.model,
            effort = excluded.effort,
            updated_at = excluded.updated_at,
            total_cost_usd = excluded.total_cost_usd,
            input_tokens = excluded.input_tokens,
            output_tokens = excluded.output_tokens,
            last_turn_cache_creation_tokens = excluded.last_turn_cache_creation_tokens,
            last_turn_cache_read_tokens = excluded.last_turn_cache_read_tokens,
            total_duration_ms = excluded.total_duration_ms,
            total_api_duration_ms = excluded.total_api_duration_ms,
            raw_json = excluded.raw_json;
    "

    # Comparing costs in SQL (not bash) so REAL equality is exact -- SQLite's
    # text rendering of a REAL (e.g. "1.0") won't always string-match jq's
    # rendering of the same number (e.g. "1.00"), so a bash string compare
    # would false-negative and insert a duplicate row on every firing.
    sqlite3 "$USAGE_DB" "
        INSERT INTO cost_snapshots (
            tool, session_id, total_cost_usd, input_tokens, output_tokens,
            cache_creation_tokens, cache_read_tokens, context_used_percentage,
            occurred_at, raw_json
        )
        SELECT 'claude-code', $(sql_str "$SESSION_ID"), $(sql_num "$COST_USD"),
            $(sql_num "$INPUT_TOKENS"), $(sql_num "$OUTPUT_TOKENS"),
            $(sql_num "$CACHE_CREATION"), $(sql_num "$CACHE_READ"), $(sql_num "$CTX_USED_PCT"),
            $(sql_str "$NOW"), $(sql_str "$PAYLOAD")
        WHERE (
            SELECT total_cost_usd FROM cost_snapshots
            WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID")
            ORDER BY id DESC LIMIT 1
        ) IS NOT $(sql_num "$COST_USD");
    "

    # rate_limits only exists for claude.ai subscribers (see DISPLAY_USAGE
    # below); account-wide, not per-session, so no session_id and no
    # per-session dedup scoping -- see schema.sql's rate_limit_snapshots
    # comment.
    if [[ -n "$FIVE_HOUR_PCT" || -n "$SEVEN_DAY_PCT" ]]; then
        sqlite3 "$USAGE_DB" "
            INSERT INTO rate_limit_snapshots (
                tool, five_hour_used_percentage, seven_day_used_percentage,
                five_hour_resets_at, seven_day_resets_at, occurred_at, raw_json
            )
            SELECT 'claude-code', $(sql_num "$FIVE_HOUR_PCT"), $(sql_num "$SEVEN_DAY_PCT"),
                $(sql_num "$FIVE_HOUR_RESETS"), $(sql_num "$SEVEN_DAY_RESETS"),
                $(sql_str "$NOW"), $(sql_str "$PAYLOAD")
            WHERE (
                SELECT five_hour_used_percentage FROM rate_limit_snapshots
                WHERE tool = 'claude-code' ORDER BY id DESC LIMIT 1
            ) IS NOT $(sql_num "$FIVE_HOUR_PCT")
            OR (
                SELECT seven_day_used_percentage FROM rate_limit_snapshots
                WHERE tool = 'claude-code' ORDER BY id DESC LIMIT 1
            ) IS NOT $(sql_num "$SEVEN_DAY_PCT");
        "
    fi
fi

format_pct() {
    if [[ -z "$1" || "$1" == "null" ]]; then
        printf '?%%'
    else
        printf '%.0f%%' "$1"
    fi
}

# resets_at is Unix epoch seconds; integer arithmetic keeps this free of GNU date.
format_remaining() {
    local resets_at="$1" now="$2" remaining
    [[ -z "$resets_at" || "$resets_at" == "null" ]] && return 0
    remaining=$((resets_at - now))
    ((remaining < 0)) && remaining=0
    if ((remaining >= 86400)); then
        printf ' (%dd %dh)' $((remaining / 86400)) $((remaining % 86400 / 3600))
    else
        printf ' (%dh %dm)' $((remaining / 3600)) $((remaining % 3600 / 60))
    fi
}

SEVEN_DAY_SECONDS=604800
PACE_YELLOW_POINTS=10
PACE_RED_POINTS=20
PACE_ROOM_POINTS=-15

# Points the 7d usage sits above (+) or below (-) an even burn across the
# window. Points rather than a ratio, so a few percent in the first hours
# doesn't read as many times over pace. The window is fixed, not rolling:
# resets_at advances by exactly SEVEN_DAY_SECONDS between windows.
is_missing() {
    [[ -z "$1" || "$1" == "null" ]]
}

pace_delta() {
    local used_pct="$1" resets_at="$2" now="$3" window="${4:-$SEVEN_DAY_SECONDS}" used elapsed
    is_missing "$used_pct" && return 0
    is_missing "$resets_at" && return 0
    used="$(printf '%.0f' "$used_pct")"
    elapsed=$((window - (resets_at - now)))
    ((elapsed < 0)) && elapsed=0
    ((elapsed > window)) && elapsed=$window
    printf '%d' $((used - (elapsed * 100 + window / 2) / window))
}

pace_color() {
    local delta="$1"
    if ((delta >= PACE_RED_POINTS)); then
        printf '%s' $'\033[31m'
    elif ((delta >= PACE_YELLOW_POINTS)); then
        printf '%s' $'\033[33m'
    elif ((delta <= PACE_ROOM_POINTS)); then
        printf '%s' $'\033[32m'
    fi
}

CREDITS_CLAUDE_JSON="${USAGE_CLAUDE_JSON:-${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json}"

is_uint() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# Whitelisted fields only: ~/.claude.json also holds account identifiers, which must never print.
read_credits_fields() {
    [[ -r "$CREDITS_CLAUDE_JSON" ]] || return 0
    jq -r '
        (.cachedUsageUtilization // {}) as $cache
        | ($cache.utilization.extra_usage // {}) as $extra
        | [$extra.is_enabled, $extra.used_credits, $extra.monthly_limit, $cache.fetchedAtMs]
        | map(tostring) | join("\u001f")
    ' "$CREDITS_CLAUDE_JSON" 2>/dev/null || true
}

# Calendar month containing $1 in America/Chicago, the zone the /usage panel reports resets in.
# Prints "start end" as Unix epoch seconds. /bin/date is the BSD binary; a GNU date earlier on
# PATH (Homebrew coreutils) rejects -j, so the system binary is named explicitly.
chicago_month_bounds() {
    local start_text
    start_text="$(TZ=America/Chicago /bin/date -r "$1" +%Y-%m)-01 00:00:00"
    printf '%s %s\n' \
        "$(TZ=America/Chicago /bin/date -j -f '%Y-%m-%d %H:%M:%S' "$start_text" +%s)" \
        "$(TZ=America/Chicago /bin/date -j -v+1m -f '%Y-%m-%d %H:%M:%S' "$start_text" +%s)"
}

# Prints the monthly credits segment, or nothing when the cache has no usable figure for this month.
credits_segment() {
    local now="$1" enabled used limit fetched_ms
    local month_start month_end percent delta color segment
    IFS=$'\x1f' read -r enabled used limit fetched_ms <<<"$(read_credits_fields)" || true
    [[ "$enabled" == true ]] || return 0
    is_uint "$used" && is_uint "$limit" && is_uint "$fetched_ms" || return 0
    ((limit > 0)) || return 0
    read -r month_start month_end <<<"$(chicago_month_bounds "$now")" || return 0
    # A cache fetched before this month's start would be paced against the wrong month.
    ((fetched_ms / 1000 >= month_start)) || return 0
    percent=$(((used * 100 + limit / 2) / limit))
    segment="usage ${percent}%$(format_remaining "$month_end" "$now")"
    delta="$(pace_delta "$percent" "$month_end" "$now" $((month_end - month_start)))"
    if [[ -n "$delta" ]]; then
        segment+=" $(printf '%+d' "$delta")"
        color="$(pace_color "$delta")"
        [[ -n "$color" ]] && segment="$color$segment"$'\033[0m'
    fi
    printf '%s' "$segment"
}

DISPLAY_MODEL="${MODEL_DISPLAY:-?}"
DISPLAY_COST="\$0.00"
[[ -n "$COST_USD" && "$COST_USD" != "null" ]] && DISPLAY_COST="$(printf '$%.4f' "$COST_USD")"
NOW_EPOCH="${USAGE_NOW_EPOCH:-$(date +%s)}"
HAS_RATE_LIMITS="$(printf '%s' "$PAYLOAD" | jq -r '.rate_limits != null')"
# rate_limits only exists for claude.ai subscribers. Enterprise and API keep the cost figure,
# plus the monthly credits segment when the cache has one.
DISPLAY_USAGE="$DISPLAY_COST"
if [[ -n "$FIVE_HOUR_PCT" || -n "$SEVEN_DAY_PCT" ]]; then
    FIVE_HOUR_DISPLAY="5h $(format_pct "$FIVE_HOUR_PCT")$(format_remaining "$FIVE_HOUR_RESETS" "$NOW_EPOCH")"
    SEVEN_DAY_DISPLAY="7d $(format_pct "$SEVEN_DAY_PCT")$(format_remaining "$SEVEN_DAY_RESETS" "$NOW_EPOCH")"
    PACE_DELTA="$(pace_delta "$SEVEN_DAY_PCT" "$SEVEN_DAY_RESETS" "$NOW_EPOCH")"
    if [[ -n "$PACE_DELTA" ]]; then
        SEVEN_DAY_DISPLAY="$SEVEN_DAY_DISPLAY $(printf '%+d' "$PACE_DELTA")"
        PACE_COLOR="$(pace_color "$PACE_DELTA")"
        [[ -n "$PACE_COLOR" ]] && SEVEN_DAY_DISPLAY="$PACE_COLOR$SEVEN_DAY_DISPLAY"$'\033[0m'
    fi
    DISPLAY_USAGE="$FIVE_HOUR_DISPLAY | $SEVEN_DAY_DISPLAY"
elif [[ "$HAS_RATE_LIMITS" != true ]]; then
    CREDITS_DISPLAY="$(credits_segment "$NOW_EPOCH")"
    [[ -n "$CREDITS_DISPLAY" ]] && DISPLAY_USAGE="$DISPLAY_COST | $CREDITS_DISPLAY"
fi
DISPLAY_CTX="${CTX_USED_PCT:-0}"
DISPLAY_EFFORT=""
[[ -n "$EFFORT" && "$EFFORT" != "null" ]] && DISPLAY_EFFORT=" | effort:$EFFORT"

printf '%s | %s | %s%% ctx%s\n' "$DISPLAY_MODEL" "$DISPLAY_USAGE" "$DISPLAY_CTX" "$DISPLAY_EFFORT"
