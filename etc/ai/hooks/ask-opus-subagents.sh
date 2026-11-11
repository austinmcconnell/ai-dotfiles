#!/bin/bash
# Ask the user before an Agent launch that runs on Opus or Fable.
# Claude Code only: wired as a PreToolUse hook with matcher "Agent".
#
# Why a hook: `Agent(...)` entries in permissions.ask do not prompt for subagent launches, even in
# default mode, so they gate nothing. A hook's `ask` does prompt, including for background launches,
# and it overrides the bare `Agent` allow rule.
#
# Asks when the call names the `doubt-reviewer` persona (it pins Opus in its frontmatter, which the
# Agent call never carries) or sets a `model` containing "opus" or "fable". Any other launch passes
# through with no output.

set -euo pipefail

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.subagent_type // empty')
MODEL=$(echo "$TOOL_INPUT" | jq -r '.tool_input.model // empty' | tr '[:upper:]' '[:lower:]')

REASON=""
if [[ "$SUBAGENT_TYPE" == "doubt-reviewer" ]]; then
    REASON="doubt-reviewer runs on Opus"
elif [[ "$MODEL" == *opus* || "$MODEL" == *fable* ]]; then
    REASON="subagent model '${MODEL}' is Opus-class"
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
