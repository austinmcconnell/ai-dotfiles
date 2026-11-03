#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-steering-references.sh
#
# Commit-time guard for dangling references in steering docs and skills.
#
# WHY THIS EXISTS
# Steering docs and SKILL.md files name repo paths and other skills. A rename or
# removal leaves those names pointing at nothing, and agents act on them anyway.
# The drift check that used to catch this lived in the main dotfiles repo and was
# removed with the AI tree, so this validator is the check now.
#
# WHAT IT CHECKS
#   1. Backticked repo paths under etc/, scripts/, install/, and bin/ in steering
#      docs and SKILL.md files exist in this repo. Tokens with a glob, a <placeholder>,
#      or a ~, $, or { prefix are skipped: they describe a pattern or a location
#      outside this repo, and the doc should say so.
#   2. Skill names in the trigger tables (steering/**/skill-loading-triggers.md)
#      each have a SKILL.md under etc/ai/skills/.
#
# Files under skills/*/references/ are not scanned. They hold worked examples that
# name files the example itself creates.
#
# Exit 0 when every reference resolves; exit 1 otherwise.
# ---------------------------------------------------------------

# Resolve the AI dotfiles root from this script's location so the validator always
# checks THIS repo, not whatever $AI_DOTFILES_DIR points at in the shell.
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

STEERING_DIR="${AI_DOTFILES_DIR}/etc/ai/steering"
SKILLS_DIR="${AI_DOTFILES_DIR}/etc/ai/skills"

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

fail() {
    echo -e "${RED}✗${RESET} $1"
    FAILURES=$((FAILURES + 1))
}

# Documents whose references are checked: steering docs and skill entry points.
scanned_docs() {
    find "${STEERING_DIR}" -name '*.md'
    find "${SKILLS_DIR}" -path '*/references/*' -prune -o -name 'SKILL.md' -print
}

# Backticked repo paths in one document. Prints one path per line.
path_refs() {
    grep -oE "\`(etc|scripts|install|bin)/[^\`]+\`" "$1" | tr -d '`' | sort -u || true
}

# True for tokens that name a pattern or a location outside this repo.
is_external_or_pattern() {
    case "$1" in
    *'*'* | *'<'* | *'$'* | *'{'* | '~'*) return 0 ;;
    *) return 1 ;;
    esac
}

check_path_refs() {
    local doc ref
    while IFS= read -r doc; do
        while IFS= read -r ref; do
            [[ -n "${ref}" ]] || continue
            is_external_or_pattern "${ref}" && continue
            [[ -e "${AI_DOTFILES_DIR}/${ref}" ]] ||
                fail "${doc#"${AI_DOTFILES_DIR}"/}: references missing path '${ref}'"
        done < <(path_refs "${doc}")
    done < <(scanned_docs)
}

# Skill names in the last column of the trigger tables.
trigger_table_skills() {
    find "${STEERING_DIR}" -name '*skill-loading-triggers.md' -print0 |
        xargs -0 grep -hoE "\\| \`[a-z0-9-]+\` \\|$" 2>/dev/null |
        grep -oE '[a-z0-9-]+' | sort -u || true
}

check_trigger_table_skills() {
    local name matches
    while IFS= read -r name; do
        [[ -n "${name}" ]] || continue
        matches="$(find "${SKILLS_DIR}" -path "*/${name}/SKILL.md")"
        [[ -n "${matches}" ]] || fail "trigger table names skill '${name}' with no SKILL.md under etc/ai/skills/"
    done < <(trigger_table_skills)
}

echo -e "${BOLD}Validating steering and skill references${RESET}"

check_path_refs
check_trigger_table_skills

if [[ "${FAILURES}" -eq 0 ]]; then
    echo -e "${GREEN}✓ All steering and skill references resolve${RESET}"
    exit 0
fi

echo "${FAILURES} dangling reference(s). Fix the doc, or move the reference outside the scanned paths."
exit 1
