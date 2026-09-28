#!/bin/bash
# Nudges at a fixed context-size checkpoint so there's a deterministic,
# human-visible warning before Claude Code's real auto-compaction fires.
#
# UserPromptSubmit hook, Claude Code only: kiro-cli has no local token data
# at all (see etc/ai/usage/README.md's "Why Kiro CLI isn't wired up"), so
# wiring this into kiro would be a permanent no-op.
#
# THRESHOLD is a fixed absolute token count, deliberately NOT derived as a
# fraction of autoCompactWindow -- the real compaction trigger point is a
# window-size-dependent ratio that's still only loosely understood (see
# engram decision/claude-code-auto-compact-window-fix), so deriving this
# threshold from it would inherit that uncertainty. An absolute number is
# simpler and correct regardless of what autoCompactWindow is configured to.
#
# Self-resetting sentinel, not a one-time-ever nudge: below THRESHOLD, any
# stale sentinel is cleared silently; at/above THRESHOLD, it nudges once per
# "growth phase" (once per sentinel), then stays silent until tokens drop
# back below THRESHOLD (e.g. a compaction) and climb past it again, at which
# point it nudges again. No coordination with the compaction hooks needed.
#
# Purely observational: always exits 0, never blocks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../usage/lib.sh"

THRESHOLD=135000

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
    echo "📊 This session has crossed ${THRESHOLD} tokens (currently ~${CURRENT_TOKENS}). Auto-compaction may trigger somewhat above this point. If you're at a natural stopping point, consider /compact now (on your terms) or /clear if switching to an unrelated task."
    mkdir -p "$SENTINEL_DIR"
    : >"$SENTINEL"
fi

exit 0
