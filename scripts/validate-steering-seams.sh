#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-steering-seams.sh
#
# Commit-time guard for the two steering seams in install/ai-tools.sh:
# link_rules_domain (Claude ~/.claude/rules/<domain>) and link_steering_tree
# (kiro ~/.kiro/steering). The runtime probe in each seam checks a built tree;
# this checks the seam logic itself, so a regression fails before it is
# installed.
#
# Every case runs the real functions against a scratch HOME, so the user's
# ~/.claude and ~/.kiro are never touched. Cases:
#   1. A fresh build of each seam succeeds.
#   2. A foreign symlink at the kiro destination is refused, target intact.
#   3. A symlinked ~/.claude/rules is refused, nothing written through it.
#   4. A symlinked ~/.kiro is refused, nothing written through it.
#
# Exit 0 when every case holds; exit 1 otherwise.
# ---------------------------------------------------------------

AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STEERING_SOURCE="${AI_DOTFILES_DIR}/etc/ai/steering"
STEERING_PROBE="security/env-file-protection.md"

WORK="$(mktemp -d)"
trap 'rm -R "$WORK"' EXIT

FAILURES=0

# Load only the function definitions of the installer (everything before the
# distribution section), with the host's overlay sources cleared.
load_installer_functions() {
    unset EXTRA_SKILL_SOURCES EXTRA_STEERING_SOURCES
    export AI_DOTFILES_DIR
    # The installer sources these at top level and sets set -e, so a missing one
    # would abort the sourcing shell. Check first and fail with a clear message.
    local dep
    for dep in install/utils.sh install/enabled-agents.sh; do
        if [[ ! -f "${AI_DOTFILES_DIR}/${dep}" ]]; then
            echo "✗ missing ${AI_DOTFILES_DIR}/${dep}; cannot load installer functions" >&2
            exit 1
        fi
    done
    sed '/^# Distribution/,$d' "${AI_DOTFILES_DIR}/install/ai-tools.sh" >"$WORK/defs.sh"
    source "$WORK/defs.sh" >/dev/null
    set +e
    if ! declare -F link_rules_domain link_steering_tree >/dev/null; then
        echo "✗ link_rules_domain or link_steering_tree is not defined" >&2
        exit 1
    fi
}

# Point HOME at a fresh scratch dir named $1, with ~/.claude and ~/.kiro real.
new_home() {
    HOME="$WORK/$1"
    mkdir -p "$HOME/.claude" "$HOME/.kiro"
}

# Check that the command exits with the expected status.
# Args: $1 = expected rc, $2 = label, $@ = command
expect_rc() {
    local want="$1" label="$2" rc
    shift 2
    "$@" >/dev/null 2>&1
    rc=$?
    if [[ "$rc" -eq "$want" ]]; then
        echo "✓ $label (rc $rc)"
    else
        echo "✗ $label: rc $rc, expected $want" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

# Check that a directory holds no entries.
# Args: $1 = directory, $2 = label
expect_empty() {
    if [[ -z "$(ls -A "$1")" ]]; then
        echo "✓ $2"
    else
        echo "✗ $2: $1 has entries" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

case_fresh_builds() {
    new_home fresh
    expect_rc 0 "rules seam builds a fresh domain" \
        link_rules_domain "$HOME/.claude/rules/code" "$STEERING_SOURCE/code"
    expect_rc 0 "kiro seam builds a fresh tree" \
        link_steering_tree "$HOME/.kiro/steering" "$STEERING_PROBE"
}

case_foreign_kiro_link_refused() {
    new_home foreign-link
    mkdir -p "$WORK/foreign-link-target"
    touch "$WORK/foreign-link-target/keep.md"
    ln -s "$WORK/foreign-link-target" "$HOME/.kiro/steering"
    expect_rc 1 "kiro seam refuses a foreign symlink" \
        link_steering_tree "$HOME/.kiro/steering" "$STEERING_PROBE"
    if [[ -f "$WORK/foreign-link-target/keep.md" ]]; then
        echo "✓ foreign symlink target left intact"
    else
        echo "✗ foreign symlink target was altered" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

case_symlinked_rules_parent_refused() {
    new_home rules-parent
    mkdir -p "$WORK/rules-parent-target"
    rm -R "$HOME/.claude"
    mkdir -p "$HOME/.claude"
    ln -s "$WORK/rules-parent-target" "$HOME/.claude/rules"
    expect_rc 1 "rules seam refuses a symlinked rules parent" \
        link_rules_domain "$HOME/.claude/rules/code" "$STEERING_SOURCE/code"
    expect_empty "$WORK/rules-parent-target" "nothing written through the rules parent link"
}

case_symlinked_kiro_parent_refused() {
    new_home kiro-parent
    mkdir -p "$WORK/kiro-parent-target"
    rm -R "$HOME/.kiro"
    ln -s "$WORK/kiro-parent-target" "$HOME/.kiro"
    expect_rc 1 "kiro seam refuses a symlinked kiro parent" \
        link_steering_tree "$HOME/.kiro/steering" "$STEERING_PROBE"
    expect_empty "$WORK/kiro-parent-target" "nothing written through the kiro parent link"
}

load_installer_functions
case_fresh_builds
case_foreign_kiro_link_refused
case_symlinked_rules_parent_refused
case_symlinked_kiro_parent_refused

if [[ "$FAILURES" -gt 0 ]]; then
    echo "✗ steering seam validation failed: $FAILURES check(s)" >&2
    exit 1
fi
echo "✅ steering seams hold"
