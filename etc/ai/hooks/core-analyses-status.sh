#!/bin/bash
set -euo pipefail

# Report the state of a repo's core analyses in analysis/. Called from the Claude
# SessionStart hook and the Kiro agentSpawn hook (code agent only); output is
# injected into session context so the agent can mention it.
#
# Prints nothing for a directory outside the projects root (CORE_ANALYSIS_PROJECTS_ROOT,
# default $HOME/projects), outside a git work tree, or on any branch other than main
# or master.
#
# Emits at most one line:
#   - analysis/ absent, or no core file present: a quiet note that none exist.
#   - some core files missing and none stale: a quiet note naming the missing ones.
#   - one or more core files stale: the count and names, plus any missing names, with
#     a directive to offer a refresh.
#   - all four current: nothing.
#
# A core file is missing when it is not a regular file. It is stale when it exists
# but is unreadable, records no HEAD commit, records a commit that is not an ancestor
# of HEAD (e.g. after a rebase), or sits more than CORE_ANALYSIS_MAX_COMMITS_BEHIND
# commits behind HEAD.

readonly CORE_ANALYSIS_DIR="analysis"
readonly CORE_ANALYSIS_MAX_COMMITS_BEHIND=20
readonly CORE_ANALYSIS_NAMES=(project architecture schema integration)
readonly PROJECTS_ROOT="${CORE_ANALYSIS_PROJECTS_ROOT:-${HOME:-}/projects}"

is_stale() {
    local root="${1}" file="${2}" head="${3}" recorded behind
    recorded="$(sed -n 's/^\*\*HEAD Commit:\*\* *\([0-9a-f]*\).*/\1/p' "${file}" 2>/dev/null | head -1)" || true
    [[ -n "${recorded}" ]] || return 0
    git -C "${root}" merge-base --is-ancestor "${recorded}" "${head}" 2>/dev/null || return 0
    behind="$(git -C "${root}" rev-list --count "${recorded}..${head}")"
    ((behind > CORE_ANALYSIS_MAX_COMMITS_BEHIND))
}

join_names() {
    local IFS=','
    local out="$*"
    echo "${out//,/, }"
}

main() {
    local dir="${1:-${PWD}}" projects_root root head branch name file
    local -a stale_names=() missing_names=()

    projects_root="$(cd "${PROJECTS_ROOT}" 2>/dev/null && pwd -P)" || return 0
    dir="$(cd "${dir}" 2>/dev/null && pwd -P)" || return 0
    case "${dir}" in
    "${projects_root}"/*) ;;
    *) return 0 ;;
    esac

    root="$(git -C "${dir}" rev-parse --show-toplevel 2>/dev/null)" || return 0
    head="$(git -C "${root}" rev-parse --verify -q HEAD)" || return 0

    branch="$(git -C "${root}" symbolic-ref --short -q HEAD)" || return 0
    case "${branch}" in
    main | master) ;;
    *) return 0 ;;
    esac

    for name in "${CORE_ANALYSIS_NAMES[@]}"; do
        file="${root}/${CORE_ANALYSIS_DIR}/${name}-analysis.md"
        if [[ ! -f "${file}" ]]; then
            missing_names+=("${name}")
        elif is_stale "${root}" "${file}" "${head}"; then
            stale_names+=("${name}")
        fi
    done

    if ((${#missing_names[@]} == ${#CORE_ANALYSIS_NAMES[@]})); then
        echo "💡 No core analyses in ${CORE_ANALYSIS_DIR}/ yet. Mention this once in your first reply only if the user's question would benefit. Do not generate them."
    elif ((${#stale_names[@]} > 0)); then
        local msg stale_list prompts_dir
        stale_list="$(join_names "${stale_names[@]}")"
        prompts_dir="${AI_DOTFILES_DIR:-${HOME:-}/.ai-dotfiles}/etc/ai/prompts/"
        msg="🔍 ${#stale_names[@]} of ${#CORE_ANALYSIS_NAMES[@]} core analyses in ${CORE_ANALYSIS_DIR}/ are stale: ${stale_list}. "
        if ((${#missing_names[@]} > 0)); then
            msg+="Also missing: $(join_names "${missing_names[@]}"). "
        fi
        msg+="In your first reply, before answering anything else, tell the user this and offer to refresh the stale files: the matching <name>-analysis.md prompt from ${prompts_dir} for one file, or run-core-analyses.md with those file names in a background subagent for two or more. Do not regenerate without their go-ahead."
        echo "${msg}"
    elif ((${#missing_names[@]} > 0)); then
        echo "💡 Core analyses in ${CORE_ANALYSIS_DIR}/ are missing: $(join_names "${missing_names[@]}"). Mention this once in your first reply only if the user's question would benefit. Do not generate them."
    fi
}

main "$@"
exit 0
