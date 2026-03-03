#!/bin/bash
# Audit AWS and kubectl commands run via shell

# Read JSON from stdin
TOOL_INPUT=$(cat)

# Extract command from the correct path
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty')

# Log AWS commands
if echo "$CMD" | grep -qE '(^|[;&|])aws '; then
    echo "$TOOL_INPUT" | jq -c '{timestamp: now | strftime("%Y-%m-%d %H:%M:%S"), tool: "shell:aws", command: .tool_input.command}' >>~/.kiro/logs/aws-audit.jsonl
fi

# Log kubectl commands
if echo "$CMD" | grep -qE '(^|[;&|])kubectl '; then
    echo "$TOOL_INPUT" | jq -c '{timestamp: now | strftime("%Y-%m-%d %H:%M:%S"), tool: "shell:kubectl", command: .tool_input.command}' >>~/.kiro/logs/kubectl-audit.jsonl
fi
