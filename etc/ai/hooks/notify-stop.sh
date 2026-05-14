#!/bin/bash
# Desktop notification when Claude Code finishes a task
# Uses OSC 9 (iTerm2/WezTerm)

set -euo pipefail

input=$(cat)
msg=$(echo "$input" | jq -r '.last_assistant_message // "Task complete"' | head -c 100)

seq=$(printf '\033]9;Claude Code: %s\007' "$msg")
jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
