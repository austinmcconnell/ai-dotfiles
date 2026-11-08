#!/bin/bash

# ---------------------------------------------------------------
# Host-local AI Source Templates
# Writes `.example` templates for the two optional, git-ignored files under
# ~/.extra that mount machine-specific skills and steering kept out of this
# public repo:
#   - ~/.extra/skill-sources     (install/ai-tools.sh)
#   - ~/.extra/steering-sources  (install/ai-tools.sh, scripts/generate-personas.sh)
#
# Every consumer treats an ABSENT live file as "in-repo content only", so this
# script never writes a live file. A live steering-sources with an uncommented
# placeholder path would emit a ⚠ SKIPPED warning on every install; a
# `.example` with only commented lines is inert.
#
# The `.example` files are repo-owned templates, not user data, so they are
# refreshed on every run — that is how template improvements reach an existing
# machine. User edits live in the copied live files, which are never touched.
# ---------------------------------------------------------------

set -euo pipefail

# Resolve the AI dotfiles root from this script's location when not already set
# (e.g. run standalone rather than sourced from a parent install.sh).
AI_DOTFILES_DIR="${AI_DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

source "$AI_DOTFILES_DIR/install/utils.sh"

print_section_header "Scaffolding ~/.extra AI source templates"

mkdir -p "$HOME/.extra"

# Write/refresh a repo-owned `.example` template. Rewrites only when the content
# differs, so a no-op run stays quiet and does not bump mtime.
# Usage: scaffold_example <target-path> <<'EOF' ... EOF
scaffold_example() {
    local target="$1" content
    content="$(cat)"
    if [[ -f "$target" && "$content" == "$(cat "$target")" ]]; then
        log_info "$target already current"
        return
    fi
    printf '%s\n' "$content" >"$target"
    log_info "Wrote $target"
}

scaffold_example "$HOME/.extra/skill-sources.example" <<'EOF'
# Host-local skill sources — one `name=path` per line (# comments ok).
#
# Consumed by ai-dotfiles install/ai-tools.sh to mount machine-specific skill
# dirs that are not tracked in the public repo.
#   name = mount label under each agent's `extra/` skills umbrella category.
#   path = a directory containing skill dirs; a leading ~/ is expanded to $HOME.
# A line with no `=` is skipped; leading/trailing whitespace is trimmed.
#
# Env-var equivalent: $EXTRA_SKILL_SOURCES, colon-separated name=path pairs
# (PATH-like). Both the env var and this file are additive.
#
# To activate: copy this file to ~/.extra/skill-sources and uncomment/edit.
# An absent live file is normal — the AI tooling then mounts in-repo skills only.
#
# work=~/work-config/ai-skills
EOF

scaffold_example "$HOME/.extra/steering-sources.example" <<'EOF'
# Host-local steering sources — one `domain=path` per line (# comments ok).
#
# Consumed by ai-dotfiles install/ai-tools.sh and scripts/generate-personas.sh
# to merge machine-specific steering docs into the matching domain.
#   domain = a steering domain name (e.g. scrum, ansible, documentation, datadog).
#   path   = a directory of *.md steering docs; a leading ~/ is expanded to $HOME.
# A line with no `=` is skipped; leading/trailing whitespace is trimmed.
#
# Env-var equivalent: $EXTRA_STEERING_SOURCES, colon-separated domain=path pairs.
#
# IMPORTANT: a listed path that is missing (or a dir with no *.md) emits a
# non-fatal `⚠ SKIPPED` warning at install time. An absent live file is silent.
# So keep example lines COMMENTED until the path actually exists — an
# uncommented dead path would warn on every install.
#
# To activate: copy this file to ~/.extra/steering-sources and uncomment/edit.
#
# scrum=~/work-config/ai-steering/scrum
EOF
