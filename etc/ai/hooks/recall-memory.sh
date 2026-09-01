#!/bin/bash
set -euo pipefail

# Surface recent memory context at session start
# Called from agentSpawn hook — output is injected into session context
# Relies on agent config timeout_ms (5000ms) as safety net if engram hangs

ENGRAM_DB="$HOME/.config/engram/engram.db"

if ! command -v engram &>/dev/null || [[ ! -f "${ENGRAM_DB}" ]]; then
    exit 0
fi

# Resolve the project name the way engram does. Engram's canonical source is the
# git remote (project_source=git_remote): the repo name from the origin URL with a
# trailing ".git" stripped — e.g. git@host:user/dotfiles.git -> "dotfiles". Fall back
# to the working-directory basename only when there is no git remote (engram's cwd
# detection). NOTE: basename "$(pwd)" alone is wrong here — this repo lives in
# ".dotfiles" but engram resolves it to "dotfiles", so a pwd-based name never matches.
REMOTE_URL="$(git remote get-url origin 2>/dev/null || true)"
if [[ -n "${REMOTE_URL}" ]]; then
    PROJECT_NAME="$(basename "${REMOTE_URL}")"
    PROJECT_NAME="${PROJECT_NAME%.git}"
else
    PROJECT_NAME="$(basename "$(pwd)")"
fi

# Project-scoped existence check: `engram context <project>` reports a per-project
# observation count ("[N observations]"). This is scoped to the resolved project
# rather than a full-text keyword search on the name, so it can't false-match on
# unrelated memories that happen to mention the directory name.
OBS_COUNT=$(engram context "${PROJECT_NAME}" 2>/dev/null |
    grep -oE "\\*\\*${PROJECT_NAME}\\*\\*.*\\[[0-9]+ observations\\]" |
    grep -oE '[0-9]+ observations' | grep -oE '[0-9]+' | head -1 || true)

if [[ -n "${OBS_COUNT}" && "${OBS_COUNT}" -gt 0 ]]; then
    echo "💡 Engram has memories about '${PROJECT_NAME}'. Use mem_search or mem_context to recall prior decisions and context."
fi

exit 0
