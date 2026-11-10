#!/bin/bash
# Block any tool from accessing .env files
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# Exact repo-relative paths of tracked docs that quote the guard. Never add a hook or settings file.
ALLOWED_DOC_WRITES=(
    "etc/ai/steering/security/env-file-protection.md"
)

is_allowed_doc_write() {
    local tool file_path entry
    tool="$(jq -r '.tool_name // empty' <<<"${TOOL_INPUT}")"
    [[ "${tool}" == "Write" || "${tool}" == "Edit" ]] || return 1
    file_path="$(jq -r '.tool_input.file_path // empty' <<<"${TOOL_INPUT}")"
    [[ -n "${file_path}" && ! -L "${file_path}" ]] || return 1
    for entry in "${ALLOWED_DOC_WRITES[@]}"; do
        [[ "${file_path}" == "${REPO_ROOT}/${entry}" ]] && return 0
    done
    return 1
}

if is_allowed_doc_write; then
    exit 0
fi

STRING_VALUES=$(jq -r '.. | strings' <<<"${TOOL_INPUT}" 2>/dev/null || true)
# Every regex match contains ".env", so this literal check skips the regex on most calls.
if grep -qiF '.env' <<<"${STRING_VALUES}" &&
    grep -qiE '(^|[/[:space:]])[^/[:space:]]*\.env($|\.|[[:space:]]|/)' <<<"${STRING_VALUES}"; then
    echo "BLOCKED: Access to .env files is not permitted for security reasons" >&2
    exit 2
fi
