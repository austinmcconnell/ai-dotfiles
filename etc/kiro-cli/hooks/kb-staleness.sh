#!/bin/bash
set -euo pipefail

# Git hook (post-commit, post-merge, post-rewrite) that marks the research
# knowledge base as stale so kiro-cli agents prompt for re-indexing.

SENTINEL="$HOME/.kiro/research-kb-stale"
printf 'default\ndocs\n' >"${SENTINEL}"
