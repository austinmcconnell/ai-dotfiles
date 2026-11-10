# shellcheck shell=bash
# Input guard for the blocking hooks that run on every tool call. Sourced by
# etc/ai/hooks/*.sh. Lives under lib/ so validate-hook-wiring.sh does not treat
# it as a hook.

# Exits the calling hook when its input cannot be checked. A missing jq or a
# non-empty payload that is not JSON blocks (exit 2), matching what
# onFailure "block" does on Claude Code for any other hook failure. An empty
# payload has nothing to check and passes.
check_hook_input() {
    local input="$1" hook
    hook="$(basename "$0")"
    if ! command -v jq >/dev/null 2>&1; then
        echo "BLOCKED: jq not found; ${hook} cannot check this call" >&2
        exit 2
    fi
    if ! LC_ALL=C grep -q '[^[:space:]]' <<<"${input}"; then
        exit 0
    fi
    if ! jq empty <<<"${input}" >/dev/null 2>&1; then
        echo "BLOCKED: hook input is not valid JSON; ${hook} cannot check this call" >&2
        exit 2
    fi
}
