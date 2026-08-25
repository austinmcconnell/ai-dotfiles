#!/bin/bash

# ---------------------------------------------------------------
# Codex CLI Configuration
# Copies Codex config defaults to ~/.codex/ without overwriting local state
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Setting up Codex configuration"

install_if_needed "codex" "cask"

CODEX_DIR="$HOME/.codex"
CODEX_CONFIG="$CODEX_DIR/config.toml"
DOTFILES_CODEX_CONFIG="$AI_DOTFILES_DIR/etc/codex/config.toml"

mkdir -p "$CODEX_DIR"

if [[ -L "$CODEX_CONFIG" && "$(readlink "$CODEX_CONFIG")" == "$DOTFILES_CODEX_CONFIG" ]]; then
    rm "$CODEX_CONFIG"
    cp -v "$DOTFILES_CODEX_CONFIG" "$CODEX_CONFIG"
elif [[ -e "$CODEX_CONFIG" || -L "$CODEX_CONFIG" ]]; then
    echo "Codex config already exists at $CODEX_CONFIG; leaving it unchanged"
else
    cp -v "$DOTFILES_CODEX_CONFIG" "$CODEX_CONFIG"
fi

echo "✅ Codex configuration complete"
