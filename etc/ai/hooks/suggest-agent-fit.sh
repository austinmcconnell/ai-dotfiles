#!/bin/bash
set -euo pipefail

# Session-start hook: when the DEFAULT generalist agent lands in a repo that
# has a tuned specialist agent, emit a one-time confirm-not-switch nudge at
# session start. This catches the "wrong agent from the start" case — both
# `kiro-cli chat` and `claude` default to the generalist, so a repo whose
# domain has a better-fit agent (ansible, docs) would otherwise be worked in
# the generalist for a whole session.
#
# Shared cross-tool hook (hence etc/ai/hooks/), wired on both tools:
#   - kiro-cli: `agentSpawn` hook in code.json, passing "code" as $1.
#   - Claude Code: `SessionStart` command hook in claude-code/settings.json.
#     Claude passes hook input as JSON on stdin, not an arg; the default
#     session has no `agent_type`, and a persona launched with
#     `claude --agent <name>` sets `agent_type` to that name.
#
# Only the default generalist nudges. The scoped agents (ansible, docs, ...)
# are already the right agent by construction and must stay silent — this
# mirrors the agent-routing.md rule that scoped agents never nudge. The guard
# below treats two signals as "the generalist": the kiro literal `code` arg,
# and Claude's absent `agent_type` (a default, non-persona session). Any other
# value — a kiro miswiring into another agent's config, or a Claude persona
# session — is inert.
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
#
# The `--agent X` relaunch wording in the messages is valid on both tools
# (`kiro-cli chat --agent X` and `claude --agent X`), so the body is identical
# for each.

AGENT="${1:-}"

# On Claude Code there is no arg; the agent identity arrives as `agent_type` in
# the hook payload on stdin. Read it only when no arg was passed, so the kiro
# path (which passes "code") never blocks on a stdin that isn't coming. An
# absent/empty `agent_type` is the default generalist session — treat it as the
# code-equivalent. jq may be missing or the payload may not be JSON; degrade to
# empty so the guard below simply exits without nudging.
if [[ -z "${AGENT}" ]] && [[ ! -t 0 ]]; then
    PAYLOAD="$(cat)"
    AGENT="$(echo "${PAYLOAD}" | jq -r '.agent_type // empty' 2>/dev/null || true)"
    # Default Claude session: no persona → treat as the generalist.
    AGENT="${AGENT:-code}"
fi

# Only the default landing/generalist agent nudges.
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
