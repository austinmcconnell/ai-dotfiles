#!/bin/bash

# ---------------------------------------------------------------
# Amazon Q Installation Script
# This script:
# 1. Installs Amazon Q via Homebrew
# 2. Creates necessary configuration directories
# 3. Links configuration files from the dotfiles repository
# 4. Installs Amazon Q integrations (like SSH)
# ---------------------------------------------------------------

set -euo pipefail

# Source the utilities script for helper functions
source "$DOTFILES_DIR/install/utils.sh"

# Check if an Amazon Q integration is installed
is_integration_installed() {
    local integration_name=$1
    q integrations status "$integration_name" | grep -q "Installed"
}

# Install an Amazon Q integration if it's not already installed
install_integration_if_needed() {
    local integration_name=$1

    if is_integration_installed "$integration_name"; then
        echo -e "\033[32m✓ ${integration_name} integration is already installed\033[0m"
    else
        echo "Installing ${integration_name} integration..."
        q integrations install "$integration_name"
    fi
}

print_header "Installing Amazon Q"

# Initialize Homebrew cache
init_brew_cache

# Install Amazon Q using Homebrew
install_if_needed "amazon-q" "cask"

# Define Amazon Q configuration directories
AMAZON_Q_APPLICATION_SUPPORT_DIR="$HOME/Library/Application Support/amazon-q"
AMAZON_Q_CONFIG_DIR="$HOME/.aws/amazonq"
AMAZON_Q_DEFAULT_PROFILE_DIR="$AMAZON_Q_CONFIG_DIR/profiles/default"
AMAZON_Q_CLI_AGENTS_DIR="$AMAZON_Q_CONFIG_DIR/cli-agents"

# Create necessary directories
mkdir -p "$AMAZON_Q_APPLICATION_SUPPORT_DIR"
mkdir -p "$AMAZON_Q_CONFIG_DIR"
mkdir -p "$AMAZON_Q_DEFAULT_PROFILE_DIR"
mkdir -p "$AMAZON_Q_CLI_AGENTS_DIR"
mkdir -p "$DOTFILES_DIR/etc/ai-prompts"

# Link configuration files from dotfiles repository to appropriate locations
ln -sfv "$DOTFILES_DIR/etc/amazon-q/settings.json" "$AMAZON_Q_APPLICATION_SUPPORT_DIR"
ln -sfv "$DOTFILES_DIR/etc/amazon-q/global_context.json" "$AMAZON_Q_CONFIG_DIR"

# Link all existing profile configurations from dotfiles
if [ -d "$DOTFILES_DIR/etc/amazon-q/profiles" ]; then
    for profile_dir in "$DOTFILES_DIR/etc/amazon-q/profiles"/*; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            target_profile_dir="$AMAZON_Q_CONFIG_DIR/profiles/$profile_name"

            # Create target directory if it doesn't exist
            mkdir -p "$target_profile_dir"

            # Link context.json if it exists in dotfiles
            if [ -f "$profile_dir/context.json" ]; then
                ln -sfv "$profile_dir/context.json" "$target_profile_dir/context.json"
                echo "✓ Linked profile: $profile_name"
            fi
        fi
    done
else
    echo "No profiles directory found in dotfiles"
fi

# Link CLI agents from dotfiles repository
if [ -d "$DOTFILES_DIR/etc/amazon-q/cli-agents" ]; then
    for agent_file in "$DOTFILES_DIR/etc/amazon-q/cli-agents"/*.json; do
        if [ -f "$agent_file" ]; then
            agent_name=$(basename "$agent_file")
            ln -sfv "$agent_file" "$AMAZON_Q_CLI_AGENTS_DIR/$agent_name"
            echo "✓ Linked CLI agent: $agent_name"
        fi
    done
else
    echo "No CLI agents directory found in dotfiles"
fi

# Install Amazon Q integrations if the CLI is available
if is-executable q; then
    print_header "Installing Amazon Q integrations"
    install_integration_if_needed "ssh"
else
    echo "Amazon Q CLI not found. Skipping integrations installation."
fi

# Install MCP servers if npm is available
if is-executable npm; then
    print_header "Installing Amazon Q MCP servers"

    # List of Node.js MCP servers to install
    MCP_SERVERS=(
        "@modelcontextprotocol/server-filesystem"
        "@modelcontextprotocol/server-sequential-thinking"
        "enhanced-postgres-mcp-server"
        "@aashari/mcp-server-atlassian-jira"
    )

    # Install each MCP server
    for server in "${MCP_SERVERS[@]}"; do
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

# Install Python MCP servers if pip is available
if is-executable pip; then
    print_header "Installing Python MCP servers"

    # List of Python MCP servers to install
    PYTHON_MCP_SERVERS=(
        "mcp-server-git"
        "mcp-server-time"
        "mcp-server-fetch"
    )

    # Install each Python MCP server
    for server in "${PYTHON_MCP_SERVERS[@]}"; do
        echo "Installing $server..."
        if pip show "$server" >/dev/null 2>&1; then
            echo "✓ $server is already installed"
        else
            pip install "$server"
            echo "✓ $server installed successfully"
        fi
    done

    echo "✅ All Python MCP servers installed successfully"
else
    echo "pip not found. Skipping Python MCP server installation."
fi

# Build official GitHub MCP Server from source if Go is available
if is-executable go; then
    print_header "Building official GitHub MCP Server from source"

    GITHUB_MCP_REPO_DIR="$HOME/.repositories/github-mcp-server"
    GITHUB_MCP_BINARY="$HOME/.local/bin/github-mcp-server"

    # Create directories
    mkdir -p "$HOME/.repositories"
    mkdir -p "$HOME/.local/bin"

    # Clone or update the repository
    if [ -d "$GITHUB_MCP_REPO_DIR" ]; then
        echo "Updating existing GitHub MCP Server repository..."
        cd "$GITHUB_MCP_REPO_DIR"
        git pull origin main
    else
        echo "Cloning GitHub MCP Server repository..."
        git clone https://github.com/github/github-mcp-server.git "$GITHUB_MCP_REPO_DIR"
        cd "$GITHUB_MCP_REPO_DIR"
    fi

    # Build the binary with proper version information
    echo "Building GitHub MCP Server binary..."
    VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if go build -ldflags "-s -w -X main.version=$VERSION -X main.commit=$COMMIT -X main.date=$DATE" -o "$GITHUB_MCP_BINARY" ./cmd/github-mcp-server; then
        echo "✅ GitHub MCP Server built successfully at: $GITHUB_MCP_BINARY"

        # Make sure it's executable
        chmod +x "$GITHUB_MCP_BINARY"

        # Test the binary
        if "$GITHUB_MCP_BINARY" --help >/dev/null 2>&1; then
            echo "✅ GitHub MCP Server binary is working correctly"
        else
            echo "⚠️  GitHub MCP Server binary built but may have issues"
        fi
    else
        echo "❌ Failed to build GitHub MCP Server"
        echo "   You may need to build it manually:"
        echo "   cd $GITHUB_MCP_REPO_DIR"
        echo "   VERSION=\$(git describe --tags --always --dirty 2>/dev/null || echo \"dev\")"
        echo "   COMMIT=\$(git rev-parse --short HEAD 2>/dev/null || echo \"unknown\")"
        echo "   DATE=\$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")"
        echo "   go build -ldflags \"-s -w -X main.version=\$VERSION -X main.commit=\$COMMIT -X main.date=\$DATE\" -o $GITHUB_MCP_BINARY ./cmd/github-mcp-server"
    fi
else
    echo "Go not found. Skipping GitHub MCP Server build."
    echo "To use the GitHub agent, install Go and run this script again, or use Docker:"
    echo "   docker pull ghcr.io/github/github-mcp-server"
fi
