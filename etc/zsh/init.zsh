#!/bin/zsh
#
# Zsh integration for ai-dotfiles: the ai-prompt function, its completion, and the
# engram data directory for the CLI and Codex. Source from an interactive zsh config
# before compinit runs.
#

() {
    local root=${${(%):-%x}:A:h:h:h}

    fpath=("$root/etc/zsh/completions" $fpath)
    source "$root/scripts/ai-prompt.sh"
}

# Matches the MCP server configs; the engram CLI otherwise defaults to ~/.engram.
export ENGRAM_DATA_DIR="${ENGRAM_DATA_DIR:-$HOME/.config/engram}"
