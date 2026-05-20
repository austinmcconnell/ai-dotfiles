#!/bin/bash
# Block any tool from accessing sops/age secret files
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)
#
# Protected patterns:
#   - Age private keys: keys.txt in sops/age dirs, *.agekey
#   - sops decrypt commands (would expose plaintext)

set -euo pipefail

TOOL_INPUT=$(cat)

# Extract only actionable paths/commands — not all string values.
# For file tools: check path, file_path, image_paths
# For shell tools: check command
PATHS=$(echo "$TOOL_INPUT" | jq -r '
    [.tool_input.path // empty,
    .tool_input.file_path // empty,
    (.tool_input.operations // [] | .[].path // empty),
    (.tool_input.operations // [] | .[] | .image_paths // [] | .[]),
    .tool_input.command // empty
    ] | .[]' 2>/dev/null)

# Block age private keys
if echo "$PATHS" | grep -qiE '(sops/age/keys\.txt|\.agekey($|[^a-z]))'; then
    echo "BLOCKED: Access to age private key files is not permitted" >&2
    exit 2
fi

# Block sops decrypt commands (would output plaintext secrets)
if echo "$PATHS" | grep -qiE 'sops (decrypt|--decrypt|-d )'; then
    echo "BLOCKED: sops decrypt commands are not permitted" >&2
    exit 2
fi
