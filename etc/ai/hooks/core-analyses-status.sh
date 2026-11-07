#!/bin/bash
set -euo pipefail

# Report the state of a repo's core analyses in analysis/. Called from the Claude
# SessionStart hook; output is injected into session context so the agent can
# mention it. Prints nothing for directories outside $PROJECTS_ROOT, outside a
# git work tree, or on any branch other than main or master.
#
# Emits at most one line:
#   - analysis/ absent or holding no core file: a generation candidate.
#   - some core files missing and none stale: a quiet note naming them.
#   - one or more core files stale: the count and names (plus any missing names).
#
# A core file is missing when it is not a regular file. It is stale when it exists
# but records no HEAD commit, records a commit that is not an ancestor of HEAD
# (e.g. after a rebase), or sits more than CORE_ANALYSIS_MAX_COMMITS_BEHIND commits
# behind HEAD.

readonly CORE_ANALYSIS_DIR="analysis"
readonly CORE_ANALYSIS_MAX_COMMITS_BEHIND=20
readonly CORE_ANALYSIS_NAMES=(project architecture schema integration)
readonly PROJECTS_ROOT="${CORE_ANALYSIS_PROJECTS_ROOT:-$HOME/projects}"

is_stale() {
    local root="$1" file="$2" head="$3" recorded behind
    recorded="$(sed -n 's/^\*\*HEAD Commit:\*\* *\([0-9a-f]*\).*/\1/p' "$file" | head -1)"
    [[ -n "$recorded" ]] || return 0
    git -C "$root" merge-base --is-ancestor "$recorded" "$head" 2>/dev/null || return 0
    behind="$(git -C "$root" rev-list --count "$recorded..$head")"
    ((behind > CORE_ANALYSIS_MAX_COMMITS_BEHIND))
}

join_names() {
    local IFS=','
    local out="$*"
    echo "${out//,/, }"
}

main() {
    local dir="${1:-$PWD}" root head branch name file
    local -a stale_names=() missing_names=()

    dir="$(cd "$dir" && pwd -P)" || return 0
    case "$dir" in
    "$PROJECTS_ROOT"/*) ;;
    *) return 0 ;;
    esac

    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 0
    head="$(git -C "$root" rev-parse --verify -q HEAD)" || return 0

    branch="$(git -C "$root" symbolic-ref --short -q HEAD)" || return 0
    case "$branch" in
    main | master) ;;
    *) return 0 ;;
    esac

    for name in "${CORE_ANALYSIS_NAMES[@]}"; do
        file="$root/$CORE_ANALYSIS_DIR/$name-analysis.md"
        if [[ ! -f "$file" ]]; then
            missing_names+=("$name")
        elif is_stale "$root" "$file" "$head"; then
            stale_names+=("$name")
        fi
    done

    if ((${#missing_names[@]} == ${#CORE_ANALYSIS_NAMES[@]})); then
        echo "💡 No core analyses in $CORE_ANALYSIS_DIR/ yet. Mention this once in your first reply only if the user's question would benefit. Do not generate them."
    elif ((${#stale_names[@]} > 0)); then
        local msg stale_list
        stale_list="$(join_names "${stale_names[@]}")"
        msg="🔍 ${#stale_names[@]} of ${#CORE_ANALYSIS_NAMES[@]} core analyses in $CORE_ANALYSIS_DIR/ are stale: $stale_list. "
        if ((${#missing_names[@]} > 0)); then
            msg+="Also missing: $(join_names "${missing_names[@]}"). "
        fi
        msg+="In your first reply, before answering anything else, tell the user this and offer to refresh the stale files: the matching <name>-analysis.md prompt from ~/.ai-dotfiles/etc/ai/prompts/ for one file, or run-core-analyses.md with those file names in a background subagent for two or more. Do not regenerate without their go-ahead."
        echo "$msg"
    elif ((${#missing_names[@]} > 0)); then
        echo "💡 Core analyses in $CORE_ANALYSIS_DIR/ are missing: $(join_names "${missing_names[@]}"). Mention this once in your first reply only if the user's question would benefit. Do not generate them."
    fi
}

main "$@"
exit 0
