#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-persona-steering.sh
#
# Validation-only guard (same pattern as validate-agent-denies.sh) that the
# Claude Code personas can receive their domain steering.
#
# Claude Code uses a persona's markdown body verbatim as its system prompt and
# does not expand `@path` imports there, so install/ai-tools.sh generates the
# installed personas with the steering inlined (scripts/generate-personas.sh).
# Checks, per persona in install/persona-domains.sh:
#   1. The persona source file exists and its steering domain has at least one
#      doc.
#   2. The source has no `@`-import lines (they would reach the model as
#      literal text).
# The shared/ domain every persona inherits must also hold at least one doc.
# Then the generator runs into a temporary directory, which fails if any
# persona is missing an inlined steering doc (domain, shared, or security).
#
# This script does NOT touch ~/.claude. Exit 0 when everything holds; exit 1 on
# any problem.
# ---------------------------------------------------------------

# Resolve the AI dotfiles root from this script's location so the validator
# always checks THIS repo, not whatever $DOTFILES_DIR points at in the shell.
AI_DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AI_DOTFILES_DIR

source "$AI_DOTFILES_DIR/install/persona-domains.sh"

STEERING_DIR="${AI_DOTFILES_DIR}/etc/ai/steering"
PERSONAS_DIR="${AI_DOTFILES_DIR}/etc/claude-code/agents"

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

report_fail() {
    local persona="$1" detail="$2"
    echo -e "  ${RED}[FAIL]${RESET} ${persona}: ${detail}"
    ((FAILURES++)) || true
}

echo -e "${BOLD}Validating persona steering against etc/ai/steering/${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

if [[ -z "$(find "${STEERING_DIR}/shared" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ]]; then
    report_fail "shared" "no steering docs found in steering/shared/"
fi

for persona in "${PERSONAS[@]}"; do
    persona_file="${PERSONAS_DIR}/${persona}.md"

    if [[ ! -f "$persona_file" ]]; then
        report_fail "$persona" "persona file not found: ${persona_file}"
        continue
    fi

    if ! domain="$(persona_domain "$persona")"; then
        report_fail "$persona" "no steering domain mapped in install/persona-domains.sh"
        continue
    fi

    if [[ -z "$(find "${STEERING_DIR}/${domain}" -maxdepth 1 -name '*.md' -print -quit 2>/dev/null)" ]]; then
        report_fail "$persona" "no steering docs found in steering/${domain}/"
    fi

    if grep -qE '^@[~/.]' "$persona_file"; then
        report_fail "$persona" "contains @-import lines; Claude Code does not expand them in a persona body"
    fi
done

generated_dir="$(mktemp -d)"
trap 'rm -rf "$generated_dir"' EXIT

if ! generator_output="$("${AI_DOTFILES_DIR}/scripts/generate-personas.sh" "${generated_dir}/agents" 2>&1)"; then
    report_fail "generator" "${generator_output}"
fi

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} persona steering issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ All ${#PERSONAS[@]} personas generate with their steering inlined${RESET}"
