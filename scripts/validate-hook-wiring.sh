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
#      into the kiro agents AGENTS.md says it should be, AND is wired in
#      etc/claude-code/settings.json under the expected Claude event and
#      matcher. Presence alone is not enough: a script bound to the wrong
#      event or matcher is silently dead.
#   2. Every script in etc/kiro-cli/hooks/ (genuinely kiro-only per
#      AGENTS.md's "What Claude Code Does NOT Have") has NO Claude wiring
#      in settings.json — guarding that claim from silently becoming false.
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
#     for the same "session start" moment, by platform design. The Claude
#     side is checked against `SessionStart`.
#   - block-persona-shell-commands.sh mirrors kiro's inline
#     `toolsSettings.shell.deniedCommands` (permission config, not a
#     kiro hook script) — it has no etc/kiro-cli agent hook counterpart
#     to compare against, so only its Claude wiring is checked.
#
# kb-staleness.sh is excluded entirely: it's a git hook for the research
# repo (wired via `git config` in install/kiro-cli.sh), not a kiro
# agent hook, so it has no place in this comparison.
#
# This script does NOT generate or rewrite anything.
#
# Exit 0 when wiring matches expectations; exit 1 on any drift.
# ---------------------------------------------------------------

# Resolve the AI dotfiles root from this script's location so the validator
# always checks THIS repo, not whatever $DOTFILES_DIR points at in the shell.
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

AI_HOOKS_DIR="${AI_DOTFILES_DIR}/etc/ai/hooks"
KIRO_HOOKS_DIR="${AI_DOTFILES_DIR}/etc/kiro-cli/hooks"
KIRO_AGENTS_DIR="${AI_DOTFILES_DIR}/etc/kiro-cli/cli-agents"
CLAUDE_SETTINGS="${AI_DOTFILES_DIR}/etc/claude-code/settings.json"

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
    block-shell-trace-mode.sh) echo "all5" ;;
    block-memory-secrets.sh) echo "all5" ;;
    correction-capture.sh) echo "all5" ;;
    recall-memory.sh) echo "all5" ;;
    check-engram-hygiene.sh) echo "all5" ;;
    audit-shell-commands.sh) echo "default_only" ;;
    suggest-agent-fit.sh) echo "default_only" ;;
    core-analyses-status.sh) echo "default_only" ;;
    block-persona-shell-commands.sh) echo "none" ;;
    warn-memory-exfil.sh) echo "none" ;;
    log-compaction-event.sh) echo "none" ;;
    suggest-context-checkpoint.sh) echo "none" ;;
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

# Which Claude event and matcher SHOULD wire each cross-tool script, one
# "<Event> <matcher>" per entry. Claude's wiring lives only in settings.json.
expected_claude_wiring() {
    case "$1" in
    recall-memory.sh | check-engram-hygiene.sh | core-analyses-status.sh) echo "SessionStart startup|resume" ;;
    suggest-agent-fit.sh) echo "SessionStart startup" ;;
    block-env-files.sh | block-sops-age-files.sh | block-ssh-private-keys.sh | block-shell-trace-mode.sh) echo "PreToolUse *" ;;
    block-memory-secrets.sh | warn-memory-exfil.sh) echo "PreToolUse mcp__engram__.*" ;;
    block-persona-shell-commands.sh) echo "PreToolUse Bash" ;;
    audit-shell-commands.sh) echo "PostToolUse Bash" ;;
    correction-capture.sh | suggest-context-checkpoint.sh) echo "UserPromptSubmit <none>" ;;
    log-compaction-event.sh) printf '%s\n' "PreCompact *" "PostCompact *" ;;
    esac
}

# Claude "<Event> <matcher>" pairs whose hook command runs the script. Matches a
# whole path token, so a comment or an unrelated key cannot count as wiring.
claude_wiring() {
    local script="$1"
    jq -r --arg script "$script" '
        .hooks | to_entries[] | .key as $event | .value[] | (.matcher // "<none>") as $matcher
        | .hooks[]
        | select(.command | split(" ") | any(endswith("/" + $script)))
        | "\($event) \($matcher)"' "$CLAUDE_SETTINGS" | sort
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

    expected_claude="$(expected_claude_wiring "$script" | sort)"
    actual_claude="$(claude_wiring "$script")"
    if [[ "$actual_claude" != "$expected_claude" ]]; then
        report_fail "$script" "Claude wiring expected [${expected_claude//$'\n'/, }], found [${actual_claude//$'\n'/, }]"
    fi
done

for script_path in "$KIRO_HOOKS_DIR"/*.sh; do
    [[ -f "$script_path" ]] || continue
    script="$(basename "$script_path")"
    [[ "$script" == "kb-staleness.sh" ]] && continue

    if [[ -n "$(claude_wiring "$script")" ]]; then
        report_fail "$script" "genuinely-kiro-only script (per AGENTS.md) is now wired on the Claude side"
    fi
done

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} hook-wiring drift issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ Hook wiring matches expectations across kiro agents and claude${RESET}"
