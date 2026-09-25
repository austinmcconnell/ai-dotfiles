#!/bin/bash
# Shared helpers for the local AI usage/cost tracking store.
# Sourced by per-tool ingestion scripts (e.g. claude-statusline.sh).
# Not meant to be executed directly.

set -euo pipefail

USAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DB_DIR="$HOME/.local/share/ai-usage"
USAGE_DB="$USAGE_DB_DIR/usage.db"
USAGE_SCHEMA="$USAGE_DIR/schema.sql"
USAGE_PRICING="$USAGE_DIR/pricing.json"

# Create the DB directory and apply the schema. Safe to call on every
# invocation: CREATE TABLE IF NOT EXISTS makes this idempotent.
usage_db_init() {
    mkdir -p "$USAGE_DB_DIR"
    sqlite3 "$USAGE_DB" <"$USAGE_SCHEMA"
}

# Render a value as a single-quoted, escaped SQL string literal.
# Empty/absent input, or jq's "null", becomes the SQL literal NULL.
sql_str() {
    local value="${1:-}"
    if [[ -z "$value" || "$value" == "null" ]]; then
        printf 'NULL'
    else
        printf "'%s'" "$(printf '%s' "$value" | sed "s/'/''/g")"
    fi
}

# Pass a number through as a bare SQL literal, or NULL when absent/non-numeric.
sql_num() {
    local value="${1:-}"
    if [[ "$value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        printf 'NULL'
    fi
}

# Estimate a $ cost for a token count with no input/output split (used for
# subagent tasks, which report one combined tokenCount). Uses the average of
# the model's input and output per-token price as a blended rate -- a rough
# midpoint, not an exact figure, since the real input/output mix is unknown.
# Prints an empty string (caller should treat as NULL) when the model has no
# pricing entry or the token count is missing.
usage_estimate_cost() {
    local model="${1:-}" tokens="${2:-}"
    if [[ -z "$model" || "$model" == "null" || ! "$tokens" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        return 0
    fi
    jq -r --arg model "$model" --argjson tokens "$tokens" '
        .models[$model] as $m
        | if $m == null then ""
            else (($m.input_per_mtok + $m.output_per_mtok) / 2) * $tokens / 1000000
            end
    ' "$USAGE_PRICING"
}
