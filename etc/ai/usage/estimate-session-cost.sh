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
# Snapshots never carry advisor passes, so the estimate leaves them out. An "advisor:" line
# prices them separately from the session's transcript when that file is still on disk. It is
# not added to the estimate and does not affect the ratio or the flag.
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

        def version_parts: split(".") | map(tonumber);

        # A pricing entry can name the Claude Code version that repriced its cache reads.
        # A missing version keeps the current rate.
        def read_mult($m; $version):
            ($m.cache_read_multiplier // $pricing.cache_read_multiplier) as $current
            | ($m.cache_read_multiplier_before_version) as $old
            | if $old == null or $version == null then $current
            elif ($version | version_parts) < ($old.version | version_parts) then $old.multiplier
            else $current
            end;

        # A long_context entry replaces the base rates for one request whose prompt is over
        # its threshold. The choice is per request, so it is made per row, not per session.
        def rates($m; $prompt):
            if $m.long_context != null and $prompt > $m.long_context.prompt_tokens_over
            then $m.long_context
            else $m
            end;

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
                | rates($m; $in + $cw + $cr) as $r
                | read_mult($m; $p.version) as $read_mult
                | (write_mult($p.prompt_cache.ttl // "5m")) as $wmult
                | (
                    ($in * $r.input_per_mtok) + ($out * $r.output_per_mtok)
                    + ($cw * $r.input_per_mtok * $wmult) + ($cr * $r.input_per_mtok * $read_mult)
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

TRANSCRIPT_PATH="$(sqlite3 "$USAGE_DB" "SELECT CASE WHEN json_valid(raw_json)
    THEN json_extract(raw_json, '\$.transcript_path') END
    FROM sessions WHERE tool = 'claude-code' AND session_id = $(sql_str "$SESSION_ID");")"

pass_count() {
    if [[ "$1" -eq 1 ]]; then
        printf '1 pass'
    else
        printf '%s passes' "$1"
    fi
}

# The advisor line's text for a session's transcript path (empty when the session has none).
advisor_summary() {
    local path="$1" row passes usd unpriced
    if [[ -z "$path" ]]; then
        printf 'unavailable (session has no transcript path)'
        return
    fi
    if [[ ! -r "$path" ]]; then
        printf 'unavailable (transcript not readable: %s)' "$path"
        return
    fi
    row="$(usage_transcript_advisor_cost "$path")"
    if [[ -z "$row" ]]; then
        printf 'unavailable (transcript could not be parsed)'
        return
    fi
    IFS=$'\t' read -r passes usd unpriced <<<"$row"
    if [[ "$unpriced" -gt 0 ]]; then
        printf "incomplete -- \$%.4f for %s; %s could not be priced" \
            "$usd" "$(pass_count $((passes - unpriced)))" "$(pass_count "$unpriced")"
    else
        printf "\$%.4f (%s)" "$usd" "$(pass_count "$passes")"
    fi
}

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
printf 'advisor:  %s\n' "$(advisor_summary "$TRANSCRIPT_PATH")"
if [[ "$UNPRICED" -gt 0 ]]; then
    printf 'warning:  %s of %s snapshots used a model with no pricing.json entry; estimate is incomplete\n' \
        "$UNPRICED" "$SNAPSHOT_COUNT"
fi
