#!/bin/bash
set -euo pipefail

# agentSpawn hook: when the DEFAULT `code` agent lands in a repo that has a
# tuned specialist agent, emit a one-time confirm-not-switch nudge at session
# start. This catches the "wrong agent from the start" case — `kiro-cli chat`
# defaults to `code`, so a repo whose domain has a better-fit agent (ansible,
# docs) would otherwise be worked in the generalist for a whole session.
#
# Only the `code` agent calls this. The scoped agents (ansible, docs, ...) are
# already the right agent by construction and must stay silent — this mirrors
# the agent-routing.md rule that scoped agents never nudge. Guard on the passed
# agent name so a future miswiring into another agent's config is inert.
#
# Wired for kiro-cli only (hence etc/kiro-cli/hooks/), but the LOGIC is portable.
# Claude Code has equivalents — `claude --agent <name>` launches a session as a
# persona, and a `SessionStart` `command` hook injects context at session begin
# (verified against docs.anthropic.com 2026-09; the older claude-code/README
# note that Claude lacks agentSpawn is stale re: Claude Code 2.1.x). Achieving
# parity is a deliberate follow-up: move this script to the shared etc/ai/hooks/
# and add a SessionStart command hook in claude-code/settings.json that calls it.
# The `--agent X` relaunch wording is already valid Claude syntax, so the body
# needs no change — only relocation + a second wiring.
#
# Session start is the ONLY low-cost moment for this: nothing is invested yet,
# so a relaunch is nearly free. Mid-session routing (a task crossing into a
# specialist's domain) is a DIFFERENT case owned by agent-routing.md steering,
# not this hook.
#
# Detection is precision-over-recall: only a DEFINITIVE root-level marker
# triggers a nudge (ansible.cfg, book.toml). Repos without an unambiguous signal
# — general code, Terraform, mixed — stay silent rather than risk a false
# positive that trains the maintainer to ignore the channel. Corroborating
# directories are not required; the marker file alone decides.

AGENT="${1:-}"

# Only the default landing agent nudges.
[[ "${AGENT}" == "code" ]] || exit 0

# Resolve the repo root; if this is not a git work tree, there is nothing to fit.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${REPO_ROOT}" ]] || exit 0

if [[ -f "${REPO_ROOT}/ansible.cfg" ]]; then
    echo "💡 This looks like an Ansible repo (ansible.cfg). \`code\` is right for cross-cutting or cross-repo work; if this session is squarely Ansible, relaunch with \`--agent ansible\` for its tuned steering, skills, and startup checks."
elif [[ -f "${REPO_ROOT}/book.toml" ]]; then
    echo "💡 This looks like an mdBook docs repo (book.toml). \`code\` is right for cross-cutting or cross-repo work; if this session is squarely documentation, relaunch with \`--agent docs\` for its tuned steering, skills, and startup checks."
fi

exit 0
