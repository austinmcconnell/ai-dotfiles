#!/usr/bin/env bash

# ---------------------------------------------------------------
# Main installation script for ai-dotfiles
#
# Standalone orchestrator for the AI tooling surface (kiro-cli, engram,
# shared skills/steering, codex, cursor, claude-code). Works two ways:
#   1. Standalone  — run ./install.sh in a clone of this repo.
#   2. Colocated   — sourced by the dotfiles install.sh, which sets
#                    AI_DOTFILES_DIR to this repo's root beforehand.
# ---------------------------------------------------------------

set -euo pipefail

# Resolve this repo's root. When sourced from a parent installer that already
# exported AI_DOTFILES_DIR, honor it; otherwise derive it from this script.
export AI_DOTFILES_DIR
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Make bin/ helpers (is-executable, engram-hygiene, trace-search) resolvable.
PATH="$AI_DOTFILES_DIR/bin:$PATH"

source "$AI_DOTFILES_DIR/install/utils.sh"
source "$AI_DOTFILES_DIR/install/enabled-agents.sh"

# Source install/<agent>.sh only when the agent is in ENABLED_AGENTS. Disabling
# an agent just stops future installs; nothing already installed is removed.
install_agent() {
    if agent_enabled "$1"; then
        # shellcheck source=/dev/null
        . "$AI_DOTFILES_DIR/install/$1.sh"
    else
        log_info "Skipping $1 (not in ENABLED_AGENTS)"
    fi
}

# Self-update: only when run standalone from a git clone with a remote. Guarded
# so a colocated/sourced run (dotfiles already pulled) or a non-git copy is a
# no-op rather than an error.
self_update_eligible() {
    [[ -z "${AI_DOTFILES_SKIP_SELF_UPDATE:-}" ]] &&
        git -C "$AI_DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 &&
        git -C "$AI_DOTFILES_DIR" remote get-url origin >/dev/null 2>&1
}

if self_update_eligible; then
    log_info "Updating ai-dotfiles from origin..."
    git -C "$AI_DOTFILES_DIR" pull --ff-only origin main || log_warning "Self-update skipped (pull failed)"
fi

# Cache dir used by the brew helpers in utils.sh.
mkdir -p "$HOME/.cache/ai-dotfiles"

# Install and configure the AI tooling, in dependency order:
#   kiro-cli    — installs the kiro-cli cask + agents/settings/MCP servers
#   engram      — configures persistent memory (binary via brew); always runs
#   ai-tools    — distributes skills + generates steering adapters to each agent
#   codex       — Codex CLI config
#   cursor      — Cursor CLI config
#   claude-code — Claude Code cask + config
# The per-agent scripts run only when enabled in install/enabled-agents.sh.
install_agent kiro-cli
. "$AI_DOTFILES_DIR/install/engram.sh"
. "$AI_DOTFILES_DIR/install/ai-tools.sh"
install_agent codex
install_agent cursor
install_agent claude-code

print_section_header "ai-dotfiles install complete"
