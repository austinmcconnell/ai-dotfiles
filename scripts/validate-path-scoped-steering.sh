#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------
# validate-path-scoped-steering.sh
#
# Commit-time guard for CLAUDE_PATH_SCOPED_STEERING_DOMAINS in
# install/ai-tools.sh. Those domains are linked into ~/.claude/rules, where a
# doc without paths: frontmatter loads in every Claude Code session instead of
# only after a session reads a matching file. Fails when a listed domain is
# missing or when any of its docs lacks a paths: key in its leading frontmatter.
#
# Exit 0 when every doc is path-scoped; exit 1 otherwise.
# ---------------------------------------------------------------

AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INSTALLER="${AI_DOTFILES_DIR}/install/ai-tools.sh"
STEERING_SOURCE="${AI_DOTFILES_DIR}/etc/ai/steering"

# Print the domains in the installer's array, one per line.
read_scoped_domains() {
    local line
    if ! line="$(grep --extended-regexp '^CLAUDE_PATH_SCOPED_STEERING_DOMAINS=\(' "${INSTALLER}")"; then
        echo "✗ CLAUDE_PATH_SCOPED_STEERING_DOMAINS not found in ${INSTALLER}" >&2
        return 1
    fi
    line="${line#*\(}"
    line="${line%\)*}"
    tr ' ' '\n' <<<"${line}" | grep --invert-match '^$'
}

# Succeed when $1 opens with frontmatter that has a top-level paths: key.
has_paths_frontmatter() {
    awk '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        /^paths:/ { found = 1 }
        END { exit found ? 0 : 1 }
    ' "$1"
}

failures=0
domains="$(read_scoped_domains)"

while IFS= read -r domain; do
    dir="${STEERING_SOURCE}/${domain}"
    if [[ ! -d "${dir}" ]]; then
        echo "✗ ${domain}: no steering domain at ${dir}" >&2
        failures=$((failures + 1))
        continue
    fi
    for doc in "${dir}"/*.md; do
        [[ -f "${doc}" ]] || continue
        if ! has_paths_frontmatter "${doc}"; then
            echo "✗ ${doc#"${AI_DOTFILES_DIR}/"}: no paths: frontmatter, so Claude Code" \
                "would load it in every session" >&2
            failures=$((failures + 1))
        fi
    done
done <<<"${domains}"

if ((failures > 0)); then
    exit 1
fi
echo "✓ every doc in a path-scoped steering domain has paths: frontmatter"
