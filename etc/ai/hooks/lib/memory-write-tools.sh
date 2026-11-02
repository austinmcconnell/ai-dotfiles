# shellcheck shell=bash
# Engram tools whose payloads the secret and exfiltration hooks scan. Sourced by
# etc/ai/hooks/*.sh. Lives under lib/ so validate-hook-wiring.sh does not treat
# it as a hook.

MEMORY_CHECKED_TOOLS=(
    mem_save
    mem_update
    mem_save_prompt
    mem_session_summary
    mem_capture_passive
    mem_judge
    mem_judge_many
    mem_compare
)

# Succeeds when the bare tool name (MCP prefix already stripped) is scanned.
is_checked_memory_tool() {
    local name="$1" tool
    for tool in "${MEMORY_CHECKED_TOOLS[@]}"; do
        [[ "$name" == "$tool" ]] && return 0
    done
    return 1
}
