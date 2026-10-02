#!/usr/bin/env bash
set -euo pipefail

# Restore etc/claude-code/settings.json to a canonical top-level key order.
#
# Claude Code rewrites this entire file whenever it persists a settings
# change (plugin toggles, /config changes, theme/model switches, etc.) by
# deserializing into its internal settings object and re-serializing the
# whole thing back out. The resulting key order follows Claude Code's own
# internal schema, not this file's prior order and not any lexical sort —
# so every app-driven write scrambles the top level differently.
#
# This script only reorders TOP-LEVEL keys. Nested objects (hooks lifecycle
# order, permissions allow/deny/ask grouping) are left untouched, since they
# already carry deliberate, meaningful ordering.
#
# Usage: ./sort-claude-settings-json.sh [path-to-settings.json]

SETTINGS_FILE="${1:-${AI_DOTFILES_DIR:-$HOME/.ai-dotfiles}/etc/claude-code/settings.json}"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "Error: Settings file not found: $SETTINGS_FILE" >&2
    exit 1
fi

# Canonical order: an importance-ranked narrative for a human reading the
# file top-to-bottom, not an alphabetical or schema-derived order. Read as:
# how much does this key change what Claude Code actually does, most
# impactful first, ending with the setting least likely to ever matter.
#
#   $schema                - boilerplate; universal convention to lead with
#   permissions             - gates what Claude can do; most-consulted block
#   hooks                   - automated side effects on every session
#   enabledPlugins           - capability surface (extra MCP tools/skills)
#   attribution              - visible external behavior (commit/PR trailers)
#   autoMemoryEnabled          - feature toggle with a documented rationale
#   showThinkingSummaries        - UI toggle
#   spinnerTipsEnabled            - UI toggle
#   theme                          - UI toggle
#   verbose                         - logging verbosity toggle
#   cleanupPeriodDays                 - disk-retention housekeeping; set once,
#                                       least behaviorally interesting key here
#
# Any key not listed here (e.g. a new setting Claude Code introduces) is
# appended afterward in alphabetical order, so nothing is silently dropped.
declare -a KEY_ORDER=(
    "\$schema"
    "permissions"
    "hooks"
    "enabledPlugins"
    "attribution"
    "autoMemoryEnabled"
    "showThinkingSummaries"
    "spinnerTipsEnabled"
    "theme"
    "verbose"
    "cleanupPeriodDays"
)

order_json=$(printf '%s\n' "${KEY_ORDER[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')

desired_order=$(jq -c --argjson order "$order_json" '
    . as $in
    | ($order | map(select(. as $k | $in | has($k)))) as $known
    | (($in | keys_unsorted) - $known | sort) as $rest
    | ($known + $rest)
' "$SETTINGS_FILE")
current_order=$(jq -c 'keys_unsorted' "$SETTINGS_FILE")

# Skip the rewrite entirely when order already matches: jq's own output
# formatting (2-space indent) differs from this repo's dprint-enforced
# 4-space style, so an unconditional rewrite would introduce a pure
# formatting diff on every run, forever, even with nothing to reorder.
if [[ "$current_order" == "$desired_order" ]]; then
    echo "✓ $SETTINGS_FILE already in canonical order"
    exit 0
fi

TEMP_FILE=$(mktemp)
jq --argjson order "$desired_order" '
    . as $in | reduce $order[] as $k ({}; . + {($k): $in[$k]})
' "$SETTINGS_FILE" >"$TEMP_FILE"

mv "$TEMP_FILE" "$SETTINGS_FILE"
echo "✓ Sorted top-level keys in $SETTINGS_FILE"
