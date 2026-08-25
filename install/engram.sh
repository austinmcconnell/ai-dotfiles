#!/bin/bash

# ---------------------------------------------------------------
# Engram Configuration
# Creates data directory for engram (persistent memory for AI agents)
# Binary installation is handled by install/brew.sh
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Configuring Engram"

if ! is-executable engram; then
    log_warning "engram not found on PATH — skipping configuration"
    return
fi

mkdir -p "$HOME/.config/engram"

log_info "Engram installed: $(engram version)"
