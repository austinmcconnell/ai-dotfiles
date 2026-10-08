#!/usr/bin/env bash
set -euo pipefail

# Reject single-leading-slash Read/Edit/Write permission rules in
# etc/claude-code/settings.json.
#
# In Claude Code, a rule like Read(/etc/**) is NOT absolute: a single
# leading slash anchors at the settings source, so in user settings it
# matches ~/.claude/etc/** and protects nothing. Absolute filesystem
# paths need the // form (Read(//etc/**)). The mistake fails silently —
# the rule parses fine and simply never matches — so catch it at commit
# time.
#
# Usage: ./validate-claude-path-rules.sh [path-to-settings.json]

SETTINGS_FILE="${1:-${AI_DOTFILES_DIR:-$HOME/.ai-dotfiles}/etc/claude-code/settings.json}"

if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "Error: Settings file not found: $SETTINGS_FILE" >&2
    exit 1
fi

bad_rules=$(jq -r '
    (.permissions // {}) | to_entries[]
    | select(.value | type == "array")
    | .key as $list
    | .value[]
    | select(type == "string" and test("^(Read|Edit|Write)\\(/[^/]"))
    | "  permissions.\($list): \(.)"
' "$SETTINGS_FILE")

if [[ -n "$bad_rules" ]]; then
    echo "✗ Single-slash path rules in $SETTINGS_FILE (anchored at ~/.claude, not /):" >&2
    echo "$bad_rules" >&2
    echo "  Use // for absolute paths, e.g. Read(//etc/**), or ~/ for home." >&2
    exit 1
fi

echo "✓ No single-slash Read/Edit/Write rules in $SETTINGS_FILE"
