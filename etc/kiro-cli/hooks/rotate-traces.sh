#!/bin/bash
# Rotate trace files older than 7 days or when total size exceeds 100MB
# Hook type: agentSpawn (runs once per session start)

set -euo pipefail

TRACE_DIR="$HOME/.kiro/logs/traces"
[[ -d "$TRACE_DIR" ]] || exit 0
chmod 700 "$TRACE_DIR"

MAX_AGE_DAYS=7
MAX_TOTAL_MB=100

# Delete files older than MAX_AGE_DAYS
find "$TRACE_DIR" -name "*.jsonl" -mtime "+${MAX_AGE_DAYS}" -delete 2>/dev/null

# If total size still exceeds limit, delete oldest files until under budget
TOTAL_KB=$(du -sk "$TRACE_DIR" 2>/dev/null | cut -f1)
MAX_TOTAL_KB=$((MAX_TOTAL_MB * 1024))

if [[ "${TOTAL_KB:-0}" -gt "$MAX_TOTAL_KB" ]]; then
    find "$TRACE_DIR" -name "*.jsonl" -print0 | xargs -0 ls -t | tail -n +20 | xargs rm -f 2>/dev/null
fi

exit 0
