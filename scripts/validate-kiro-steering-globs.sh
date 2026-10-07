#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-kiro-steering-globs.sh
#
# Validation-only guard (same pattern as validate-agent-denies.sh) for the
# invariant that install/ai-tools.sh's kiro steering build depends on.
#
# install/ai-tools.sh builds ~/.kiro/steering as a real dir of per-domain real
# dirs holding per-file symlinks to etc/ai/steering/<domain>/*.md plus any
# host-local overlay *.md. Every kiro agent reads steering through a per-domain
# recursive glob (file://~/.kiro/steering/<domain>/**/*.md). That glob only
# resolves — and an overlay file only lands in the same namespace it matches —
# if the public docs sit one level deep inside their domain dir.
#
# This script generates nothing. It asserts two halves of that contract so drift
# fails fast at commit time (the runtime probe in link_steering_tree guards the
# built tree; this guards the source-of-truth the build reads — different
# failures, per shell-conventions):
#   1. Every per-domain steering glob/ref in an agent JSON points at a domain
#      that exists under etc/ai/steering/.
#   2. Every public steering domain holds its *.md exactly one level deep
#      (<domain>/*.md, no nesting).
#
# Host-local overlay dirs (~/.extra/steering-sources) are not checked: they are
# absent in CI and on a public clone, and their dangling-path handling lives in
# link_steering_tree.
#
# Exit 0 when the contract holds; exit 1 on any drift.
# ---------------------------------------------------------------

# Resolve the AI dotfiles root from this script's location so the validator
# always checks THIS repo, not whatever $DOTFILES_DIR points at in the shell.
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

STEERING_DIR="${AI_DOTFILES_DIR}/etc/ai/steering"
AGENTS_DIR="${AI_DOTFILES_DIR}/etc/kiro-cli/cli-agents"

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

report_fail() {
    local scope="$1" detail="$2"
    echo -e "  ${RED}[FAIL]${RESET} ${scope}: ${detail}"
    ((FAILURES++)) || true
}

echo -e "${BOLD}Validating kiro steering per-domain glob contract${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

# Check 1: every per-domain steering resource in an agent JSON names a real
# domain. Pull the domain segment out of each file://.../steering/<domain>/...
# resource and confirm the matching etc/ai/steering/<domain>/ dir exists.
for config in "${AGENTS_DIR}"/*.json; do
    [[ -f "$config" ]] || continue
    agent="$(basename "$config" .json)"

    if ! jq empty "$config" 2>/dev/null; then
        report_fail "$agent" "invalid JSON"
        continue
    fi

    while IFS= read -r domain; do
        [[ -n "$domain" ]] || continue
        if [[ ! -d "${STEERING_DIR}/${domain}" ]]; then
            report_fail "$agent" "steering resource references missing domain: ${domain}/"
        fi
    done < <(
        jq -r '.resources[]? // empty' "$config" |
            sed -n 's#^file://.*/\.kiro/steering/\([^/]*\)/.*#\1#p' |
            sort -u
    )
done

# Check 2: every public steering domain holds its *.md exactly one level deep.
# A doc nested under <domain>/<subdir>/ is matched by the ** glob but falls
# outside the flat namespace an overlay merges into.
for domain_dir in "${STEERING_DIR}"/*/; do
    [[ -d "$domain_dir" ]] || continue
    domain="$(basename "$domain_dir")"

    if [[ -z "$(find "$domain_dir" -maxdepth 1 -name '*.md' -print -quit)" ]]; then
        report_fail "$domain" "no *.md directly under steering/${domain}/"
    fi

    while IFS= read -r nested; do
        report_fail "$domain" "steering doc nested deeper than one level: ${nested#"${STEERING_DIR}/"}"
    done < <(find "$domain_dir" -mindepth 2 -name '*.md')
done

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} kiro steering glob contract issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ Kiro steering per-domain glob contract holds${RESET}"
