#!/bin/bash
set -euo pipefail

# Surface recent memory context at session start
# Called from agentSpawn hook — output is injected into session context
# Relies on agent config timeout_ms (5000ms) as safety net if engram hangs
#
# Emits one of three things, in priority order:
#   1. If exactly one ACTIVE HANDOFF exists (an observation carrying the structured
#      self-referential marker line ENGRAM-HANDOFF-ACTIVE: handoff/<project>-active),
#      a DIRECTIVE to fetch it in full — the handoff is the live state of an ongoing
#      effort and must be read before other work.
#   2. If MORE than one such marker is found, a fail-loud warning to verify manually
#      (the convention allows only one active handoff per project).
#   3. Otherwise, if the project has any memories, a generic recall nudge.

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
# fetch it IN FULL rather than a generic nudge. A truncated preview cannot carry
# the handoff, so the nudge COMMANDS the full fetch instead of trying to CARRY it.
#
# IDENTITY, NOT MENTION. `engram search` is FTS content search — it cannot filter
# by topic_key (not an FTS column, no --topic flag, no JSON mode), so a bare search
# for the sentinel WORD matches any observation that merely DISCUSSES handoffs
# (e.g. a correction about the convention), not only real handoffs. To answer
# "which observation IS the active handoff" we require a STRUCTURED, self-referential
# marker line that only a genuine handoff for THIS project carries:
#
#     ENGRAM-HANDOFF-ACTIVE: handoff/<project>-active
#
# The search seeds FTS on the sentinel word; we then post-filter each result's body
# for that exact line. Prose that merely names the token or the topic_key does not
# contain the exact KEY: value line, so it is rejected. (See the "Handoffs" section
# of cross-session-memory.md.) `engram search` prints "[N] #<id> (<type>) — <title>"
# followed by the body, so awk tracks the current #id per result block and records
# ids whose block carries the marker line for this project.
#
# COLLISION FAILS LOUD. The convention guarantees exactly ONE active handoff per
# project (topic_key upsert). If the post-filter finds more than one match, that is
# itself a red flag (a stray doc copied the exact marker, or the upsert invariant
# broke) — surface it for manual review rather than silently picking one.
HANDOFF_IDS=$(engram search "ENGRAM-HANDOFF-ACTIVE" --project "${PROJECT_NAME}" --limit 20 2>/dev/null |
    awk -v proj="${PROJECT_NAME}" '
        /^\[[0-9]+\] #[0-9]+ / {
            if (match($0, /#[0-9]+/)) { cur = substr($0, RSTART + 1, RLENGTH - 1) }
            next
        }
        {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            if (line == "ENGRAM-HANDOFF-ACTIVE: handoff/" proj "-active") { print cur }
        }
    ' | sort -u || true)

HANDOFF_COUNT=$(printf '%s' "${HANDOFF_IDS}" | grep -c . || true)

if [[ "${HANDOFF_COUNT}" -eq 1 ]]; then
    echo "⚠️  ACTIVE HANDOFF exists for '${PROJECT_NAME}' (#${HANDOFF_IDS}). Call mem_get_observation(${HANDOFF_IDS}) IN FULL before doing anything else."
elif [[ "${HANDOFF_COUNT}" -gt 1 ]]; then
    joined=$(printf '%s' "${HANDOFF_IDS}" | tr '\n' ' ')
    echo "⚠️  Multiple active-handoff markers for '${PROJECT_NAME}' (#: ${joined}). The convention allows only one — verify with mem_get_observation before continuing; do not assume which is current."
elif [[ -n "${OBS_COUNT}" && "${OBS_COUNT}" -gt 0 ]]; then
    echo "💡 Engram has memories about '${PROJECT_NAME}'. Use mem_search or mem_context to recall prior decisions and context."
fi

exit 0
