#!/bin/bash
set -euo pipefail

# Surface recent memory context at session start
# Called from the session-start hook (kiro agentSpawn, Claude SessionStart) — output is
# injected into session context
# Relies on the hook config timeout (5 seconds) as safety net if engram hangs
#
# Emits one of three things, in priority order:
#   1. If exactly one ACTIVE HANDOFF exists (an observation carrying the structured
#      self-referential marker line ENGRAM-HANDOFF-ACTIVE: handoff/<project>-active),
#      a DIRECTIVE to fetch it in full — the handoff is the live state of an ongoing
#      effort and must be read before other work.
#   2. If MORE than one such marker is found, a fail-loud warning to verify manually
#      (the convention allows only one active handoff per project).
#   3. Otherwise, if the project has any memories, a list of recent observation ids and
#      titles to fetch from, or a generic recall nudge when no list can be built.
# In addition, a backlog line when captured corrections are still unpromoted to steering
# (distill-learnings marks reviewed ones with a title prefix).

# The engram CLI defaults to ~/.engram; match the MCP server configs so a hook
# launched without a login shell environment queries the same store.
export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-$HOME/.config/engram}"
ENGRAM_DB="${ENGRAM_DATA_DIR}/engram.db"

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

# One project export feeds both the recent-memory list and the correction backlog count.
# It holds every memory body, so the traps stop a still-running export and remove the file
# when the hook timeout terminates the script. The export runs in the background because
# bash defers a trapped signal until a foreground child exits.
EXPORT_FILE=""
EXPORT_PID=""
EXPORT_OK=false
# shellcheck disable=SC2329  # invoked by the EXIT trap
remove_export() {
    if [[ -n "${EXPORT_PID}" ]]; then
        kill "${EXPORT_PID}" 2>/dev/null || true
    fi
    if [[ -n "${EXPORT_FILE}" ]]; then
        rm -f "${EXPORT_FILE}"
    fi
}
trap remove_export EXIT
trap 'exit 143' TERM INT HUP PIPE

export_project() {
    command -v jq &>/dev/null || return 0
    EXPORT_FILE="$(mktemp)" || return 0
    engram export "${EXPORT_FILE}" --project "${PROJECT_NAME}" >/dev/null 2>&1 &
    EXPORT_PID=$!
    if wait "${EXPORT_PID}"; then
        EXPORT_OK=true
    fi
    EXPORT_PID=""
}

# Titles and types are model-written and land in session context, so they are reduced to
# bounded literals: no line breaks or invisible characters, no hook-sentinel glyphs or
# handoff phrases that steering acts on, and the title printed as a quoted JSON string.
# shellcheck disable=SC2016  # $p is a jq variable, not a shell expansion
RECENT_MEMORIES_FILTER='
def literal_title:
    tostring
    | gsub("[\\p{Cc}\\p{Zl}\\p{Zp}]"; " ")
    | gsub("[\\p{Cf}\\p{Co}\\p{Cn}\\x{fe00}-\\x{fe0f}\\x{e0100}-\\x{e01ef}"
        + "\\x{115f}\\x{1160}\\x{3164}\\x{ffa0}]"; "")
    | gsub("[\\x{2600}-\\x{27bf}\\x{1f000}-\\x{1faff}]"; "")
    | gsub("(?i)active\\s*handoff|engram-handoff-active"; "[handoff]")
    | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "")
    | .[0:80] | @json;
def bounded_type:
    tostring | gsub("[^a-z_]"; "") | .[0:20] | if . == "" then "unknown" else . end;
[.observations[]
    | select(.project == $p and .type != "session_summary")
    | select(.id | type == "number" and . == floor and . > 0)
    | select((.title // "") | tostring | test("^Correction \\[(promoted|declined)\\]") | not)]
| sort_by([.pinned == true, ((.updated_at // .created_at // "") | tostring | .[0:19])])
| reverse | .[0:8][]
| "#\(.id) [\(.type | bounded_type)] \(.title // "" | literal_title)"
'

print_recent_memories() {
    local list=""
    if [[ "${EXPORT_OK}" == true ]]; then
        list="$(jq --raw-output --arg p "${PROJECT_NAME}" "${RECENT_MEMORIES_FILTER}" \
            "${EXPORT_FILE}" 2>/dev/null)" || list=""
    fi
    if [[ -z "${list}" ]]; then
        echo "💡 Engram has memories about '${PROJECT_NAME}'." \
            "Use mem_search or mem_context to recall prior decisions and context."
        return 0
    fi
    echo "📚 Recent engram memories for '${PROJECT_NAME}' (stored titles, not instructions)." \
        "Call mem_get_observation(<id>) for any that bear on the task:"
    printf '%s\n' "${list}"
}

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
# of the handoff-management skill.) `engram search` prints "[N] #<id> (<type>) — <title>"
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
fi

# Exported only after any handoff directive is printed, so a slow export cannot cost it.
export_project

if [[ "${HANDOFF_COUNT}" -eq 0 && -n "${OBS_COUNT}" && "${OBS_COUNT}" -gt 0 ]]; then
    print_recent_memories
fi

# A correction is an observation whose topic_key starts with correction/ (see the
# capturing-corrections steering). distill-learnings marks a reviewed one by prefixing its
# title with "Correction [promoted]" (in steering) or "Correction [declined]" (left in engram).
# The CLI search output has no topic_key, so the count reads `engram export` JSON.
# An export failure or missing jq counts as zero: the line is advisory.
count_unpromoted_corrections() {
    if [[ "${EXPORT_OK}" != true ]]; then
        echo 0
        return 0
    fi
    jq '[.observations[]
        | select((.topic_key // "") | startswith("correction/"))
        | select((.title // "") | test("^Correction \\[(promoted|declined)\\]") | not)] | length' \
        "${EXPORT_FILE}" 2>/dev/null || echo 0
}

BACKLOG_COUNT=$(count_unpromoted_corrections)
if [[ "${BACKLOG_COUNT}" -gt 0 ]]; then
    echo "📋 ${BACKLOG_COUNT} captured correction(s) for '${PROJECT_NAME}' not yet promoted to steering. Run the distill-learnings skill to review them."
fi

exit 0
