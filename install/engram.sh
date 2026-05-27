#!/bin/bash

# ---------------------------------------------------------------
# Engram Configuration
# Creates data directory for engram (persistent memory for AI agents)
# Binary installation is handled by install/brew.sh
# ---------------------------------------------------------------

set -euo pipefail

source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Configuring Engram"

if ! is-executable engram; then
    log_warning "engram not found on PATH — skipping configuration"
    return
fi

mkdir -p "$HOME/.config/engram"

log_info "Engram installed: $(engram version)"
