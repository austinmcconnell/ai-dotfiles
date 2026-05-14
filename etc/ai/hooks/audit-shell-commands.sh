#!/bin/bash
# Audit AWS and kubectl commands run via shell
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PostToolUse)

set -euo pipefail

TOOL_INPUT=$(cat)

# Detect which AI tool is running this hook
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    AGENT="claude-code"
else
    AGENT="kiro-cli"
fi

# Extract command from tool input
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')
CWD=$(echo "$TOOL_INPUT" | jq -r '.cwd // empty')

LOG_DIR="$HOME/.local/share/ai-audit"
mkdir -p "$LOG_DIR"

# Log AWS commands
if echo "$CMD" | grep -qE '(^|[;&|])aws '; then
    jq -nc \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg agent "$AGENT" \
        --arg cmd "$CMD" \
        --arg cwd "$CWD" \
        '{timestamp: $ts, agent: $agent, tool: "aws", command: $cmd, cwd: $cwd}' \
        >>"$LOG_DIR/command-audit.jsonl"
fi

# Log kubectl commands
if echo "$CMD" | grep -qE '(^|[;&|])kubectl '; then
    jq -nc \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg agent "$AGENT" \
        --arg cmd "$CMD" \
        --arg cwd "$CWD" \
        '{timestamp: $ts, agent: $agent, tool: "kubectl", command: $cmd, cwd: $cwd}' \
        >>"$LOG_DIR/command-audit.jsonl"
fi
