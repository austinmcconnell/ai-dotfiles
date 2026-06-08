#!/bin/bash

# ---------------------------------------------------------------
# Kiro CLI (formerly Amazon Q) Installation Script
# This script:
# 1. Installs Kiro CLI via Homebrew
# 2. Creates necessary configuration directories
# 3. Links configuration files from the dotfiles repository
# ---------------------------------------------------------------

set -euo pipefail

# Source the utilities script for helper functions
source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Installing Kiro CLI"

# Initialize Homebrew cache
init_brew_cache

# Install Kiro CLI using Homebrew
install_if_needed "kiro-cli" "cask"

# Define Kiro CLI configuration directories
KIRO_SETTINGS_DIR="$HOME/.kiro/settings"
KIRO_AGENTS_DIR="$HOME/.kiro/agents"
KIRO_LOGS_DIR="$HOME/.kiro/logs"

# Create necessary directories
mkdir -p "$KIRO_SETTINGS_DIR"
mkdir -p "$KIRO_AGENTS_DIR"
mkdir -p "$KIRO_LOGS_DIR"
mkdir -p "$DOTFILES_DIR/etc/ai/prompts"

# Create audit log files with proper permissions
touch "$KIRO_LOGS_DIR/aws-audit.jsonl"
touch "$KIRO_LOGS_DIR/kubectl-audit.jsonl"
chmod 600 "$KIRO_LOGS_DIR"/*.jsonl

# Link settings from dotfiles
ln -sfv "$DOTFILES_DIR/etc/kiro-cli/settings/cli.json" "$KIRO_SETTINGS_DIR/cli.json"
ln -sfv "$DOTFILES_DIR/etc/kiro-cli/settings/mcp.json" "$KIRO_SETTINGS_DIR/mcp.json"

# Link CLI agents from dotfiles repository
KIRO_AGENTS_DIR="$HOME/.kiro/agents"
mkdir -p "$KIRO_AGENTS_DIR"

if [ -d "$DOTFILES_DIR/etc/kiro-cli/cli-agents" ]; then
    for agent_file in "$DOTFILES_DIR/etc/kiro-cli/cli-agents"/*.{json,md}; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file")
            ln -sfv "$agent_file" "$KIRO_AGENTS_DIR/$agent_name"
            echo "✓ Linked CLI agent: $agent_name"
        fi
    done
else
    echo "No CLI agents directory found in dotfiles"
fi

# Set default agent to use custom 'default' agent instead of built-in kiro_default
if is-executable kiro-cli; then
    echo "Setting default agent to 'default'..."
    kiro-cli agent set-default --name default 2>/dev/null || echo "⚠️  Could not set default agent (may need to run manually)"
fi

# Skills are linked by install/ai-tools.sh (centralized for all AI tools)

# NOTE: Do NOT install the "ssh" integration — it injects itself into ~/.ssh/config
# and runs `kiro-cli internal generate-ssh` on every SSH connection. My SSH config
# already handles keys, ControlMaster, and host aliases independently.

# Install MCP servers if npm is available
source "$DOTFILES_DIR/etc/kiro-cli/mcp-servers.conf"

if is-executable npm; then
    print_section_header "Installing Kiro CLI MCP servers"

    for server in "${NODE_MCP_SERVERS[@]}"; do
        echo "Installing $server..."
        if npm list -g "$server" >/dev/null 2>&1; then
            echo "✓ $server is already installed"
        else
            npm install -g "$server"
            echo "✓ $server installed successfully"
        fi
    done

    echo "✅ All Node.js MCP servers installed successfully"
else
    echo "npm not found. Skipping Node.js MCP server installation."
fi

# Configure git hooks for the research repo (KB staleness detection)
# Uses git 2.54+ config-based hooks — coexists with pre-commit framework
# without needing core.hooksPath (which overrides .git/hooks/ entirely).
RESEARCH_REPO="$HOME/projects/austinmcconnell/_research_"
if [ -d "$RESEARCH_REPO/.git" ]; then
    HOOK_CMD="$HOME/.dotfiles/etc/kiro-cli/hooks/kb-staleness.sh"
    git -C "$RESEARCH_REPO" config unset --all hook.kb-staleness.event 2>/dev/null || true
    git -C "$RESEARCH_REPO" config set hook.kb-staleness.command "$HOOK_CMD"
    git -C "$RESEARCH_REPO" config set hook.kb-staleness.event post-commit
    git -C "$RESEARCH_REPO" config set --append hook.kb-staleness.event post-merge
    git -C "$RESEARCH_REPO" config set --append hook.kb-staleness.event post-rewrite
    echo "✓ Configured KB staleness hooks for research repo"
fi

# Clone reference repositories for ansible agent knowledge bases
SOURCES_DIR="$HOME/sources/geerlingguy"
GEERLING_REPOS=(
    "mac-dev-playbook"
    "pi-cluster"
    "ansible-for-devops"
    "ansible-role-docker"
    "ansible-role-security"
    "ansible-role-pip"
    "ansible-role-ntp"
)

mkdir -p "$SOURCES_DIR"
for repo in "${GEERLING_REPOS[@]}"; do
    if [ ! -d "$SOURCES_DIR/$repo" ]; then
        echo "Cloning $repo..."
        git clone "https://github.com/geerlingguy/$repo.git" "$SOURCES_DIR/$repo" || echo "⚠️  Failed to clone $repo (non-fatal)"
    else
        echo "✓ $repo already exists"
    fi
done
