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
    "kiro-cli"
    # "codex"
    # "cursor"
    # "gemini-cli"
    # "github-copilot"
    # "windsurf"
)

# ---------------------------------------------------------------

print_section_header "Distributing Agent Skills"

SKILLS_SOURCE="$AI_DOTFILES_DIR/etc/ai/skills"
STEERING_SOURCE="$AI_DOTFILES_DIR/etc/ai/steering"

# Extra skill sources — host-local, deliberately NOT tracked in this repo so
# machine-specific skill locations stay out of the public dotfiles. Each entry
# is a `name=path` pair: `name` is the mount label under the agent's `extra/`
# umbrella category, `path` is a directory of skill dirs. Decoupling the mount
# name from the source folder name lets the agent globs (which reference the
# stable `extra/` umbrella) stay fixed regardless of where a source lives.
#
# Populated from two optional sources, mirroring the ~/.extra convention in
# etc/zsh/custom/plugins/extra/:
#   - $EXTRA_SKILL_SOURCES env var — colon-separated name=path pairs (PATH-like)
#   - ~/.extra/skill-sources file  — one name=path pair per line (# comments ok)
# Absent sources and missing paths are skipped silently (see the per-entry
# [ -d ] guards in the distribution loop).
EXTRA_SKILL_PAIRS=()
if [ -n "${EXTRA_SKILL_SOURCES:-}" ]; then
    IFS=':' read -r -a _env_pairs <<<"$EXTRA_SKILL_SOURCES"
    EXTRA_SKILL_PAIRS+=("${_env_pairs[@]}")
fi
if [ -f "$HOME/.extra/skill-sources" ]; then
    while IFS= read -r _line; do
        _line="${_line%%#*}"
        _line="${_line#"${_line%%[![:space:]]*}"}"
        _line="${_line%"${_line##*[![:space:]]}"}"
        [ -n "$_line" ] && EXTRA_SKILL_PAIRS+=("$_line")
    done <"$HOME/.extra/skill-sources"
fi

# Steering domains shipped to every session by the steering-file generators
# (Gemini GEMINI.md, Cursor .mdc, Claude rules/). These are universal — they
# apply to any work in any session. Domain-specific steering (ansible,
# documentation, datadog, scrum) is loaded per-persona via @-imports in the
# relevant Claude subagent body, so it doesn't pollute unrelated sessions.
# Single source of truth: every generator loops this array, so adding a
# universal domain here updates all three tools at once.
#
# This split only exists because these three tools have no per-session
# resource scoping — unlike kiro-cli, where every invocation is an agent with
# its own `resources` array, so steering filters natively at load time (see
# kiro-cli:steering below: a raw symlink of the whole tree, no split needed).
# Claude/Cursor/Gemini each have exactly one always-on global context surface
# with no runtime filter, so whatever lands here loads on every session,
# forever — the split has to happen at distribution time instead. See
# etc/ai/README.md's "Why Some Steering Is Universal" section for the full
# cross-tool rationale.
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
    claude-code:skills_layout) echo "flat" ;;
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

# Split a `name=path` entry into its parts and expand a leading ~ in the path.
# Usage: pair_name "$entry" / pair_path "$entry". An entry with no `=` yields an
# empty name (caller skips it).
pair_name() {
    case "$1" in
    *=*) printf '%s' "${1%%=*}" ;;
    *) printf '' ;;
    esac
}
pair_path() {
    local path="${1#*=}"
    # Expand a leading ~/ to $HOME. The pattern is a literal prefix check, not
    # shell tilde expansion (which does not fire inside quotes or variables).
    if [ "${path#\~/}" != "$path" ]; then
        printf '%s' "$HOME/${path#\~/}"
    else
        printf '%s' "$path"
    fi
}

# ---------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------
for agent in "${ENABLED_AGENTS[@]}"; do
    skills_path="$(agent_config "$agent" skills_path)"
    steering="$(agent_config "$agent" steering)"
    skills_layout="$(agent_config "$agent" skills_layout)"
    : "${skills_layout:=nested}"

    # Symlink skills
    mkdir -p "$(dirname "$skills_path")"
    case "$skills_layout" in
    flat)
        # This agent only discovers <skills_path>/<skill-name>/SKILL.md one
        # level deep (no recursion into category subfolders like kiro's
        # skill://.../shared/**/SKILL.md resources support). Symlink each
        # skill directory individually so it's directly visible.
        rm -rf "$skills_path"
        mkdir -p "$skills_path"
        skill_count=0
        while IFS= read -r -d '' skill_dir; do
            ln -sfn "$skill_dir" "$skills_path/$(basename "$skill_dir")"
            skill_count=$((skill_count + 1))
        done < <(find "$SKILLS_SOURCE" -mindepth 2 -maxdepth 2 -type d ! -path "*/.system/*" -print0)
        # Extra skill sources: this layout has no category grouping, so the
        # pair `name` is unused here — each skill dir under every source path is
        # symlinked individually alongside the primary skills. Per-entry [ -d ]
        # guard skips sources absent on this machine.
        for _entry in "${EXTRA_SKILL_PAIRS[@]}"; do
            _src="$(pair_path "$_entry")"
            [ -n "$(pair_name "$_entry")" ] && [ -d "$_src" ] || continue
            while IFS= read -r -d '' skill_dir; do
                ln -sfn "$skill_dir" "$skills_path/$(basename "$skill_dir")"
                skill_count=$((skill_count + 1))
            done < <(find "$_src" -mindepth 1 -maxdepth 1 -type d -print0)
        done
        echo "✓ Linked $skill_count flattened skills to $agent ($skills_path)"
        ;;
    *)
        # Nested layout: this agent discovers skills via recursive globs per
        # category (e.g. kiro's skill://~/.kiro/skills/shared/**/SKILL.md).
        # <skills_path> is a REAL directory of per-category symlinks — one per
        # dotfiles category plus any guarded optional sources — rather than a
        # single whole-tree symlink, so an extra source can mount as its own
        # category sibling instead of resolving through a tree-wide symlink.
        #
        # Idempotency: handle both leftover shapes. An old single whole-tree
        # symlink is removed before building the real dir; a stale real dir is
        # rebuilt cleanly each run.
        if [ -L "$skills_path" ]; then
            rm -f "$skills_path"
        elif [ -d "$skills_path" ]; then
            rm -rf "$skills_path"
        fi
        mkdir -p "$skills_path"
        category_count=0
        # Category list is glob-driven, not hardcoded, so adding a dotfiles
        # skill category stays zero-config.
        while IFS= read -r -d '' category_dir; do
            ln -sfn "$category_dir" "$skills_path/$(basename "$category_dir")"
            category_count=$((category_count + 1))
        done < <(find "$SKILLS_SOURCE" -mindepth 1 -maxdepth 1 -type d ! -name ".system" -print0)
        echo "✓ Linked $category_count skill categories to $agent ($skills_path)"

        # Extra skill sources mount under a single `extra/` umbrella category:
        # extra/<name> -> <path>. One stable umbrella keeps the agent globs
        # (skill://.../extra/**/SKILL.md) fixed no matter which sources exist.
        # Per-entry [ -d ] guard skips sources absent on this machine.
        extra_count=0
        for _entry in "${EXTRA_SKILL_PAIRS[@]}"; do
            _name="$(pair_name "$_entry")"
            _src="$(pair_path "$_entry")"
            [ -n "$_name" ] && [ -d "$_src" ] || continue
            mkdir -p "$skills_path/extra"
            ln -sfn "$_src" "$skills_path/extra/$_name"
            extra_count=$((extra_count + 1))
        done
        [ "$extra_count" -gt 0 ] &&
            echo "✓ Linked $extra_count extra skill source(s) to $agent ($skills_path/extra)"
        ;;
    esac

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
