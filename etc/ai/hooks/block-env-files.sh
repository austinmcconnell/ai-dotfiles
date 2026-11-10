#!/bin/bash
# Block any tool from accessing .env files
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

STRING_VALUES=$(jq -r '.. | strings' <<<"${TOOL_INPUT}" 2>/dev/null || true)
# Every regex match contains ".env", so this literal check skips the regex on most calls.
if grep -qiF '.env' <<<"${STRING_VALUES}" &&
    grep -qiE '(^|[/[:space:]])[^/[:space:]]*\.env($|\.|[[:space:]]|/)' <<<"${STRING_VALUES}"; then
    echo "BLOCKED: Access to .env files is not permitted for security reasons" >&2
    exit 2
fi
