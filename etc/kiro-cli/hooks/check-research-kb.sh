#!/bin/bash
set -euo pipefail

AGENT="${1:-}"
SENTINEL="$HOME/.kiro/research-kb-stale"

if [[ -n "${AGENT}" && -f "${SENTINEL}" ]] && grep -q "^${AGENT}$" "${SENTINEL}"; then
    echo "⚠️ Research knowledge base is stale (source: ${HOME}/projects/austinmcconnell/_research_). Ask me to update it to re-index and clear this warning."
fi
exit 0
