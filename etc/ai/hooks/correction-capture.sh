#!/bin/bash
set -euo pipefail
# Correction capture + deferred promotion prompt (single userPromptSubmit hook).
# Shared hook: works with kiro-cli (userPromptSubmit) and Claude Code (UserPromptSubmit).
#
# On every user prompt this hook does two things, both by writing to the agent's
# context via stdout (exit 0). userPromptSubmit stdout is the one channel documented
# to reach the model on BOTH tools — unlike the stop event, whose exit-0 stdout is
# not surfaced. That is why capture-nudge and promotion-prompt both live here rather
# than splitting the promotion prompt into a stop hook.
#
#   1. Deferred promotion prompt: if a correction was captured on a PRIOR turn (a
#      session-scoped sentinel exists), remind the user to run distill-learnings,
#      then clear the sentinel so the reminder appears once per correction-batch.
#   2. Capture nudge: if the current prompt looks like a correction/preference,
#      nudge the agent to mem_save it now (per the capturing-corrections steering)
#      and drop the sentinel so the promotion prompt fires next turn.
#
# This hook never writes to memory itself; the agent's mem_save still passes through
# the block-memory-secrets guard. It never promotes anything; promotion is the
# user-approved distill-learnings skill.
#
# Safety: grep runs inside `if` (errexit suppressed there); the empty-prompt early
# exit avoids over-triggering; jq failures degrade to empty via `// empty` + 2>/dev/null.

INPUT=$(cat)

# Session key: prefer the payload's session_id (Claude Code provides it; kiro may
# too), then the exported KIRO_SESSION_ID, then a date+PID fallback — matching the
# repo's trace-tool-call.sh so parallel sessions don't collide on a shared sentinel.
SESSION_ID=$(echo "${INPUT}" | jq -r '.session_id // empty' 2>/dev/null)
SESSION_ID="${SESSION_ID:-${KIRO_SESSION_ID:-$(date +%Y%m%d)-$$}}"

SENTINEL_DIR="${TMPDIR:-/tmp}/ai-corrections"
SENTINEL="${SENTINEL_DIR}/${SESSION_ID}.pending"

# 1. Deferred promotion prompt (from a correction captured on a prior turn).
if [[ -f "${SENTINEL}" ]]; then
    echo "💡 A correction was captured to engram earlier this session. At a good stopping point, run the distill-learnings skill to review it for promotion into steering/skills (your approval required)."
    rm -f "${SENTINEL}"
fi

# 2. Capture nudge for the current prompt.
PROMPT=$(echo "${INPUT}" | jq -r '.prompt // empty' 2>/dev/null)
[[ -z "${PROMPT}" ]] && exit 0

# High-confidence correction / redirection / preference phrasing. Anchored to the
# start of a clause (line start or after sentence punctuation) to avoid firing on
# benign mid-sentence prose like "I always run tests first". Conservative by design:
# the capturing-corrections steering is the primary capture path, so false negatives
# are acceptable and false positives are kept low to avoid spurious promotion prompts.
# POSIX ERE only (grep -E) — no PCRE \s — so it works under any bash/sh grep on PATH.
# Apostrophes in contractions (that's, don't) are matched with `.` to avoid fragile
# shell quote-splicing; `.` matches the apostrophe (and any stray char, harmlessly).
clause='(^|[.!?;][[:space:]]+)'
anchored="${clause}(no,|nope|actually,|wrong|that.s (wrong|incorrect|not right)|i (said|meant)|stop (using|doing)|i prefer|remember (this|that)|do not (use|do)|don.t (use|do))"
correction_re="${anchored}|use [^ ]+ not |instead of "

if echo "${PROMPT}" | grep -qiE "${correction_re}"; then
    echo "↳ That looked like a correction, redirection, or stated preference. Per the capturing-corrections steering, save it now with mem_save (type: preference, topic_key: correction/<area>-<slug>) before continuing — do not wait until end of session."
    mkdir -p "${SENTINEL_DIR}"
    : >"${SENTINEL}"
fi

exit 0
