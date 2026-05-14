#!/bin/bash

# ---------------------------------------------------------------
# Agent Skills Distribution Script
# Symlinks skills from the dotfiles repo to each AI agent's
# expected discovery path, enabling multi-agent portability.
# Also generates steering adapter files for agents that support them.
#
# Skills are already Agent Skills spec-compliant (SKILL.md with
# name/description frontmatter + references/ directories).
# This script just handles distribution to each agent's path.
# ---------------------------------------------------------------

set -euo pipefail

source "$DOTFILES_DIR/install/utils.sh"

print_section_header "Distributing Agent Skills"

SKILLS_SOURCE="$DOTFILES_DIR/etc/ai/skills"
STEERING_SOURCE="$DOTFILES_DIR/etc/ai/steering"

# ---------------------------------------------------------------
# Steering Generators
# ---------------------------------------------------------------

# Generate a single concatenated markdown file from steering docs.
# Used by: Claude Code (CLAUDE.md), Gemini CLI (GEMINI.md)
generate_single_steering() {
    local output_file="$1"
    {
        cat <<'HEADER'
# Coding Guidelines

Auto-generated from dotfiles steering docs. Do not edit directly.
Source: `~/.dotfiles/etc/ai/steering/{code,security}/`

HEADER
        for f in "$STEERING_SOURCE/code"/*.md; do
            [ -f "$f" ] || continue
            cat "$f"
            printf '\n\n'
        done
        for f in "$STEERING_SOURCE/security"/*.md; do
            [ -f "$f" ] || continue
            cat "$f"
            printf '\n\n'
        done
    } >"$output_file"
}

# Generate .mdc rule files from steering docs.
# Used by: Cursor (one .mdc per steering doc, alwaysApply: true)
generate_mdc_steering() {
    local output_dir="$1"
    local prefix="steering-"

    # Clean previously generated steering rules
    rm -f "${output_dir:?}/${prefix}"*.mdc

    for f in "$STEERING_SOURCE/code"/*.md "$STEERING_SOURCE/security"/*.md; do
        [ -f "$f" ] || continue
        local basename
        basename="$(basename "$f" .md)"
        local mdc_file="$output_dir/${prefix}${basename}.mdc"
        {
            printf -- '---\ndescription: \nglobs: \nalwaysApply: true\n---\n\n'
            cat "$f"
        } >"$mdc_file"
    done
}

# ---------------------------------------------------------------
# Agent Registry
# Each agent defines:
#   skills_path  — where the agent discovers skills
#   steering     — how the agent loads always-on instructions
#                  "none"        = relies on AGENTS.md (no adapter needed)
#                  "single:PATH" = single concatenated file
#                  "mdc:DIR"     = .mdc files with frontmatter
# ---------------------------------------------------------------
declare -A AGENT_SKILLS_PATH
declare -A AGENT_STEERING

AGENT_SKILLS_PATH[claude - code]="$HOME/.claude/skills"
AGENT_STEERING[claude - code]="single:$HOME/.claude/CLAUDE.md"

AGENT_SKILLS_PATH[codex]="$HOME/.codex/skills"
AGENT_STEERING[codex]="none"

AGENT_SKILLS_PATH[cursor]="$HOME/.cursor/skills"
AGENT_STEERING[cursor]="mdc:$HOME/.cursor/rules"

AGENT_SKILLS_PATH[gemini - cli]="$HOME/.gemini/skills"
AGENT_STEERING[gemini - cli]="single:$HOME/.gemini/GEMINI.md"

AGENT_SKILLS_PATH[github - copilot]="$HOME/.agents/skills"
AGENT_STEERING[github - copilot]="none"

AGENT_SKILLS_PATH[windsurf]="$HOME/.codeium/windsurf/skills"
AGENT_STEERING[windsurf]="none"

# ---------------------------------------------------------------
# Enable the agents you actively use. Others are defined above
# but won't be linked until added here.
# ---------------------------------------------------------------
ENABLED_AGENTS=(
    # "claude-code"
    "codex"
    "cursor"
    # "gemini-cli"
    # "github-copilot"
    # "windsurf"
)

# ---------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------
for agent in "${ENABLED_AGENTS[@]}"; do
    skills_path="${AGENT_SKILLS_PATH[$agent]}"
    steering="${AGENT_STEERING[$agent]}"

    # Symlink skills
    mkdir -p "$(dirname "$skills_path")"
    ln -sfn "$SKILLS_SOURCE" "$skills_path"
    echo "✓ Linked skills to $agent ($skills_path)"

    # Generate steering adapter
    case "$steering" in
    none) ;;
    single:*)
        output_file="${steering#single:}"
        mkdir -p "$(dirname "$output_file")"
        generate_single_steering "$output_file"
        echo "✓ Generated steering for $agent ($output_file)"
        ;;
    mdc:*)
        output_dir="${steering#mdc:}"
        mkdir -p "$output_dir"
        generate_mdc_steering "$output_dir"
        echo "✓ Generated steering for $agent ($output_dir/)"
        ;;
    esac
done

echo "✅ Agent skills distributed to ${#ENABLED_AGENTS[@]} enabled agent(s)"
