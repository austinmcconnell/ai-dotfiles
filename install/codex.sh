#!/bin/bash

# ---------------------------------------------------------------
# Codex CLI Configuration
# Copies Codex config defaults to ~/.codex/ without overwriting local state
# ---------------------------------------------------------------

set -euo pipefail

source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Setting up Codex configuration"

CODEX_DIR="$HOME/.codex"
CODEX_CONFIG="$CODEX_DIR/config.toml"
DOTFILES_CODEX_CONFIG="$DOTFILES_DIR/etc/codex/config.toml"

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
