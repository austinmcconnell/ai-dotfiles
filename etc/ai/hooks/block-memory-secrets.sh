#!/bin/bash
set -euo pipefail
# Block memory saves that contain potential secrets
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)
#
# Safety: set -euo pipefail is safe here because grep is inside an `if` condition
# (which suppresses errexit) and the early-exit for non-matching tool names ensures
# we never reach the grep on irrelevant calls.

TOOL_INPUT=$(cat)

# Fail closed: an unparsable payload cannot be checked, so block it explicitly. Left to set -e, the
# jq failure in the tool-name assignment exits 5, which is not a documented hook exit code.
if ! echo "$TOOL_INPUT" | jq -e . >/dev/null 2>&1; then
    echo "BLOCKED: Hook input is not valid JSON. Refusing to check memory save." >&2
    exit 2
fi

# Only check memory save/update operations
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
# Normalize MCP tool-name prefixes so the bare tool name is compared:
#   kiro-cli:     "@engram/mem_save"        -> "mem_save"  (prefix ends with "/")
#   Claude Code:  "mcp__engram__mem_save"   -> "mem_save"  (prefix uses "__")
# Strip the kiro-style "@server/" prefix first, then the Claude-style
# "mcp__server__" prefix. Order is safe: the patterns don't overlap.
TOOL_NAME="${TOOL_NAME##*/}"
TOOL_NAME="${TOOL_NAME##mcp__*__}"
if [[ "${TOOL_NAME}" != "mem_save" && "${TOOL_NAME}" != "mem_update" && "${TOOL_NAME}" != "mem_save_prompt" && "${TOOL_NAME}" != "mem_session_summary" && "${TOOL_NAME}" != "mem_capture_passive" ]]; then
    exit 0
fi

# Capture string values once. Piping jq straight into `grep -q` lets grep exit at the first match;
# under pipefail, jq's SIGPIPE then fails the pipeline and a secret past that point goes unchecked.
STRING_VALUES=$(echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null || true)

# Check for common secret patterns in all string values
if grep -qiE \
    'AKIA[0-9A-Z]{16}|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|xox[baprs]-[a-zA-Z0-9-]+|-----BEGIN .* PRIVATE KEY|password\s*[:=]\s*\S+' <<<"${STRING_VALUES}"; then
    echo "BLOCKED: Memory save appears to contain a secret or credential. Refusing to store." >&2
    exit 2
fi

# Zero-width and bidi-control codepoints have no legitimate place in a memory body. Match UTF-8 byte
# sequences in the C locale: bracket byte ranges do not match reliably across grep implementations.
INVISIBLE_UNICODE_BYTES=$'\xe2\x80\x8b|\xe2\x80\x8c|\xe2\x80\x8d|\xe2\x80\xaa|\xe2\x80\xab|\xe2\x80\xac|\xe2\x80\xad|\xe2\x80\xae|\xe2\x81\xa6|\xe2\x81\xa7|\xe2\x81\xa8|\xe2\x81\xa9|\xef\xbb\xbf'
if LC_ALL=C grep -qE "${INVISIBLE_UNICODE_BYTES}" <<<"${STRING_VALUES}"; then
    echo "BLOCKED: Memory save contains invisible or bidi-control Unicode characters. Refusing to store." >&2
    exit 2
fi

exit 0
