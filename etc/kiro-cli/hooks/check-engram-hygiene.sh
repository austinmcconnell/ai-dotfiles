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

HYGIENE="${AI_DOTFILES_DIR:-$HOME/.dotfiles}/bin/engram-hygiene"

[[ -x "${HYGIENE}" ]] || exit 0

"${HYGIENE}" check 2>/dev/null || true

exit 0
