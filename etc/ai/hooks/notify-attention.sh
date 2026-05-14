#!/bin/bash
# Desktop notification when Claude Code needs user attention
# Uses OSC 9 (iTerm2/WezTerm)

set -euo pipefail

input=$(cat)
body=$(echo "$input" | jq -r '.message // "Needs attention"')

seq=$(printf '\033]9;Claude Code: %s\007' "$body")
jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
