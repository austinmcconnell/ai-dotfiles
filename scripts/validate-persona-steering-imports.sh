#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-persona-steering-imports.sh
#
# Validation-only guard (same pattern as validate-agent-denies.sh) for
# steering-doc drift between kiro-cli agents and Claude Code personas.
#
# Kiro's per-agent `resources` entries use globs
# (file://~/.kiro/steering/<domain>/**/*.md) that auto-pick-up new
# files. Claude's persona `@`-imports (etc/claude-code/agents/<name>.md)
# are an explicit per-file list — confirmed against current Claude Code
# docs that `@`-imports have no glob/wildcard support. Adding a
# steering file today requires remembering to add a matching @-import
# line to every persona that loads that domain; this script asserts
# that happened, so a missed import fails fast instead of silently
# degrading persona behavior.
#
# This script does NOT generate or rewrite anything. Two things are
# checked per persona:
#   1. Every *.md file in the persona's steering domain(s) has a
#      matching @-import line in the persona's .md body.
#   2. Every domain-steering @-import line in the persona's .md body
#      points at a file that still exists (catches a stale import left
#      behind after a steering file is renamed/removed).
#
# Exit 0 when every persona is in sync; exit 1 on any drift.
# ---------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "${DOTFILES_DIR}/install/utils.sh"

STEERING_DIR="${DOTFILES_DIR}/etc/ai/steering"
PERSONAS_DIR="${DOTFILES_DIR}/etc/claude-code/agents"

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

# Domain each persona loads, matching AGENTS.md's Personas section and
# each kiro agent's `resources` glob. Every persona additionally
# requires security/env-file-protection.md, handled separately below
# (not the universal security/best-practices.md, which reaches personas
# via the generated ~/.claude/rules/, not a per-persona @-import).
persona_domain() {
    case "$1" in
    docs) echo "documentation" ;;
    jira) echo "scrum" ;;
    datadog) echo "datadog" ;;
    ansible) echo "ansible" ;;
    esac
}

PERSONAS=(docs jira datadog ansible)

echo -e "${BOLD}Validating persona steering @-imports against etc/ai/steering/${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

for persona in "${PERSONAS[@]}"; do
    persona_file="${PERSONAS_DIR}/${persona}.md"

    if [[ ! -f "$persona_file" ]]; then
        report_fail "$persona" "persona file not found: ${persona_file}"
        continue
    fi

    domain="$(persona_domain "$persona")"

    for steering_file in "${STEERING_DIR}/${domain}"/*.md; do
        [[ -f "$steering_file" ]] || continue
        basename_f="$(basename "$steering_file")"
        expected_import="@~/.dotfiles/etc/ai/steering/${domain}/${basename_f}"
        if ! grep -qxF -- "$expected_import" "$persona_file"; then
            report_fail "$persona" "missing @-import for steering/${domain}/${basename_f}"
        fi
    done

    expected_security_import="@~/.dotfiles/etc/ai/steering/security/env-file-protection.md"
    if ! grep -qxF -- "$expected_security_import" "$persona_file"; then
        report_fail "$persona" "missing @-import for steering/security/env-file-protection.md"
    fi

    # Reverse check: every domain-steering @-import in the persona file
    # must point at a file that still exists.
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        import_path="${line#@}"
        resolved="${import_path/#\~/$HOME}"
        if [[ ! -f "$resolved" ]]; then
            report_fail "$persona" "stale @-import points at missing file: ${line}"
        fi
    done < <(grep -oE '@~/\.dotfiles/etc/ai/steering/[^[:space:]]+\.md' "$persona_file" || true)
done

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} steering-import drift issue(s) found across personas${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ All ${#PERSONAS[@]} personas have matching steering @-imports${RESET}"
