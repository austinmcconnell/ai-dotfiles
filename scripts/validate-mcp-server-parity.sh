#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-mcp-server-parity.sh
#
# Validation-only guard (same pattern as validate-agent-denies.sh) for
# MCP server definitions hand-duplicated between kiro-cli and Claude
# Code:
#   - engram: etc/kiro-cli/settings/mcp.json vs the DESIRED_MCP_SERVERS
#     heredoc in install/claude-code.sh
#   - jira:   etc/kiro-cli/cli-agents/jira.json (mcpServers.jira) vs the
#     same heredoc
#
# Only `command` and `args` are compared — that's where the actual
# silent-drift risk lives (e.g. the jira npm package's pinned version).
# `env` blocks are deliberately NOT compared: kiro's jira mcpServers
# entry has an empty env because npx inherits ATLASSIAN_* from the
# parent shell, while Claude's MCP config requires them declared
# explicitly via ${VAR} interpolation to reach the subprocess. That's a
# genuine platform difference, not duplication to reconcile — same
# reasoning AGENTS.md already applies to the two chmod deny spellings.
#
# This script does NOT generate or rewrite anything.
#
# Exit 0 when both servers match on command+args; exit 1 on any drift.
# ---------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "${DOTFILES_DIR}/install/utils.sh"

KIRO_MCP_JSON="${DOTFILES_DIR}/etc/kiro-cli/settings/mcp.json"
KIRO_JIRA_JSON="${DOTFILES_DIR}/etc/kiro-cli/cli-agents/jira.json"
CLAUDE_INSTALL_SH="${DOTFILES_DIR}/install/claude-code.sh"

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

report_fail() {
    local server="$1" detail="$2"
    echo -e "  ${RED}[FAIL]${RESET} ${server}: ${detail}"
    ((FAILURES++)) || true
}

# Extract the DESIRED_MCP_SERVERS heredoc body from install/claude-code.sh
# as standalone JSON.
claude_desired_servers() {
    awk '/<<'"'"'EOF'"'"'/{flag=1; next} /^EOF$/{flag=0} flag' "$CLAUDE_INSTALL_SH"
}

# Compare command+args for one server between a kiro JSON (at the given
# jq path) and the Claude heredoc's top-level <server> key.
compare_server() {
    local server="$1" kiro_file="$2" kiro_jq_path="$3" claude_json="$4"

    if [[ ! -f "$kiro_file" ]]; then
        report_fail "$server" "kiro config not found: ${kiro_file}"
        return
    fi

    local kiro_def claude_def
    kiro_def="$(jq -Sc "$kiro_jq_path | {command, args}" "$kiro_file" 2>/dev/null)"
    claude_def="$(echo "$claude_json" | jq -Sc ".${server} | {command, args}" 2>/dev/null)"

    if [[ -z "$kiro_def" || "$kiro_def" == "null" ]]; then
        report_fail "$server" "not found in ${kiro_file} (path: ${kiro_jq_path})"
        return
    fi
    if [[ -z "$claude_def" || "$claude_def" == "null" ]]; then
        report_fail "$server" "not found in install/claude-code.sh DESIRED_MCP_SERVERS"
        return
    fi

    if [[ "$kiro_def" != "$claude_def" ]]; then
        report_fail "$server" "command/args diverged"
        echo -e "      kiro:   ${kiro_def}"
        echo -e "      claude: ${claude_def}"
    fi
}

echo -e "${BOLD}Validating MCP server command/args parity (kiro vs claude)${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

claude_json="$(claude_desired_servers)"

if ! echo "$claude_json" | jq empty 2>/dev/null; then
    report_fail "claude" "could not extract valid JSON from install/claude-code.sh's DESIRED_MCP_SERVERS heredoc"
else
    compare_server "engram" "$KIRO_MCP_JSON" ".mcpServers.engram" "$claude_json"
    compare_server "jira" "$KIRO_JIRA_JSON" ".mcpServers.jira" "$claude_json"
fi

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} MCP server parity issue(s) found${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ engram and jira MCP server command/args match across kiro and claude${RESET}"
