#!/bin/bash

# ---------------------------------------------------------------
# Cursor CLI Configuration
# Symlinks Cursor config files from dotfiles to ~/.cursor/
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Setting up Cursor configuration"

CURSOR_DIR="$HOME/.cursor"

mkdir -p "$CURSOR_DIR"

# Link global config files
ln -sfv "$AI_DOTFILES_DIR/etc/cursor/cli-config.json" "$CURSOR_DIR/cli-config.json"
ln -sfv "$AI_DOTFILES_DIR/etc/cursor/mcp.json" "$CURSOR_DIR/mcp.json"

echo "✅ Cursor configuration complete"
