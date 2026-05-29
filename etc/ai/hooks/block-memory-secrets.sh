#!/bin/bash
set -euo pipefail
# Block memory saves that contain potential secrets
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)
#
# Safety: set -euo pipefail is safe here because grep is inside an `if` condition
# (which suppresses errexit) and the early-exit for non-matching tool names ensures
# we never reach the grep on irrelevant calls.

TOOL_INPUT=$(cat)

# Only check memory save/update operations
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
if [[ "${TOOL_NAME}" != "mem_save" && "${TOOL_NAME}" != "mem_update" && "${TOOL_NAME}" != "mem_save_prompt" && "${TOOL_NAME}" != "mem_session_summary" && "${TOOL_NAME}" != "mem_capture_passive" ]]; then
    exit 0
fi

# Check for common secret patterns in all string values
if echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null | grep -qiE \
    'AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|xox[baprs]-[a-zA-Z0-9-]+|-----BEGIN .* PRIVATE KEY|password\s*[:=]\s*\S+'; then
    echo "BLOCKED: Memory save appears to contain a secret or credential. Refusing to store." >&2
    exit 2
fi

exit 0
