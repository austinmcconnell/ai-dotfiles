#!/bin/bash
# Nudges at a fixed context-size checkpoint so there's a deterministic,
# human-visible warning before Claude Code's real auto-compaction fires.
#
# UserPromptSubmit hook, Claude Code only: kiro-cli has no local token data
# at all (see etc/ai/usage/README.md's "Why Kiro CLI isn't wired up"), so
# wiring this into kiro would be a permanent no-op.
#
# THRESHOLD is derived from the configured window: auto-compaction fires about
# COMPACT_RESERVE tokens below it (see etc/ai/usage/README.md), and the nudge
# fires NUDGE_MARGIN tokens before that. The window comes from
# CLAUDE_CODE_AUTO_COMPACT_WINDOW, else autoCompactWindow in the user
# settings.json; with neither readable, FALLBACK_THRESHOLD applies. A per-model
# modelSettings window is not read.
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

COMPACT_RESERVE=35000
NUDGE_MARGIN=15000
FALLBACK_THRESHOLD=235000

# Prints a token count for "250k" / "250000" style values; prints nothing otherwise.
parse_window() {
    local raw
    raw=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
        echo "$raw"
    elif [[ "$raw" =~ ^[0-9]+k$ ]]; then
        echo $((${raw%k} * 1000))
    fi
    return 0
}

compute_threshold() {
    local window settings
    settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
    window=$(parse_window "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}")
    if [[ -z "$window" && -f "$settings" ]]; then
        window=$(parse_window "$(jq -r '.autoCompactWindow // empty' "$settings" 2>/dev/null || true)")
    fi
    if [[ -n "$window" && "$window" -gt $((COMPACT_RESERVE + NUDGE_MARGIN)) ]]; then
        echo $((window - COMPACT_RESERVE - NUDGE_MARGIN))
    else
        echo "$FALLBACK_THRESHOLD"
    fi
}

THRESHOLD=$(compute_threshold)

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
Tell them to send that line as its own message with nothing before it: a slash command only runs
when it opens the message, so pasting it after other answers sends it as plain text.
Write the instructions from this session's actual work. Cover what to keep (decisions, file paths,
current state, open questions, user preferences), what is finished and can be dropped, and what
work remains. Never suggest a bare /compact. If the user is switching to an unrelated task,
suggest /clear instead.
EOF
    mkdir -p "$SENTINEL_DIR"
    : >"$SENTINEL"
fi

exit 0
