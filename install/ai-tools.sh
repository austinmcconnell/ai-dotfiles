#!/bin/bash

# ---------------------------------------------------------------
# AI Tools Distribution Script
# Symlinks skills from the dotfiles repo to each AI agent's
# expected discovery path, enabling multi-agent portability.
# Also generates steering adapter files for agents that support them.
#
# Skills are already Agent Skills spec-compliant (SKILL.md with
# name/description frontmatter + references/ directories).
# This script just handles distribution to each agent's path.
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

# ---------------------------------------------------------------
# Enable the agents you actively use. Others are defined in the
# agent_config registry below but won't be linked until added here.
# ---------------------------------------------------------------
ENABLED_AGENTS=(
    "claude-code"
    "codex"
    "cursor"
    "kiro-cli"
    # "gemini-cli"
    # "github-copilot"
    # "windsurf"
)

# ---------------------------------------------------------------

print_section_header "Distributing Agent Skills"

SKILLS_SOURCE="$AI_DOTFILES_DIR/etc/ai/skills"
STEERING_SOURCE="$AI_DOTFILES_DIR/etc/ai/steering"

# Steering domains shipped to every session by the steering-file generators
# (Gemini GEMINI.md, Cursor .mdc, Claude rules/). These are universal — they
# apply to any work in any session. Domain-specific steering (ansible,
# documentation, datadog, scrum) is loaded per-persona via @-imports in the
# relevant Claude subagent body, so it doesn't pollute unrelated sessions.
# Single source of truth: every generator loops this array, so adding a
# universal domain here updates all three tools at once.
UNIVERSAL_STEERING_DOMAINS=(code github security)

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
HEADER
        # Single quotes are intentional: the backticks are literal markdown code
        # formatting, and %s pulls in $STEERING_SOURCE as a printf argument.
        # shellcheck disable=SC2016
        printf 'Source: `%s/{%s}/`\n\n' "$STEERING_SOURCE" \
            "$(
                IFS=,
                echo "${UNIVERSAL_STEERING_DOMAINS[*]}"
            )"
        for domain in "${UNIVERSAL_STEERING_DOMAINS[@]}"; do
            for f in "$STEERING_SOURCE/$domain"/*.md; do
                [ -f "$f" ] || continue
                cat "$f"
                printf '\n\n'
            done
        done
    } >"$output_file"
}

# Generate .mdc rule files from steering docs.
# Used by: Cursor (one .mdc per steering doc, alwaysApply: true)
generate_mdc_steering() {
    local output_dir="$1"
    local prefix="steering-"

    # Clean previously generated steering rules and stale symlinks
    rm -f "${output_dir:?}/${prefix}"*.mdc
    find "$output_dir" -maxdepth 1 -name "*.mdc" -type l ! -exec test -e {} \; -delete 2>/dev/null || true

    for domain in "${UNIVERSAL_STEERING_DOMAINS[@]}"; do
        for f in "$STEERING_SOURCE/$domain"/*.md; do
            [ -f "$f" ] || continue
            local basename desc content
            basename="$(basename "$f" .md)"
            # Strip any existing YAML frontmatter before extracting content
            if head -1 "$f" | grep -q '^---$'; then
                content="$(sed '1{/^---$/!q}; 1,/^---$/d' "$f")"
            else
                content="$(cat "$f")"
            fi
            desc="$(echo "$content" | grep -m1 '^# ' | sed 's/^# //')"
            # Prefix the domain so files sharing a basename across domains
            # (e.g. code/ and github/ both have skill-loading-triggers.md) don't
            # collide on a flat output name and silently overwrite each other.
            local mdc_file="$output_dir/${prefix}${domain}-${basename}.mdc"
            {
                printf -- '---\ndescription: %s\nalwaysApply: true\n---\n\n' "$desc"
                echo "$content"
            } >"$mdc_file"
        done
    done
}

# Generate individual rule files from steering docs.
# Used by: Claude Code (one .md per steering doc in ~/.claude/rules/)
# Files with paths: frontmatter get conditional loading; others load unconditionally.
generate_rules_steering() {
    local output_dir="$1"
    local claude_md="$2"

    # Clean previously generated rules
    for domain in "${UNIVERSAL_STEERING_DOMAINS[@]}"; do
        rm -rf "${output_dir:?}/${domain}"
    done

    # Copy each steering doc preserving subdirectory structure
    for domain in "${UNIVERSAL_STEERING_DOMAINS[@]}"; do
        for f in "$STEERING_SOURCE/$domain"/*.md; do
            [ -f "$f" ] || continue
            mkdir -p "$output_dir/$domain"
            cp "$f" "$output_dir/$domain/"
        done
    done

    # Write slim CLAUDE.md
    cat >"$claude_md" <<'EOF'
# Coding Guidelines

Steering rules are loaded from ~/.claude/rules/ (auto-generated from dotfiles).
EOF
    printf 'See %s/ for source files.\n\n' "$STEERING_SOURCE" >>"$claude_md"
    cat >>"$claude_md" <<'EOF'
Skills are available in ~/.claude/skills/ (symlinked from dotfiles).
EOF
}

# ---------------------------------------------------------------
# Agent Registry
# Each agent defines:
#   skills_path  — where the agent discovers skills
#   steering     — how the agent loads always-on instructions
#                  "none"        = relies on AGENTS.md (no adapter needed)
#                  "single:PATH" = single concatenated file
#                  "mdc:DIR"     = .mdc files with frontmatter
#                  "rules:DIR"   = individual .md files (Claude Code rules/)
#                  "symlink:DIR" = symlink the steering tree to DIR (kiro-cli
#                                  reads it via file://~/.kiro/steering/ URIs in
#                                  each agent's resources)
# ---------------------------------------------------------------
agent_config() {
    local agent="$1" field="$2"
    case "$agent:$field" in
    claude-code:skills_path) echo "$HOME/.claude/skills" ;;
    claude-code:steering) echo "rules:$HOME/.claude/rules:$HOME/.claude/CLAUDE.md" ;;
    codex:skills_path) echo "$HOME/.codex/skills" ;;
    codex:steering) echo "none" ;;
    cursor:skills_path) echo "$HOME/.cursor/skills" ;;
    cursor:steering) echo "mdc:$HOME/.cursor/rules" ;;
    gemini-cli:skills_path) echo "$HOME/.gemini/skills" ;;
    gemini-cli:steering) echo "single:$HOME/.gemini/GEMINI.md" ;;
    github-copilot:skills_path) echo "$HOME/.agents/skills" ;;
    github-copilot:steering) echo "none" ;;
    kiro-cli:skills_path) echo "$HOME/.kiro/skills" ;;
    kiro-cli:steering) echo "symlink:$HOME/.kiro/steering" ;;
    windsurf:skills_path) echo "$HOME/.codeium/windsurf/skills" ;;
    windsurf:steering) echo "none" ;;
    esac
}

# ---------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------
for agent in "${ENABLED_AGENTS[@]}"; do
    skills_path="$(agent_config "$agent" skills_path)"
    steering="$(agent_config "$agent" steering)"

    # Symlink skills
    mkdir -p "$(dirname "$skills_path")"
    # Remove existing real directory (e.g., left over from prior per-category symlink layout)
    if [ -d "$skills_path" ] && [ ! -L "$skills_path" ]; then
        rm -rf "$skills_path"
    fi
    ln -sfn "$SKILLS_SOURCE" "$skills_path"
    echo "✓ Linked skills to $agent ($skills_path)"

    # Generate steering adapter
    case "$steering" in
    none) ;;
    symlink:*)
        steering_link="${steering#symlink:}"
        mkdir -p "$(dirname "$steering_link")"
        # Remove existing real directory (e.g., the empty ~/.kiro/steering dir
        # kiro creates) before linking, so ln -sfn creates a symlink not a nested one
        if [ -d "$steering_link" ] && [ ! -L "$steering_link" ]; then
            rm -rf "$steering_link"
        fi
        ln -sfn "$STEERING_SOURCE" "$steering_link"
        echo "✓ Linked steering to $agent ($steering_link)"
        ;;
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
    rules:*)
        # Format: rules:DIR:CLAUDE_MD_PATH
        rules_spec="${steering#rules:}"
        rules_dir="${rules_spec%%:*}"
        claude_md="${rules_spec#*:}"
        mkdir -p "$rules_dir"
        generate_rules_steering "$rules_dir" "$claude_md"
        echo "✓ Generated steering for $agent ($rules_dir/)"
        ;;
    esac
done

echo "✅ Agent skills distributed to ${#ENABLED_AGENTS[@]} enabled agent(s)"
