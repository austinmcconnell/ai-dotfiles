#!/bin/bash
set -euo pipefail

# agentSpawn hook: surface engram memory-conflict debt for the CURRENT project.
#
# Delegates to bin/engram-hygiene (mode: check), which is time-throttled
# (default 6 weeks) and prints a one-line nudge only when the current project has
# pending conflict relations. All-projects review is the on-demand
# `dotfiles memory-check` command; this hook is intentionally narrow to match the
# research-KB check's contextual, low-noise behavior.
#
# Relies on the agent config hook timeout as a safety net if engram hangs.
#
# Usage: check-engram-hygiene.sh [claude|kiro]
# The agent name picks the stamp dir (~/.<agent>/engram-hygiene) so one tool's check
# cannot silence the other tool's nudge. Defaults to kiro.

AGENT="${1:-kiro}"
HYGIENE="${AI_DOTFILES_DIR:-$HOME/.dotfiles}/bin/engram-hygiene"

case "${AGENT}" in
claude | kiro) ;;
*)
    echo "check-engram-hygiene: unknown agent '${AGENT}' (expected claude or kiro)" >&2
    exit 1
    ;;
esac

[[ -x "${HYGIENE}" ]] || exit 0

export ENGRAM_HYGIENE_STAMP_DIR="${HOME}/.${AGENT}/engram-hygiene"
"${HYGIENE}" check 2>/dev/null || true

exit 0
