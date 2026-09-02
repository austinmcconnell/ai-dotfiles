#!/bin/bash
set -euo pipefail

# Surface recent memory context at session start
# Called from agentSpawn hook — output is injected into session context
# Relies on agent config timeout_ms (5000ms) as safety net if engram hangs
#
# Emits one of two things, in priority order:
#   1. If an ACTIVE HANDOFF exists (an observation carrying the ENGRAM-HANDOFF-ACTIVE
#      sentinel), a DIRECTIVE to fetch it in full — the handoff is the live state of
#      an ongoing effort and must be read before other work.
#   2. Otherwise, if the project has any memories, a generic recall nudge.

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

# Detect an ACTIVE HANDOFF for this project and, if present, emit a directive to
# fetch it IN FULL rather than a generic nudge. Handoffs carry the mandatory
# sentinel token ENGRAM-HANDOFF-ACTIVE in their body (see the "Handoffs" section
# of cross-session-memory.md steering) precisely so this FTS5 search can find
# them — FTS5 needs a literal term to match on, and `engram search` requires a
# query string (it cannot list purely by topic_key or type). The first result
# line looks like "[1] #<id> (<type>) — <title>", so grep the leading "#<id>".
# A truncated preview cannot carry the handoff, so the nudge COMMANDS the full
# fetch instead of trying to CARRY it.
HANDOFF_ID=$(engram search "ENGRAM-HANDOFF-ACTIVE" --project "${PROJECT_NAME}" --limit 1 2>/dev/null |
    grep -oE '#[0-9]+' | head -1 | tr -d '#' || true)

if [[ -n "${HANDOFF_ID}" ]]; then
    echo "⚠️  ACTIVE HANDOFF exists for '${PROJECT_NAME}' (#${HANDOFF_ID}). Call mem_get_observation(${HANDOFF_ID}) IN FULL before doing anything else."
elif [[ -n "${OBS_COUNT}" && "${OBS_COUNT}" -gt 0 ]]; then
    echo "💡 Engram has memories about '${PROJECT_NAME}'. Use mem_search or mem_context to recall prior decisions and context."
fi

exit 0
