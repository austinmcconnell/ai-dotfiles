#!/bin/bash
# Ask the user before an Agent launch that runs on Opus or Fable.
# Claude Code only: wired as a PreToolUse hook with matcher "Agent".
#
# Why a hook: `Agent(...)` entries in permissions.ask do not prompt for subagent launches, even in
# default mode, so they gate nothing. A hook's `ask` does prompt, including for background launches,
# and it overrides the bare `Agent` allow rule.
#
# Asks when the call names the `doubt-reviewer` persona (it pins Opus in its frontmatter, which the
# Agent call never carries) or sets a `model` containing "opus" or "fable".
#
# Also asks when a launch sets no `model`, names a type in INHERITING_TYPES, and the session runs on
# Opus or Fable while weekly quota is tight (pace at the statusline's yellow level): such a launch
# inherits the session model. A launch from inside a subagent (`agent_id` set) inherits that
# subagent's model instead, so it is skipped.
# A new persona with `model: inherit` must be added to INHERITING_TYPES. `general-purpose` is not listed
# because CLAUDE_CODE_SUBAGENT_MODEL puts it on Haiku. The session model and quota come from
# usage.db, which the statusline fills, so surfaces where the statusline does not run (headless
# `claude -p`) are not gated. Any failure reading the DB passes the launch through, since this
# check only saves money. Any other launch passes through with no output.

set -euo pipefail

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

INHERITING_TYPES=" Explore Plan docs jira ansible datadog "
HOOK_DB_TIMEOUT_MS=200

is_inheriting_type() {
    [[ "$INHERITING_TYPES" == *" $1 "* ]]
}

# Prints the session's model id, or nothing when the DB or the row can't be read.
session_model() {
    local session_id="$1"
    [[ -r "$USAGE_DB" ]] || return 0
    sqlite3 -readonly -bail -cmd ".timeout $HOOK_DB_TIMEOUT_MS" "$USAGE_DB" \
        "SELECT model FROM sessions WHERE tool = 'claude-code'
        AND session_id = $(sql_str "$session_id");" 2>/dev/null || return 0
}

# Prints "<row count>|<7d used %>|<7d resets_at>", the last two from the newest row that has both.
quota_row() {
    sqlite3 -readonly -bail -cmd ".timeout $HOOK_DB_TIMEOUT_MS" "$USAGE_DB" \
        "SELECT c.n, r.pct, r.resets
        FROM (SELECT count(*) AS n FROM rate_limit_snapshots WHERE tool = 'claude-code') c
        LEFT JOIN (
            SELECT seven_day_used_percentage AS pct, seven_day_resets_at AS resets
            FROM rate_limit_snapshots
            WHERE tool = 'claude-code'
            AND seven_day_used_percentage IS NOT NULL
            AND seven_day_resets_at IS NOT NULL
            ORDER BY id DESC LIMIT 1
        ) r;" 2>/dev/null || return 0
}

# Prints the ask reason when quota is tight for a session on model family $1, nothing otherwise.
quota_reason() {
    local family="$1" row count pct resets delta
    row="$(quota_row)" || return 0
    IFS='|' read -r count pct resets <<<"$row"
    if [[ "$count" == 0 ]]; then
        printf 'Inherits %s from this session, and no 7d rate-limit data is recorded here,' \
            "$family"
        printf '%s' ' so quota cannot be checked. Pass model "sonnet" or "haiku" to avoid.'
        return 0
    fi
    [[ "$pct" =~ ^[0-9]+(\.[0-9]+)?$ && "$resets" =~ ^[0-9]+$ ]] || return 0
    delta="$(pace_delta "$pct" "$resets" "${USAGE_NOW_EPOCH:-$(date +%s)}")" ||
        return 0
    [[ "$delta" =~ ^-?[0-9]+$ ]] || return 0
    [[ "$delta" -ge "$PACE_YELLOW_POINTS" ]] || return 0
    printf 'Inherits %s from this session, and 7d usage is %+d points over an even pace' \
        "$family" "$delta"
    printf ' (ask threshold +%d). Pass model "sonnet" or "haiku" to avoid.' "$PACE_YELLOW_POINTS"
}

# Prints the ask reason for a model-less launch of an inheriting type, nothing otherwise. Sources
# lib.sh only here, so a broken lib.sh cannot block launches that never read usage.db.
inherited_opus_reason() {
    local session_id model family
    source "$(dirname "${BASH_SOURCE[0]}")/../usage/lib.sh" 2>/dev/null || return 0
    session_id="$(jq -r '.session_id // empty' <<<"$TOOL_INPUT")" || return 0
    [[ -n "$session_id" ]] || return 0
    model="$(session_model "$session_id" | tr '[:upper:]' '[:lower:]')" || return 0
    case "$model" in
    *fable*) family=Fable ;;
    *opus*) family=Opus ;;
    *) return 0 ;;
    esac
    quota_reason "$family"
}

SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.subagent_type // empty')
MODEL=$(echo "$TOOL_INPUT" | jq -r '.tool_input.model // empty' | tr '[:upper:]' '[:lower:]')
# agent_type is also set in a main session started with --agent, so agent_id marks a subagent.
CALLER_AGENT_ID=$(echo "$TOOL_INPUT" | jq -r '.agent_id // empty')

REASON=""
if [[ "$SUBAGENT_TYPE" == "doubt-reviewer" ]]; then
    REASON="doubt-reviewer runs on Opus"
elif [[ "$MODEL" == *opus* || "$MODEL" == *fable* ]]; then
    REASON="subagent model '${MODEL}' is Opus-class"
elif [[ -z "$MODEL" && -z "$CALLER_AGENT_ID" ]] && is_inheriting_type "$SUBAGENT_TYPE"; then
    REASON="$(inherited_opus_reason)" || REASON=""
fi

if [[ -n "$REASON" ]]; then
    jq --null-input --compact-output --arg reason "$REASON" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: $reason
        }
    }'
fi
