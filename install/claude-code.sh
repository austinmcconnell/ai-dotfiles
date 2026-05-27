#!/bin/bash

# ---------------------------------------------------------------
# Claude Code Configuration
# Symlinks Claude Code settings from dotfiles to ~/.claude/
# and bootstraps MCP server configuration in ~/.claude.json
# ---------------------------------------------------------------

set -euo pipefail

source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Setting up Claude Code configuration"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"

mkdir -p "$CLAUDE_DIR"

# Link settings (permissions)
ln -sfv "$DOTFILES_DIR/etc/claude-code/settings.json" "$CLAUDE_DIR/settings.json"

# Bootstrap MCP servers in ~/.claude.json (user scope) if not already present
if [ ! -f "$CLAUDE_JSON" ]; then
    cat >"$CLAUDE_JSON" <<'EOF'
{
  "mcpServers": {
    "engram": {
      "type": "stdio",
      "command": "engram",
      "args": ["mcp"],
      "env": {
        "ENGRAM_DATA_DIR": "${HOME}/.config/engram"
      }
    },
    "jira": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@aashari/mcp-server-atlassian-jira@3.3.0"],
      "env": {
        "ATLASSIAN_SITE_NAME": "${ATLASSIAN_SITE_NAME}",
        "ATLASSIAN_USER_EMAIL": "${ATLASSIAN_USER_EMAIL}",
        "ATLASSIAN_API_TOKEN": "${ATLASSIAN_API_TOKEN}"
      }
    }
  }
}
EOF
    echo "✓ Created ~/.claude.json with MCP servers"
else
    echo "$HOME/.claude.json already exists; leaving MCP config unchanged"
fi

echo "✅ Claude Code configuration complete"
