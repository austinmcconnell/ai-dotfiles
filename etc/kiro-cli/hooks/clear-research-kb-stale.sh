#!/bin/bash
set -euo pipefail

AGENT="${1:-}"
SENTINEL="$HOME/.kiro/research-kb-stale"

# Exit early if no sentinel or no agent name
[[ -z "${AGENT}" || ! -f "${SENTINEL}" ]] && exit 0

# Read hook event from stdin
EVENT=$(cat)

# Only act on update commands targeting the research path
COMMAND=$(echo "${EVENT}" | jq -r '.tool_input.command // empty')
PATH_VAL=$(echo "${EVENT}" | jq -r '.tool_input.path // empty')

if [[ "${COMMAND}" == "update" && "${PATH_VAL}" == *"_research_"* ]]; then
    sed -i "/^${AGENT}$/d" "${SENTINEL}"
    # Remove file if empty
    [[ ! -s "${SENTINEL}" ]] && rm -f "${SENTINEL}"
fi
exit 0
