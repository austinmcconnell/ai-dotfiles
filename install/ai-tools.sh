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

# Extra steering sources — host-local, deliberately NOT tracked in this repo so
# company-specific steering stays out of the public dotfiles. Each entry is a
# `domain=path` pair: `domain` is the steering domain whose dir the overlay
# merges into, `path` is a directory of *.md docs. Populated from two optional
# sources (both absent is the normal public-cloner case):
#   - $EXTRA_STEERING_SOURCES env var — colon-separated domain=path pairs
#   - ~/.extra/steering-sources file  — one domain=path pair per line (# ok)
# A listed-but-missing path is not silent — see link_steering_tree.
EXTRA_STEERING_PAIRS=()
if [ -n "${EXTRA_STEERING_SOURCES:-}" ]; then
    IFS=':' read -r -a _env_pairs <<<"$EXTRA_STEERING_SOURCES"
    EXTRA_STEERING_PAIRS+=("${_env_pairs[@]}")
fi
if [ -f "$HOME/.extra/steering-sources" ]; then
    while IFS= read -r _line; do
        _line="${_line%%#*}"
        _line="${_line#"${_line%%[![:space:]]*}"}"
        _line="${_line%"${_line##*[![:space:]]}"}"
        [ -n "$_line" ] && EXTRA_STEERING_PAIRS+=("$_line")
    done <"$HOME/.extra/steering-sources"
fi

# Steering domains shipped to every session by the steering-file generators
# (Gemini GEMINI.md, Cursor .mdc, Claude rules/). These are universal — they
# apply to any work in any session. Domain-specific steering (ansible,
# documentation, datadog, scrum) is inlined per-persona into the relevant Claude
# subagent file by scripts/generate-personas.sh, so it doesn't pollute unrelated
# sessions.
# Single source of truth: every generator loops this array, so adding a
# universal domain here updates all three tools at once.
#
# This split only exists because these three tools have no per-session
# resource scoping — unlike kiro-cli, where every invocation is an agent with
# its own `resources` array, so steering filters natively at load time (see
# kiro-cli:steering below: a per-domain tree under ~/.kiro/steering, globbed
# per-domain by each agent, so no distribution-time split is needed).
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
                content="$(sed '1,/^---$/d' "$f")"
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

# Build the kiro steering tree at $dest and verify it resolves.
# Used by: kiro-cli (file://~/.kiro/steering/<domain>/**/*.md URIs cannot expand
# $AI_DOTFILES_DIR, so this on-disk tree under ~/.kiro is the relocation seam).
#
# $dest is a real directory of per-domain real directories, each holding
# per-file symlinks to the public steering docs (etc/ai/steering/<domain>/*.md)
# plus any host-local overlay docs for that domain (from EXTRA_STEERING_PAIRS).
# Per-file (not whole-domain) symlinks let public and overlay *.md coexist in one
# <domain>/ namespace, so kiro's per-domain glob (<domain>/**/*.md) matches both.
#
# Idempotency: an old whole-tree symlink is removed, a stale real dir rebuilt; a
# non-symlink, non-directory at $dest fails loudly rather than being deleted.
#
# Overlay-path discipline (shell-conventions "never silently pass a dangling
# path", decision/extra-sources-dangling-path-warn): a domain with no overlay
# entry is silent, but an entry whose path is missing or holds no *.md warns to
# stderr and is skipped (non-fatal — the public docs still populate the domain).
#
# On probe failure the whole tree is removed and the function returns non-zero,
# so the caller never reports success on a broken seam.
#
# Args: $1 = steering root path, $2 = steering-relative probe file that must
#       resolve (e.g. security/env-file-protection.md).
# Returns: 0 when built and the probe resolves, 1 otherwise (message on stderr).
link_steering_tree() {
    local dest="$1" probe="$2"

    if [[ -L "$dest" ]]; then
        rm -f "$dest"
    elif [[ -d "$dest" ]]; then
        rm -rf "${dest:?}"
    elif [[ -e "$dest" ]]; then
        echo "✗ $dest exists and is not a symlink or directory; refusing to replace it" >&2
        return 1
    fi

    mkdir -p "$dest"

    # Public domains: one real dir per domain, per-file symlinks to its *.md.
    local domain_dir domain steering_file
    while IFS= read -r -d '' domain_dir; do
        domain="$(basename "$domain_dir")"
        mkdir -p "$dest/$domain"
        for steering_file in "$domain_dir"/*.md; do
            [[ -f "$steering_file" ]] || continue
            ln -sfn "$steering_file" "$dest/$domain/$(basename "$steering_file")"
        done
    done < <(find "$STEERING_SOURCE" -mindepth 1 -maxdepth 1 -type d -print0)

    # Host-local overlay: merge each pair's *.md into its domain dir alongside
    # the public docs (a domain with no public dir is created on demand).
    local entry name src overlay_file
    for entry in "${EXTRA_STEERING_PAIRS[@]:-}"; do
        name="$(pair_name "$entry")"
        [[ -n "$name" ]] || continue
        src="$(pair_path "$entry")"
        if [[ ! -d "$src" ]]; then
            echo "⚠ SKIPPED host-local steering for '$name': $src does not exist" >&2
            continue
        fi
        local found=0
        for overlay_file in "$src"/*.md; do
            [[ -f "$overlay_file" ]] || continue
            mkdir -p "$dest/$name"
            ln -sfn "$overlay_file" "$dest/$name/$(basename "$overlay_file")"
            found=1
        done
        ((found)) ||
            echo "⚠ SKIPPED host-local steering for '$name': no *.md in $src" >&2
    done

    if [[ ! -e "$dest/$probe" ]]; then
        echo "✗ $dest does not resolve $probe (is AI_DOTFILES_DIR correct?)" >&2
        rm -rf "${dest:?}"
        return 1
    fi
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
#                  "symlink:DIR" = build the kiro steering tree at DIR — a real
#                                  dir of per-domain real dirs with per-file
#                                  symlinks (public docs + host-local overlay),
#                                  read via file://~/.kiro/steering/<domain>/**/*.md
#                                  URIs in each agent's resources
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
        link_steering_tree "$steering_link" "security/env-file-protection.md" || exit 1
        echo "✓ Built steering tree for $agent ($steering_link)"
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
