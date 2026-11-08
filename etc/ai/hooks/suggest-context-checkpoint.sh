#!/bin/bash
# Nudges at a fixed context-size checkpoint so there's a deterministic,
# human-visible warning before Claude Code's real auto-compaction fires.
#
# UserPromptSubmit hook, Claude Code only: kiro-cli has no local token data
# at all (see etc/ai/usage/README.md's "Why Kiro CLI isn't wired up"), so
# wiring this into kiro would be a permanent no-op.
#
# THRESHOLD is a fixed absolute token count set ~15K below the auto-compaction
# trigger, which is autoCompactWindow minus a ~35K reserve (see
# etc/ai/usage/README.md). Update it whenever autoCompactWindow changes.
#
# Self-resetting sentinel, not a one-time-ever nudge: below THRESHOLD, any
# stale sentinel is cleared silently; at/above THRESHOLD, it nudges once per
# "growth phase" (once per sentinel), then stays silent until tokens drop
# back below THRESHOLD (e.g. a compaction) and climb past it again, at which
# point it nudges again. No coordination with the compaction hooks needed.
#
# Purely observational: never blocks (it never exits 2). A failed usage-database query
# exits non-zero under `set -e` with no output.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../usage/lib.sh"

THRESHOLD=235000

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d)-$$}"

SENTINEL_DIR="${TMPDIR:-/tmp}/ai-context-checkpoint"
SENTINEL="${SENTINEL_DIR}/${SESSION_ID}.notified"

usage_db_init
CURRENT_TOKENS=$(sqlite3 "$USAGE_DB" \
    "SELECT input_tokens FROM sessions WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")

if [[ -z "$CURRENT_TOKENS" || "$CURRENT_TOKENS" -lt "$THRESHOLD" ]]; then
    rm -f "$SENTINEL"
    exit 0
fi

if [[ ! -f "$SENTINEL" ]]; then
    cat <<EOF
📊 This session has crossed ${THRESHOLD} tokens (currently ~${CURRENT_TOKENS}); auto-compaction is close.
Finish the step in progress, then tell the user it is time to compact and give them one
ready-to-paste line of the form: /compact <instructions>
Write the instructions from this session's actual work. Cover what to keep (decisions, file paths,
current state, open questions, user preferences), what is finished and can be dropped, and what
work remains. Never suggest a bare /compact. If the user is switching to an unrelated task,
suggest /clear instead.
EOF
    mkdir -p "$SENTINEL_DIR"
    : >"$SENTINEL"
fi

exit 0
