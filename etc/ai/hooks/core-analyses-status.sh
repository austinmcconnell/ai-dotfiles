#!/bin/bash
set -euo pipefail

# Report the state of a repo's core analyses in analysis/. Called from the Claude
# SessionStart hook; output is injected into session context so the agent can
# mention it. Prints nothing for directories outside $PROJECTS_ROOT or outside a
# git work tree.
#
# Emits at most one line:
#   - analysis/ absent: a generation candidate.
#   - analysis/ present with one or more core files stale or missing: the count.
#
# A core file is stale when it is missing, records no HEAD commit, records a commit
# that is not an ancestor of HEAD (e.g. after a rebase), or sits more than
# CORE_ANALYSIS_MAX_COMMITS_BEHIND commits behind HEAD.

readonly CORE_ANALYSIS_DIR="analysis"
readonly CORE_ANALYSIS_MAX_COMMITS_BEHIND=20
readonly CORE_ANALYSIS_NAMES=(project architecture schema integration)
readonly PROJECTS_ROOT="${CORE_ANALYSIS_PROJECTS_ROOT:-$HOME/projects}"

is_stale() {
    local root="$1" file="$2" head="$3" recorded behind
    [[ -f "$file" ]] || return 0
    recorded="$(sed -n 's/^\*\*HEAD Commit:\*\* *\([0-9a-f]*\).*/\1/p' "$file" | head -1)"
    [[ -n "$recorded" ]] || return 0
    git -C "$root" merge-base --is-ancestor "$recorded" "$head" 2>/dev/null || return 0
    behind="$(git -C "$root" rev-list --count "$recorded..$head")"
    ((behind > CORE_ANALYSIS_MAX_COMMITS_BEHIND))
}

main() {
    local dir="${1:-$PWD}" root head stale=0 name

    dir="$(cd "$dir" && pwd -P)" || return 0
    case "$dir" in
    "$PROJECTS_ROOT"/*) ;;
    *) return 0 ;;
    esac

    root="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 0
    head="$(git -C "$root" rev-parse --verify -q HEAD)" || return 0

    if [[ ! -d "$root/$CORE_ANALYSIS_DIR" ]]; then
        echo "💡 No core analyses in $CORE_ANALYSIS_DIR/ yet. Mention this once in your first reply only if the user's question would benefit. Do not generate them."
        return 0
    fi

    for name in "${CORE_ANALYSIS_NAMES[@]}"; do
        if is_stale "$root" "$root/$CORE_ANALYSIS_DIR/$name-analysis.md" "$head"; then
            stale=$((stale + 1))
        fi
    done

    if ((stale > 0)); then
        echo "🔍 $stale of ${#CORE_ANALYSIS_NAMES[@]} core analyses in $CORE_ANALYSIS_DIR/ are stale or missing. In your first reply, before answering anything else, tell the user this count and offer to refresh them: one prompt from ~/.ai-dotfiles/etc/ai/prompts/ for a single file, or run-core-analyses.md in a background subagent for two or more. Do not regenerate without their go-ahead."
    fi
}

main "$@"
exit 0
