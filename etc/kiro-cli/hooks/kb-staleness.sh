#!/bin/bash
set -euo pipefail

# Git hook (post-commit, post-merge, post-rewrite) that marks the research
# knowledge base as stale so kiro-cli agents prompt for re-indexing.

# Agents whose config runs check-research-kb.sh against this sentinel. Keep in
# sync with the agents that reference the research knowledge base: code,
# docs, and ansible each run `check-research-kb.sh <agent>` on agentSpawn and
# only warn when their name appears here (matched with an anchored `^<agent>$`).
SENTINEL="$HOME/.kiro/research-kb-stale"
printf 'code\ndocs\nansible\n' >"${SENTINEL}"
