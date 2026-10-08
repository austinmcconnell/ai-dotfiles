#!/bin/bash

# ---------------------------------------------------------------
# Enabled AI agents — the single list of tools this machine installs.
#
# Sourced by install.sh (gates the per-tool install scripts) and
# install/ai-tools.sh (gates skills/steering distribution), so both obey
# one list. Enable the agents you actively use; the others are defined in
# the agent_config registry in ai-tools.sh but are not linked until added
# here. Disabling an agent only stops future installs — it never removes
# anything already installed or linked.
# ---------------------------------------------------------------

# shellcheck disable=SC2034 # consumed by the scripts that source this file
ENABLED_AGENTS=(
    "claude-code"
    "kiro-cli"
    # "codex"
    # "cursor"
    # "gemini-cli"
    # "github-copilot"
    # "windsurf"
)

# Return 0 when the named agent is in ENABLED_AGENTS, 1 otherwise.
agent_enabled() {
    local agent
    for agent in "${ENABLED_AGENTS[@]}"; do
        [[ "$agent" == "$1" ]] && return 0
    done
    return 1
}
