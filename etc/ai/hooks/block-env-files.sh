#!/bin/bash
# Block any tool from accessing .env files
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

if echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null | grep -qiE '(^|[/[:space:]])[^/[:space:]]*\.env($|\.|[[:space:]]|/)'; then
    echo "BLOCKED: Access to .env files is not permitted for security reasons" >&2
    exit 2
fi
