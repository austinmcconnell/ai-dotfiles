#!/bin/bash
# Block any tool from accessing SSH private key files
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)
#
# Protected patterns:
#   - SSH private keys: .ssh/id_* (excluding .pub)

set -euo pipefail

TOOL_INPUT=$(cat)

# Extract actionable paths/commands (same pattern as block-sops-age-files.sh)
PATHS=$(echo "$TOOL_INPUT" | jq -r '
    [.tool_input.path // empty,
    .tool_input.file_path // empty,
    (.tool_input.operations // [] | .[].path // empty),
    (.tool_input.operations // [] | .[] | .image_paths // [] | .[]),
    .tool_input.command // empty
    ] | .[]' 2>/dev/null)

# Block SSH private keys (id_* without .pub extension)
if echo "$PATHS" | grep -iE '\.ssh/id_' | grep -qvE '\.pub($|[^a-z])'; then
    echo "BLOCKED: Access to SSH private key files is not permitted" >&2
    exit 2
fi
