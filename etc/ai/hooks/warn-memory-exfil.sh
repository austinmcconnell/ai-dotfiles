#!/bin/bash
set -euo pipefail
# Warn when a memory save contains exfiltration or SSH-backdoor patterns. Claude Code only: kiro has
# no non-blocking channel that reaches the model from preToolUse. Always exits 0, so it never blocks;
# the warning is delivered to Claude as additionalContext.

TOOL_INPUT=$(cat)

# Malformed input is block-memory-secrets.sh's job; this hook stays silent.
if ! echo "$TOOL_INPUT" | jq -e . >/dev/null 2>&1; then
    exit 0
fi

TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // empty')
TOOL_NAME="${TOOL_NAME##*/}"
TOOL_NAME="${TOOL_NAME##mcp__*__}"
if [[ "${TOOL_NAME}" != "mem_save" && "${TOOL_NAME}" != "mem_update" && "${TOOL_NAME}" != "mem_save_prompt" && "${TOOL_NAME}" != "mem_session_summary" && "${TOOL_NAME}" != "mem_capture_passive" ]]; then
    exit 0
fi

# Capture string values once, for the same reason as block-memory-secrets.sh: grep -q under pipefail
# can fail on SIGPIPE and silently skip a match in a large payload.
STRING_VALUES=$(echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null || true)

# Each category names the risk, not the matched text, so the warning never echoes content back.
WARNINGS=()
if grep -qiE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh([[:space:]]|$)|(ba|z)?sh -c "?\$\((curl|wget)' <<<"${STRING_VALUES}"; then
    WARNINGS+=("a download piped into a shell")
fi
if grep -qiE 'base64[[:space:]]+(-d|--decode)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh' <<<"${STRING_VALUES}"; then
    WARNINGS+=("base64 output decoded into a shell")
fi
if grep -qiE '/dev/(tcp|udp)/|\bn(c|cat)\b[^|]* -e |bash -i[^|]*>&|\bmkfifo\b' <<<"${STRING_VALUES}"; then
    WARNINGS+=("a reverse-shell construct")
fi
if grep -qiE '(curl|wget)[^|]*\$\{?[A-Z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)' <<<"${STRING_VALUES}"; then
    WARNINGS+=("an outbound request that references a credential-named variable")
fi
if grep -qiE 'authorized_keys' <<<"${STRING_VALUES}"; then
    WARNINGS+=("an SSH authorized_keys path")
fi
if grep -qiE 'sshd_config|PermitRootLogin[[:space:]]+yes|PermitUserEnvironment|ProxyCommand|LocalCommand' <<<"${STRING_VALUES}"; then
    WARNINGS+=("an SSH server or client config directive that can open a backdoor")
fi

if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    exit 0
fi

REASONS=$(printf '%s; ' "${WARNINGS[@]}")
jq -n --arg reasons "${REASONS%; }" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: ("WARNING: this memory save contains " + $reasons + ". It was not blocked. Confirm with the user that it is intended before relying on it.")
    }
}'
