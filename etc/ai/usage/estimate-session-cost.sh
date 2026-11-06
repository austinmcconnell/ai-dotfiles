#!/bin/bash
# Session-level cost cross-check, not a billing source. Reprices each
# cost_snapshots firing from its raw per-call usage fields using
# pricing.json, sums them, and compares the total against the session's
# actual total_cost_usd (the authoritative figure -- see README.md).
#
# Per-call fields live only in raw_json: context_window.current_usage.* is
# the last-API-call-only usage (not the cumulative-looking total_input_tokens/
# total_output_tokens columns cost_snapshots also stores, which are the
# current context-window size, not a billing total -- see
# analysis/claude-usage-tracker-fixes.md's "Status-line payload semantics").
# So this reads raw_json per row instead of the dedicated columns.
#
# Usage: estimate-session-cost.sh <session_id-or-prefix>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"

SESSION_PREFIX="${1:?Usage: estimate-session-cost.sh <session_id-or-prefix>}"

MATCHES="$(sqlite3 "$USAGE_DB" "SELECT session_id FROM sessions WHERE tool = 'claude-code' AND session_id LIKE '${SESSION_PREFIX}%';")"
MATCH_COUNT="$(printf '%s\n' "$MATCHES" | grep -c . || true)"

if [[ "$MATCH_COUNT" -eq 0 ]]; then
    echo "No session matches '$SESSION_PREFIX'" >&2
    exit 1
elif [[ "$MATCH_COUNT" -gt 1 ]]; then
    echo "Ambiguous prefix '$SESSION_PREFIX', matches:" >&2
    printf '%s\n' "$MATCHES" >&2
    exit 1
fi

SESSION_ID="$MATCHES"

ACTUAL_COST="$(sqlite3 "$USAGE_DB" "SELECT total_cost_usd FROM sessions WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")"
if [[ -z "$ACTUAL_COST" || "$ACTUAL_COST" == "null" ]]; then
    echo "Session $SESSION_ID has no recorded total_cost_usd" >&2
    exit 1
fi

SNAPSHOT_COUNT="$(sqlite3 "$USAGE_DB" "SELECT count(*) FROM cost_snapshots WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")"
if [[ "$SNAPSHOT_COUNT" -eq 0 ]]; then
    echo "Session $SESSION_ID has no cost_snapshots rows to estimate from" >&2
    exit 1
fi

RESULT="$(
    sqlite3 -json "$USAGE_DB" \
        "SELECT raw_json FROM cost_snapshots WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID") ORDER BY id;" |
        jq -r --argjson pricing "$(cat "$USAGE_PRICING")" --argjson actual "$ACTUAL_COST" '
        def write_mult($ttl):
            if $ttl == "1h" then $pricing.cache_write_multiplier_1h
            elif $ttl == "5m" then $pricing.cache_write_multiplier_5m
            else 1 end;

        # Prices one snapshot from its raw current_usage fields. Returns
        # null (not 0) when the model has no pricing entry, so callers can
        # tell "priced at zero cost" apart from "could not price".
        def price_row:
            (.raw_json | fromjson) as $p
            | ($pricing.models[$p.model.id // ""]) as $m
            | if $m == null then null else
                ($p.context_window.current_usage.input_tokens // 0) as $in
                | ($p.context_window.current_usage.output_tokens // 0) as $out
                | ($p.context_window.current_usage.cache_creation_input_tokens // 0) as $cw
                | ($p.context_window.current_usage.cache_read_input_tokens // 0) as $cr
                | ($m.cache_read_multiplier // $pricing.cache_read_multiplier) as $read_mult
                | (write_mult($p.prompt_cache.ttl // "5m")) as $wmult
                | (
                    ($in * $m.input_per_mtok) + ($out * $m.output_per_mtok)
                    + ($cw * $m.input_per_mtok * $wmult) + ($cr * $m.input_per_mtok * $read_mult)
                ) / 1000000
                end;

        [.[] | price_row] as $priced
        | ([$priced[] | select(. == null)] | length) as $unpriced
        | ([$priced[] | select(. != null)] | add // 0) as $estimate
        | (if $actual == 0 then null else $estimate / $actual end) as $ratio
        | [
            $estimate,
            ($ratio // "null"),
            (if $ratio != null and ($ratio < 0.85 or $ratio > 1.15) then "1" else "0" end),
            $unpriced
        ]
        | join("\u001f")
    '
)"

IFS=$'\x1f' read -r ESTIMATE RATIO FLAGGED UNPRICED <<<"$RESULT"

printf 'session:  %s\n' "$SESSION_ID"
printf 'estimate: $%.4f\n' "$ESTIMATE"
printf 'actual:   $%.4f\n' "$ACTUAL_COST"
# shellcheck disable=SC2016
if [[ "$RATIO" == "null" ]]; then
    printf 'ratio:    n/a (actual cost is $0)\n'
else
    printf 'ratio:    %.2f\n' "$RATIO"
fi
if [[ "$FLAGGED" == "1" ]]; then
    printf 'flag:     ratio outside 0.85-1.15 -- estimate and actual disagree, see etc/ai/usage/README.md\n'
fi
if [[ "$UNPRICED" -gt 0 ]]; then
    printf 'warning:  %s of %s snapshots used a model with no pricing.json entry; estimate is incomplete\n' \
        "$UNPRICED" "$SNAPSHOT_COUNT"
fi
