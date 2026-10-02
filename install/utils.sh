#!/bin/bash

# Common utility functions for ai-dotfiles install scripts.
#
# Trimmed from the dotfiles install/utils.sh: this standalone AI repo keeps only
# the helpers its six install scripts actually use (logging, section headers, and
# the Homebrew install-if-needed path). The work/personal-computer split and the
# ~/.extra machine-config apparatus are deliberately NOT carried over — they are a
# dotfiles concept, and no AI install script passes the personal/work argument.

# --- Logging helpers (LOG_LEVEL: debug, info, error, none) ---
LOG_LEVEL="${AI_DOTFILES_LOG_LEVEL:-info}"

log_debug() {
    if [[ "${LOG_LEVEL}" == "debug" ]]; then
        echo -e "\033[0;37m[DEBUG] $*\033[0m"
    fi
}

log_info() {
    if [[ "${LOG_LEVEL}" == "debug" || "${LOG_LEVEL}" == "info" ]]; then
        echo -e "\033[0;34m[INFO] $*\033[0m"
    fi
}

log_warning() {
    if [[ "${LOG_LEVEL}" != "error" && "${LOG_LEVEL}" != "none" ]]; then
        echo -e "\033[0;33m[WARNING] $*\033[0m" >&2
    fi
}

log_error() {
    if [[ "${LOG_LEVEL}" != "none" ]]; then
        echo -e "\033[0;31m[ERROR] $*\033[0m" >&2
    fi
}

print_section_header() {
    if [[ "${LOG_LEVEL}" != "none" ]]; then
        echo "**********************************************************************"
        echo -e "\033[1;36m[SECTION] $1\033[0m"
        echo "**********************************************************************"
    fi
}

# --- Homebrew cache + install-if-needed ---
BREW_INSTALLED_FORMULAE=""
BREW_INSTALLED_CASKS=""
BREW_OUTDATED_FORMULAE=""
BREW_OUTDATED_CASKS=""
BREW_TAPS=""
CACHE_DIR="$HOME/.cache/ai-dotfiles"
CACHE_FILE="$CACHE_DIR/brew_cache"
CACHE_TTL=300 # 5 minutes

init_brew_cache() {
    mkdir -p "$CACHE_DIR"

    # Reuse a fresh on-disk cache to avoid repeated slow brew list/outdated calls.
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_mtime
        cache_mtime=$(gstat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        local cache_age
        cache_age=$(($(date +%s) - cache_mtime))
        if [[ $cache_age -lt $CACHE_TTL ]]; then
            # shellcheck source=/dev/null
            source "$CACHE_FILE"
            echo "Using cached brew data"
            return
        fi
    fi

    echo "Refreshing brew cache..."
    BREW_INSTALLED_FORMULAE=$(brew list --formula 2>/dev/null || echo "")
    BREW_INSTALLED_CASKS=$(brew list --cask 2>/dev/null || echo "")
    BREW_OUTDATED_FORMULAE=$(brew outdated --formula 2>/dev/null || echo "")
    BREW_OUTDATED_CASKS=$(brew outdated --cask 2>/dev/null || echo "")
    BREW_TAPS=$(brew tap 2>/dev/null || echo "")

    if [[ -z "$BREW_INSTALLED_FORMULAE" && -z "$BREW_INSTALLED_CASKS" ]]; then
        echo "Warning: Failed to initialize brew cache"
        return 1
    fi

    cat >"$CACHE_FILE" <<EOF
BREW_INSTALLED_FORMULAE="$BREW_INSTALLED_FORMULAE"
BREW_INSTALLED_CASKS="$BREW_INSTALLED_CASKS"
BREW_OUTDATED_FORMULAE="$BREW_OUTDATED_FORMULAE"
BREW_OUTDATED_CASKS="$BREW_OUTDATED_CASKS"
BREW_TAPS="$BREW_TAPS"
EOF
    echo "Cache initialized and saved"
}

refresh_brew_cache() {
    rm -f "$CACHE_FILE"
    init_brew_cache
}

is_package_installed() {
    local package=$1
    local package_type=${2:-formula}

    if [[ "$package_type" == "formula" ]]; then
        echo "$BREW_INSTALLED_FORMULAE" | grep -q "^$package\$"
    else
        echo "$BREW_INSTALLED_CASKS" | grep -q "^$package\$"
    fi
}

is_package_outdated() {
    local package=$1
    local package_type=${2:-formula}

    if [[ "$package_type" == "formula" ]]; then
        echo "$BREW_OUTDATED_FORMULAE" | grep -q "^$package\$"
    else
        echo "$BREW_OUTDATED_CASKS" | grep -q "^$package\$"
    fi
}

# Install a Homebrew formula/cask if missing, upgrade it if outdated, else no-op.
# Usage: install_if_needed <package> [formula|cask]
install_if_needed() {
    local package=$1
    local package_type=${2:-formula}

    init_brew_cache

    if ! is_package_installed "$package" "$package_type"; then
        echo "Installing $package ($package_type)..."
        if [[ "$package_type" == "cask" ]]; then
            brew install --cask "$package"
        else
            brew install --formula "$package"
        fi
        refresh_brew_cache
    elif is_package_outdated "$package" "$package_type"; then
        echo "Updating $package ($package_type)..."
        if [[ "$package_type" == "cask" ]]; then
            brew upgrade --cask "$package"
        else
            brew upgrade --formula "$package"
        fi
        refresh_brew_cache
    else
        echo -e "\033[32m✓ $package is already installed and up to date\033[0m"
    fi
}

# Add a Homebrew tap if not already tapped. Needed for formulae/casks that live
# in a third-party tap rather than homebrew-core (e.g. engram).
# Usage: tap_if_needed <user/tap>
tap_if_needed() {
    local tap=$1

    init_brew_cache

    if ! echo "$BREW_TAPS" | grep -q "^$tap\$"; then
        echo "Tapping $tap..."
        brew tap "$tap"
        refresh_brew_cache
    else
        echo "Tap $tap already exists"
    fi
}
