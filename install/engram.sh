#!/bin/bash

# ---------------------------------------------------------------
# Engram Configuration
# Installs the engram binary (persistent memory for AI agents) from its
# Homebrew tap, then creates its data directory. Self-contained: does not
# assume a parent dotfiles installer tapped/installed engram first.
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Configuring Engram"

# engram lives in a third-party tap, not homebrew-core — tap before installing.
if is-executable brew; then
    tap_if_needed "gentleman-programming/tap"
    install_if_needed "engram" "formula"
else
    log_warning "brew not found — cannot install engram"
fi

if ! is-executable engram; then
    log_warning "engram not found on PATH — skipping configuration"
    return
fi

mkdir -p "$HOME/.config/engram"

log_info "Engram installed: $(engram version)"
