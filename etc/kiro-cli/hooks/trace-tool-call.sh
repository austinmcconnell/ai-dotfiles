#!/bin/bash
# Log all tool calls to a session-scoped trace file for debugging
# Hook type: postToolUse (matcher: "*")
# NOTE: No set -euo pipefail — this hook must never crash the session.
# jq/perl failures are expected on malformed input and should degrade gracefully.

TOOL_INPUT=$(cat)

AGENT="${AI_AGENT_NAME:-${1:-default}}"
TRACE_DIR="$HOME/.kiro/logs/traces"
mkdir -p "$TRACE_DIR"
chmod 700 "$TRACE_DIR"

# Session ID: prefer explicit, fall back to date + parent PID
SESSION_ID="${KIRO_SESSION_ID:-$(date +%Y%m%d)-$$}"
TRACE_FILE="$TRACE_DIR/${SESSION_ID}.jsonl"

# Extract fields (fail gracefully on malformed JSON)
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null) || TOOL_NAME="unknown"
TOOL_IN=$(echo "$TOOL_INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || TOOL_IN="{}"
TOOL_OUT=$(echo "$TOOL_INPUT" | jq -c '.tool_output // {}' 2>/dev/null) || TOOL_OUT="{}"
DURATION=$(echo "$TOOL_INPUT" | jq -r '.duration_ms // empty' 2>/dev/null) || DURATION=""

# Redact sensitive values (perl for case-insensitive support on macOS)
REDACT_PATTERN='(password|secret|token|key|credential|authorization|api.key|private)'
TOOL_IN_SAFE=$(echo "$TOOL_IN" | perl -pe "s/(\"($REDACT_PATTERN)\"\\s*:\\s*\")[^\"]*\"/\$1[REDACTED]\"/gi")
TOOL_OUT_SAFE=$(echo "$TOOL_OUT" | perl -pe "s/(\"($REDACT_PATTERN)\"\\s*:\\s*\")[^\"]*\"/\$1[REDACTED]\"/gi")

# Truncate for storage
INPUT_SUMMARY=$(echo "$TOOL_IN_SAFE" | cut -c1-300)
OUTPUT_SUMMARY=$(echo "$TOOL_OUT_SAFE" | jq -c '{
    exit_status: .exit_status,
    stdout_len: (.stdout // "" | length),
    stderr_len: (.stderr // "" | length),
    error: (.error // null)
} | del(.error | nulls)' 2>/dev/null || echo "$TOOL_OUT_SAFE" | cut -c1-200)

# Write trace entry
jq -nc \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg agent "$AGENT" \
    --arg tool "$TOOL_NAME" \
    --arg input "$INPUT_SUMMARY" \
    --arg output "$OUTPUT_SUMMARY" \
    --arg duration "${DURATION:-}" \
    --arg session "$SESSION_ID" \
    '{ts: $ts, agent: $agent, tool: $tool, input_summary: $input, output_summary: $output, duration_ms: ($duration | if . == "" then null else tonumber end), session: $session}' \
    >>"$TRACE_FILE" 2>/dev/null

exit 0
