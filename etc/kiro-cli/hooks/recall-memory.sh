#!/bin/bash
set -euo pipefail

# Surface recent memory context at session start
# Called from agentSpawn hook — output is injected into session context
# Relies on agent config timeout_ms (5000ms) as safety net if engram hangs

ENGRAM_DB="$HOME/.config/engram/engram.db"

if ! command -v engram &>/dev/null || [[ ! -f "${ENGRAM_DB}" ]]; then
    exit 0
fi

PROJECT_NAME="$(basename "$(pwd)")"

RECENT_COUNT=$(engram search "${PROJECT_NAME}" --limit 1 2>/dev/null | grep -c "^\\[" || true)

if [[ "${RECENT_COUNT}" -gt 0 ]]; then
    echo "💡 Engram has memories about '${PROJECT_NAME}'. Use mem_search or mem_context to recall prior decisions and context."
fi

exit 0
