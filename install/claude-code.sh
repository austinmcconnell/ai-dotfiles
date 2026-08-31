#!/bin/bash

# ---------------------------------------------------------------
# Claude Code Installation Script
# This script:
# 1. Installs Claude Code via Homebrew
# 2. Symlinks settings from dotfiles to ~/.claude/
# 3. Bootstraps MCP server configuration in ~/.claude.json
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Installing Claude Code"

# Initialize Homebrew cache
init_brew_cache

# Install Claude Code via Homebrew
install_if_needed "claude-code" "cask"

print_section_header "Setting up Claude Code configuration"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_JSON="$HOME/.claude.json"

mkdir -p "$CLAUDE_DIR"

# Link settings (permissions)
ln -sfv "$AI_DOTFILES_DIR/etc/claude-code/settings.json" "$CLAUDE_DIR/settings.json"

# Link subagents directory (jira, datadog personas — usable via `claude --agent <name>`).
# Note: Claude Code does not detect a newly created agents/ dir mid-session; a restart
# is required the first time this symlink is added.
ln -sfn "$AI_DOTFILES_DIR/etc/claude-code/agents" "$CLAUDE_DIR/agents"
echo "✓ Linked subagents to ~/.claude/agents"

# Bootstrap MCP servers in ~/.claude.json (user scope).
#
# Idempotent: the desired server set lives in a heredoc and is merged into any
# existing ~/.claude.json with jq. Existing servers are preserved; only missing
# servers are added (existing values win on key collision, so local edits and
# session state are never clobbered). A brand-new file is seeded with the same
# desired set. This replaces the old `if [ ! -f ]` guard, which silently skipped
# existing installs and left new servers (e.g. engram) unlanded.
read -r -d '' DESIRED_MCP_SERVERS <<'EOF' || true
{
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
EOF

if ! command -v jq >/dev/null 2>&1; then
    echo "⚠ jq not found; skipping ~/.claude.json MCP bootstrap"
elif [ -f "$CLAUDE_JSON" ]; then
    # Merge desired servers into existing config; existing servers win on
    # collision (* the existing object is applied last in the multiply).
    tmp_claude_json="$(mktemp)"
    if jq --argjson desired "$DESIRED_MCP_SERVERS" \
        '.mcpServers = ($desired + (.mcpServers // {}))' \
        "$CLAUDE_JSON" >"$tmp_claude_json"; then
        mv "$tmp_claude_json" "$CLAUDE_JSON"
        echo "✓ Merged MCP servers into ~/.claude.json (existing servers preserved)"
    else
        rm -f "$tmp_claude_json"
        echo "⚠ Failed to merge MCP servers into ~/.claude.json; leaving it unchanged"
    fi
else
    jq -n --argjson desired "$DESIRED_MCP_SERVERS" '{mcpServers: $desired}' \
        >"$CLAUDE_JSON"
    echo "✓ Created ~/.claude.json with MCP servers"
fi

echo "✅ Claude Code configuration complete"
