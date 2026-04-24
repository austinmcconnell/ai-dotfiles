#!/bin/bash

# ---------------------------------------------------------------
# Kiro CLI (formerly Amazon Q) Installation Script
# This script:
# 1. Installs Kiro CLI via Homebrew
# 2. Creates necessary configuration directories
# 3. Links configuration files from the dotfiles repository
# 4. Installs Kiro CLI integrations (like SSH)
# ---------------------------------------------------------------

set -euo pipefail

# Source the utilities script for helper functions
source "$DOTFILES_DIR/install/utils.sh"

# Check if a Kiro CLI integration is installed
is_integration_installed() {
    local integration_name=$1
    kiro-cli integrations status "$integration_name" | grep -q "Installed"
}

# Install a Kiro CLI integration if it's not already installed
install_integration_if_needed() {
    local integration_name=$1

    if is_integration_installed "$integration_name"; then
        echo -e "\033[32m✓ ${integration_name} integration is already installed\033[0m"
    else
        echo "Installing ${integration_name} integration..."
        kiro-cli integrations install "$integration_name"
    fi
}

print_header "Installing Kiro CLI"

# Initialize Homebrew cache
init_brew_cache

# Install Kiro CLI using Homebrew
install_if_needed "kiro-cli" "cask"

# Define Kiro CLI configuration directories
KIRO_SETTINGS_DIR="$HOME/.kiro/settings"
KIRO_AGENTS_DIR="$HOME/.kiro/agents"
KIRO_SKILLS_DIR="$HOME/.kiro/skills"
KIRO_LOGS_DIR="$HOME/.kiro/logs"

# Create necessary directories
mkdir -p "$KIRO_SETTINGS_DIR"
mkdir -p "$KIRO_AGENTS_DIR"
mkdir -p "$KIRO_SKILLS_DIR"
mkdir -p "$KIRO_LOGS_DIR"
mkdir -p "$DOTFILES_DIR/etc/ai-prompts"

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

# Link skills from dotfiles repository
KIRO_SKILLS_DIR="$HOME/.kiro/skills"
mkdir -p "$KIRO_SKILLS_DIR"

if [ -d "$DOTFILES_DIR/etc/kiro-cli/skills" ]; then
    for skill_dir in "$DOTFILES_DIR/etc/kiro-cli/skills"/*; do
        if [ -d "$skill_dir" ]; then
            skill_name=$(basename "$skill_dir")
            ln -sfnv "$skill_dir" "$KIRO_SKILLS_DIR/$skill_name"
            echo "✓ Linked skill: $skill_name"
        fi
    done
else
    echo "No skills directory found in dotfiles"
fi

# Install Kiro CLI integrations if the CLI is available
if is-executable kiro-cli; then
    print_header "Installing Kiro CLI integrations"
    install_integration_if_needed "ssh"
else
    echo "Kiro CLI not found. Skipping integrations installation."
fi

# Install MCP servers if npm is available
source "$DOTFILES_DIR/etc/kiro-cli/mcp-servers.conf"

if is-executable npm; then
    print_header "Installing Kiro CLI MCP servers"

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

# Pre-cache Python MCP servers for uvx if uv is available
if is-executable uv; then
    print_header "Pre-caching Python MCP servers for uvx"

    for server in "${PYTHON_MCP_SERVERS[@]}"; do
        echo "Pre-caching $server..."
        uvx --quiet "$server" --help >/dev/null 2>&1 && echo "✓ $server cached" || echo "⚠️  $server may need manual verification"
    done

    echo "✅ All Python MCP servers pre-cached for uvx"
else
    echo "uv not found. Skipping Python MCP server pre-caching."
    echo "Install uv (https://docs.astral.sh/uv/) for Python MCP server support."
fi

# Install GitHub MCP Server via go install if Go is available
if is-executable go; then
    print_header "Installing GitHub MCP Server"
    echo "Installing $GITHUB_MCP_SERVER_PKG..."
    if go install "$GITHUB_MCP_SERVER_PKG"; then
        echo "✅ GitHub MCP Server installed to $(go env GOPATH)/bin/"
    else
        echo "❌ Failed to install GitHub MCP Server"
    fi
else
    echo "Go not found. Skipping GitHub MCP Server installation."
fi
