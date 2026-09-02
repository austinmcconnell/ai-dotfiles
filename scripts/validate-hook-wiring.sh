#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-hook-wiring.sh
#
# Validation-only guard (same pattern as validate-agent-denies.sh) for
# hook-wiring drift between kiro-cli agents and Claude Code. Both tools
# reference the same shared etc/ai/hooks/*.sh scripts by absolute path,
# but WHICH agent/event fires WHICH script is asserted independently in
# multiple places: kiro's per-agent hooks[] arrays vs Claude's global
# settings.json event arrays and personas' own hooks: frontmatter. This
# is the exact failure mode that caused real drift before this branch
# (the engram hygiene hook was wired into every kiro agent but silently
# absent from Claude's settings.json).
#
# Two things are checked:
#   1. Every script in etc/ai/hooks/ (cross-tool by convention) is wired
#      into the kiro agents AGENTS.md says it should be, AND is
#      referenced somewhere on the Claude side (settings.json or a
#      persona's hooks: frontmatter). A cross-tool script with no
#      Claude-side reference at all is exactly the "shared script,
#      tool-specific wiring only" gap this check exists to catch.
#   2. Every script in etc/kiro-cli/hooks/ (genuinely kiro-only per
#      AGENTS.md's "What Claude Code Does NOT Have") has NO reference
#      anywhere on the Claude side — guarding that claim from silently
#      becoming false.
#
# Known, documented, intentional asymmetries are encoded explicitly
# below (not treated as drift):
#   - audit-shell-commands.sh is wired to kiro's `code` (default) agent only
#     (kiro's other 4 agents deny aws/kubectl outright instead), but
#     globally on the Claude side (Claude has no per-agent scoping
#     mechanism for this). Claude's global wiring therefore also covers
#     its 4 personas, which kiro's design does not — harmless, since
#     this hook only audits/logs, it doesn't block anything.
#   - recall-memory.sh / check-engram-hygiene.sh fire on kiro's
#     `agentSpawn` vs Claude's `SessionStart` — different event names
#     for the same "session start" moment, by platform design. This
#     script does not check exact event-name pairing, only presence.
#   - block-persona-shell-commands.sh mirrors kiro's inline
#     `toolsSettings.shell.deniedCommands` (permission config, not a
#     kiro hook script) — it has no etc/kiro-cli agent hook counterpart
#     to compare against, so it's checked for Claude-side presence only.
#
# kb-staleness.sh is excluded entirely: it's a git hook for the research
# repo (wired via `git config` in install/kiro-cli.sh), not a kiro
# agent hook, so it has no place in this comparison.
#
# This script does NOT generate or rewrite anything.
#
# Exit 0 when wiring matches expectations; exit 1 on any drift.
# ---------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "${DOTFILES_DIR}/install/utils.sh"

AI_HOOKS_DIR="${DOTFILES_DIR}/etc/ai/hooks"
KIRO_HOOKS_DIR="${DOTFILES_DIR}/etc/kiro-cli/hooks"
KIRO_AGENTS_DIR="${DOTFILES_DIR}/etc/kiro-cli/cli-agents"
CLAUDE_SETTINGS="${DOTFILES_DIR}/etc/claude-code/settings.json"
CLAUDE_AGENTS_DIR="${DOTFILES_DIR}/etc/claude-code/agents"

KIRO_AGENTS=(code docs jira datadog ansible)

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

# Which kiro agents SHOULD wire this cross-tool script, per AGENTS.md.
#   all5          - every kiro agent wires it
#   default_only  - only the code (default) agent wires it (documented asymmetry)
#   none          - not a kiro hook at all (Claude-only by design)
expected_kiro_scope() {
    case "$1" in
    block-env-files.sh) echo "all5" ;;
    block-sops-age-files.sh) echo "all5" ;;
    block-ssh-private-keys.sh) echo "all5" ;;
    block-memory-secrets.sh) echo "all5" ;;
    correction-capture.sh) echo "all5" ;;
    recall-memory.sh) echo "all5" ;;
    check-engram-hygiene.sh) echo "all5" ;;
    audit-shell-commands.sh) echo "default_only" ;;
    block-persona-shell-commands.sh) echo "none" ;;
    *) echo "unknown" ;;
    esac
}

# Kiro agents whose hooks[] array references the given script basename.
kiro_agents_wiring() {
    local script="$1" agent config
    for agent in "${KIRO_AGENTS[@]}"; do
        config="${KIRO_AGENTS_DIR}/${agent}.json"
        [[ -f "$config" ]] || continue
        if jq -r '.hooks[]?.action.command' "$config" 2>/dev/null | grep -qF "/${script}"; then
            echo "$agent"
        fi
    done
}

# True if the script basename appears anywhere on the Claude side
# (global settings.json hooks, or any persona's own hooks: frontmatter).
claude_side_references() {
    local script="$1"
    grep -qF "/${script}" "$CLAUDE_SETTINGS" 2>/dev/null && return 0
    grep -qF "/${script}" "$CLAUDE_AGENTS_DIR"/*.md 2>/dev/null && return 0
    return 1
}

echo -e "${BOLD}Validating hook wiring parity (kiro agents vs claude)${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

for script_path in "$AI_HOOKS_DIR"/*.sh; do
    [[ -f "$script_path" ]] || continue
    script="$(basename "$script_path")"
    scope="$(expected_kiro_scope "$script")"

    actual_agents="$(kiro_agents_wiring "$script")"
    actual_agents_display="$(echo "$actual_agents" | tr '\n' ' ' | sed 's/ *$//')"

    case "$scope" in
    all5)
        for agent in "${KIRO_AGENTS[@]}"; do
            if ! grep -qxF -- "$agent" <<<"$actual_agents"; then
                report_fail "$script" "expected in kiro agent '${agent}' but missing"
            fi
        done
        ;;
    default_only)
        if [[ "$actual_agents_display" != "code" ]]; then
            report_fail "$script" "expected ONLY in kiro's code (default) agent, found in: ${actual_agents_display:-<none>}"
        fi
        ;;
    none)
        if [[ -n "$actual_agents_display" ]]; then
            report_fail "$script" "expected in NO kiro agent (Claude-only by design), found in: ${actual_agents_display}"
        fi
        ;;
    unknown)
        report_fail "$script" "new script in etc/ai/hooks/ has no expected_kiro_scope() classification — add one"
        continue
        ;;
    esac

    if ! claude_side_references "$script"; then
        report_fail "$script" "lives in etc/ai/hooks/ (cross-tool) but has no reference anywhere on the Claude side"
    fi
done

for script_path in "$KIRO_HOOKS_DIR"/*.sh; do
    [[ -f "$script_path" ]] || continue
    script="$(basename "$script_path")"
    [[ "$script" == "kb-staleness.sh" ]] && continue

    if claude_side_references "$script"; then
        report_fail "$script" "genuinely-kiro-only script (per AGENTS.md) is now referenced on the Claude side"
    fi
done

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} hook-wiring drift issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ Hook wiring matches expectations across kiro agents and claude${RESET}"
