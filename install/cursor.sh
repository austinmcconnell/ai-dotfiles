#!/bin/bash

# ---------------------------------------------------------------
# Cursor CLI Configuration
# Symlinks Cursor config files from dotfiles to ~/.cursor/
# ---------------------------------------------------------------

set -euo pipefail

source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Setting up Cursor configuration"

CURSOR_DIR="$HOME/.cursor"

mkdir -p "$CURSOR_DIR"

# Link global config files
ln -sfv "$DOTFILES_DIR/etc/cursor/cli-config.json" "$CURSOR_DIR/cli-config.json"
ln -sfv "$DOTFILES_DIR/etc/cursor/mcp.json" "$CURSOR_DIR/mcp.json"

echo "✅ Cursor configuration complete"
