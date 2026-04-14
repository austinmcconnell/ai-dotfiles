#!/bin/bash
# Block any tool from accessing .env files

TOOL_INPUT=$(cat)

if echo "$TOOL_INPUT" | jq -r '.. | strings' 2>/dev/null | grep -qiE '(^|/)\.env($|\.)'; then
    echo "BLOCKED: Access to .env files is not permitted for security reasons" >&2
    exit 2
fi
