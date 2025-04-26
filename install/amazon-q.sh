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

# Initialize Homebrew cache if needed
if [[ "$CACHE_INITIALIZED" != "true" ]]; then
    init_brew_cache
fi

# Install Amazon Q using Homebrew
install_if_needed "amazon-q" "cask"

# Define Amazon Q configuration directories
AMAZON_Q_APPLICATION_SUPPORT_DIR="$HOME/Library/Application Support/amazon-q"
AMAZON_Q_CONFIG_DIR="$HOME/.aws/amazonq"
AMAZON_Q_DEFAULT_PROFILE_DIR="$AMAZON_Q_CONFIG_DIR/profiles/default"

# Create necessary directories
mkdir -p "$AMAZON_Q_APPLICATION_SUPPORT_DIR"
mkdir -p "$AMAZON_Q_CONFIG_DIR"
mkdir -p "$AMAZON_Q_DEFAULT_PROFILE_DIR"

# Link configuration files from dotfiles repository to appropriate locations
ln -sfv "$DOTFILES_DIR/etc/amazon-q/settings.json" "$AMAZON_Q_APPLICATION_SUPPORT_DIR"
ln -sfv "$DOTFILES_DIR/etc/amazon-q/global_context.json" "$AMAZON_Q_CONFIG_DIR"
ln -sfv "$DOTFILES_DIR/etc/amazon-q/profiles/default/context.json" "$AMAZON_Q_DEFAULT_PROFILE_DIR"

# Install Amazon Q integrations if the CLI is available
if is-executable q; then
    print_header "Installing Amazon Q integrations"
    install_integration_if_needed "ssh"
else
    echo "Amazon Q CLI not found. Skipping integrations installation."
fi
