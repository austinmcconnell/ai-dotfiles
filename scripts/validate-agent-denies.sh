#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-agent-denies.sh
#
# Validation-only guard (Option C) for the shared secret/permission
# deny lists duplicated across every kiro-cli agent config.
#
# Each agent in etc/kiro-cli/cli-agents/*.json carries the same
# secret-file and permission-escalation denials in TWO formats:
#   - V2: toolsSettings.shell.deniedCommands  (regex spellings)
#   - V3: permissions.rules[] deny block      (glob spellings)
#
# This script does NOT generate or rewrite anything. It asserts that
# the shared groups are present and identical across all agents, so a
# hand-edit that misses one of the up-to-10 sites fails fast. It also
# asserts the DELIBERATE V2/V3 chmod divergence stays intact (see
# AGENTS.md "Security Layers"): V2 uses the octal regex
# `chmod [0-7]{3,4} .*` with no exclude, while V3 uses the broad glob
# `chmod * *` plus `"exclude": ["chmod +x *"]`. These two spellings
# are correct-by-design and must NOT be reconciled.
#
# Exit 0 when every agent is consistent; exit 1 on any drift.
# ---------------------------------------------------------------

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
source "${DOTFILES_DIR}/install/utils.sh"

AGENTS_DIR="${DOTFILES_DIR}/etc/kiro-cli/cli-agents"
AGENTS=(default docs jira datadog ansible)

FAILURES=0

RED="\033[0;31m"
GREEN="\033[32m"
BOLD="\033[1m"
RESET="\033[0m"

# ---------------------------------------------------------------
# Canonical shared deny sets. Adding a new shared deny means adding
# ONE line here plus the corresponding entry in each agent JSON; the
# check then enforces that every agent actually got it.
# ---------------------------------------------------------------

# Group A + Group B, V2 regex spellings (toolsSettings.shell.deniedCommands)
V2_SHARED_DENIES=(
    'awk .*\.env.*'
    'cat .*\.env.*'
    'grep .*\.env.*'
    'head .*\.env.*'
    'sed .*\.env.*'
    'tail .*\.env.*'
    'find .*\.env.*'
    'cat .*sops/age/keys\.txt.*'
    'cat .*\.agekey.*'
    'sops (decrypt|--decrypt|-d ).*'
    'cat .*\.ssh/id_rsa.*'
    'cat .*\.ssh/id_ed25519.*'
    'cat .*\.ssh/id_ecdsa.*'
    'cat .*\.ssh/id_dsa.*'
    'cat .*\.ssh/.*_key[^.].*'
    'chmod [0-7]{3,4} .*'
    'chmod -R .*'
    'chmod u\+s .*'
    'chmod g\+s .*'
    'chown .*'
    'git add \.'
    'git add -A.*'
    'git add --all.*'
)

# Group A + Group B, V3 glob spellings (permissions.rules deny match)
V3_SHARED_DENIES=(
    'awk *.env*'
    'cat *.env*'
    'grep *.env*'
    'head *.env*'
    'sed *.env*'
    'tail *.env*'
    'find *.env*'
    'cat *sops/age/keys.txt*'
    'cat *.agekey*'
    'sops decrypt*'
    'sops --decrypt*'
    'sops -d *'
    'cat *.ssh/id_rsa*'
    'cat *.ssh/id_ed25519*'
    'cat *.ssh/id_ecdsa*'
    'cat *.ssh/id_dsa*'
    'cat *.ssh/*_key*'
    'chmod * *'
    'chmod -R *'
    'chmod u+s *'
    'chmod g+s *'
    'chown *'
    'git add .'
    'git add -A*'
    'git add --all*'
)

report_fail() {
    local agent="$1" detail="$2"
    echo -e "  ${RED}[FAIL]${RESET} ${agent}: ${detail}"
    ((FAILURES++)) || true
}

# Extract V2 deniedCommands as newline-delimited literals.
v2_denies() {
    jq -r '.toolsSettings.shell.deniedCommands[]' "$1"
}

# Extract the V3 shell deny-rule match[] as newline-delimited literals.
v3_denies() {
    jq -r '.permissions.rules[]
        | select(.effect == "deny" and .capability == "shell")
        | .match[]' "$1"
}

# Extract the V3 shell deny-rule exclude[] as newline-delimited literals.
v3_excludes() {
    jq -r '.permissions.rules[]
        | select(.effect == "deny" and .capability == "shell")
        | .exclude[]? // empty' "$1"
}

# Assert every canonical entry appears in the extracted haystack.
assert_all_present() {
    local agent="$1" label="$2" haystack="$3"
    shift 3
    local entry
    for entry in "$@"; do
        if ! grep -qxF -- "$entry" <<<"$haystack"; then
            report_fail "$agent" "${label} missing deny: ${entry}"
        fi
    done
}

# The chmod divergence is intentional. Verify BOTH spellings exist in
# their respective format and that only V3 carries the chmod +x exclude.
assert_chmod_divergence() {
    local agent="$1" v2="$2" v3="$3" v3_excl="$4"

    if ! grep -qxF -- 'chmod [0-7]{3,4} .*' <<<"$v2"; then
        report_fail "$agent" "V2 lost octal chmod regex 'chmod [0-7]{3,4} .*'"
    fi
    if grep -qxF -- 'chmod +x *' <<<"$v2"; then
        report_fail "$agent" "V2 must NOT list 'chmod +x *' as a deny"
    fi
    if ! grep -qxF -- 'chmod * *' <<<"$v3"; then
        report_fail "$agent" "V3 lost broad chmod glob 'chmod * *'"
    fi
    if ! grep -qxF -- 'chmod +x *' <<<"$v3_excl"; then
        report_fail "$agent" "V3 deny rule missing exclude 'chmod +x *'"
    fi
}

echo -e "${BOLD}Validating shared agent deny lists${RESET}"
echo "──────────────────────────────────────────────────────────────────────────"

for agent in "${AGENTS[@]}"; do
    config="${AGENTS_DIR}/${agent}.json"

    if [[ ! -f "$config" ]]; then
        report_fail "$agent" "config not found: ${config}"
        continue
    fi

    if ! jq empty "$config" 2>/dev/null; then
        report_fail "$agent" "invalid JSON"
        continue
    fi

    v2="$(v2_denies "$config")"
    v3="$(v3_denies "$config")"
    v3_excl="$(v3_excludes "$config")"

    assert_all_present "$agent" "V2" "$v2" "${V2_SHARED_DENIES[@]}"
    assert_all_present "$agent" "V3" "$v3" "${V3_SHARED_DENIES[@]}"
    assert_chmod_divergence "$agent" "$v2" "$v3" "$v3_excl"
done

echo "──────────────────────────────────────────────────────────────────────────"
if ((FAILURES > 0)); then
    echo -e "${RED}✗ ${FAILURES} deny-list drift issue(s) found across agents${RESET}"
    exit 1
fi

echo -e "${GREEN}✓ All ${#AGENTS[@]} agents share consistent secret/permission deny lists${RESET}"
