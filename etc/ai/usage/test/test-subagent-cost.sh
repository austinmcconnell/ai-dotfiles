#!/bin/bash
# Checks transcript-based subagent cost (lib.sh) and the value the subagent writer stores.
# Builds synthetic transcripts in a temp dir and writes to a temp usage DB, so the real
# ~/.claude and usage.db are never read or changed.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_DIR="$(dirname "$TEST_DIR")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export USAGE_DB_DIR="$WORK/db"

# shellcheck disable=SC1091
source "$USAGE_DIR/lib.sh"

FAILURES=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $name"
    else
        echo "FAIL  $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# One assistant record: requestId, model, version, usage object.
request() {
    jq -cn --arg id "$1" --arg model "$2" --arg version "$3" --argjson usage "$4" '{
        type: "assistant", requestId: $id, version: $version,
        message: {model: $model, usage: $usage}
    }'
}

# One assistant record whose usage carries an iterations array: requestId, model, version, the
# top-level usage object, the iterations JSON.
iter_request() {
    jq -cn --arg id "$1" --arg model "$2" --arg version "$3" --argjson usage "$4" \
        --argjson iterations "$5" '{
        type: "assistant", requestId: $id, version: $version,
        message: {model: $model, usage: ($usage + {iterations: $iterations})}
    }'
}

write_iteration_fixtures() {
    local dir="$WORK/fixtures"
    # Executor pass at the request model plus an advisor pass at its own, different model.
    iter_request I1 claude-sonnet-5-5 2.1.300 '{"input_tokens":1000,"output_tokens":500}' \
        '[{"type":"message","input_tokens":1000,"output_tokens":500},
            {"type":"advisor_message","model":"claude-opus-5-5",
                "input_tokens":100000,"output_tokens":1000}]' >"$dir/iter-advisor.jsonl"
    # Two Haiku passes of 60000 each: the top-level sum (120000) would cross the 100000 tier.
    iter_request I2 claude-haiku-5-5 2.1.300 '{"input_tokens":120000}' \
        '[{"type":"message","input_tokens":60000},{"type":"message","input_tokens":60000}]' \
        >"$dir/iter-per-pass-tier.jsonl"
    iter_request I3 claude-sonnet-5 2.1.300 '{"input_tokens":1}' \
        '[{"type":"message","input_tokens":1},{"type":"compaction","input_tokens":1}]' \
        >"$dir/iter-unknown-type.jsonl"
    iter_request I4 claude-sonnet-5 2.1.300 '{"input_tokens":1}' \
        '[{"type":"message","input_tokens":1},
            {"type":"advisor_message","model":"claude-unknown-9","input_tokens":1}]' \
        >"$dir/iter-advisor-unpriced.jsonl"
    iter_request I5 claude-sonnet-5 2.1.300 '{"input_tokens":1}' \
        '[{"type":"message","input_tokens":1},{"type":"advisor_message","input_tokens":1}]' \
        >"$dir/iter-advisor-no-model.jsonl"
    # The top-level split covers only the first pass while the top-level total sums both.
    iter_request I6 claude-sonnet-5 2.1.300 \
        '{"cache_creation_input_tokens":5894,"cache_creation":{"ephemeral_5m_input_tokens":836}}' \
        '[{"type":"message","cache_creation_input_tokens":836,
                "cache_creation":{"ephemeral_5m_input_tokens":836}},
            {"type":"message","cache_creation_input_tokens":5058,
                "cache_creation":{"ephemeral_5m_input_tokens":5058}}]' \
        >"$dir/iter-split-first-pass.jsonl"
    iter_request I7 claude-sonnet-5 2.1.300 '{"input_tokens":1000,"output_tokens":500}' '[]' \
        >"$dir/iter-empty-array.jsonl"
    jq -cn '{type: "assistant", requestId: "I8", version: "2.1.300",
        message: {model: "claude-sonnet-5",
            usage: {input_tokens: 1000, output_tokens: 500, iterations: {}}}}' \
        >"$dir/iter-object.jsonl"
}

write_fixtures() {
    local dir="$WORK/fixtures"
    mkdir -p "$dir"
    {
        # Streamed partial record first; the final record for R1 must win.
        request R1 claude-sonnet-5 2.1.300 '{"input_tokens":100,"output_tokens":100}'
        request R1 claude-sonnet-5 2.1.300 '{"input_tokens":1000,"output_tokens":500}'
        request R2 claude-sonnet-5 2.1.300 '{"cache_read_input_tokens":10000}'
        request R3 claude-sonnet-5 2.1.300 \
            '{"cache_creation_input_tokens":1000,
                "cache_creation":{"ephemeral_1h_input_tokens":1000}}'
        echo '{"type":"user","message":{"content":"ignored"}}'
    } >"$dir/normal.jsonl"
    request H1 claude-haiku-5-5 2.1.300 \
        '{"input_tokens":60000,"output_tokens":1000,"cache_read_input_tokens":50000}' \
        >"$dir/haiku-long.jsonl"
    request S1 claude-sonnet-5-5 2.1.200 '{"cache_read_input_tokens":100000}' \
        >"$dir/sonnet-old-version.jsonl"
    request S2 claude-sonnet-5-5 2.1.300 '{"cache_read_input_tokens":100000}' \
        >"$dir/sonnet-new-version.jsonl"
    request S3 claude-sonnet-5-5 "" '{"cache_read_input_tokens":100000}' \
        >"$dir/sonnet-no-version.jsonl"
    request S5 claude-sonnet-5-5 "" '{"input_tokens":1000}' \
        >"$dir/sonnet-no-version-no-read.jsonl"
    # Split-only cache writes: cache_creation_input_tokens is absent, so the tier test must
    # read the 5m/1h breakdown to see the prompt cross 100K.
    request H4 claude-haiku-5-5 2.1.300 \
        '{"input_tokens":60000,
            "cache_creation":{"ephemeral_1h_input_tokens":50000}}' \
        >"$dir/haiku-tier-split-write.jsonl"
    {
        request U1 claude-sonnet-5 2.1.300 '{"input_tokens":1}'
        request U2 claude-unknown-9 2.1.300 '{"input_tokens":1}'
    } >"$dir/unknown-model.jsonl"
    jq -cn '{type: "assistant", version: "2.1.300",
        message: {model: "claude-sonnet-5", usage: {input_tokens: 1}}}' \
        >"$dir/no-request-id.jsonl"
    {
        request R1 claude-sonnet-5 2.1.300 '{"input_tokens":1000,"output_tokens":500}'
        echo '{"type":"assistant","requestId":'
    } >"$dir/malformed.jsonl"
    request C1 claude-sonnet-5 2.1.300 \
        '{"cache_creation_input_tokens":1000,
            "cache_creation":{"ephemeral_5m_input_tokens":1000}}' >"$dir/write-5m-split.jsonl"
    request C2 claude-sonnet-5 2.1.300 '{"cache_creation_input_tokens":1000}' \
        >"$dir/write-5m-fallback.jsonl"
    request S4 claude-sonnet-5-5 2.1.296 '{"cache_read_input_tokens":100000}' \
        >"$dir/sonnet-boundary-version.jsonl"
    request H2 claude-haiku-5-5 2.1.300 '{"input_tokens":100000}' >"$dir/haiku-at-limit.jsonl"
    request H3 claude-haiku-5-5 2.1.300 '{"input_tokens":100001}' >"$dir/haiku-over-limit.jsonl"
    : >"$dir/empty.jsonl"
}

test_pricing() {
    local dir="$WORK/fixtures"
    check "sums last record per requestId, all rules" 0.0130000000 \
        "$(usage_transcript_cost "$dir/normal.jsonl")"
    check "haiku 5.5 long-context tier" 0.0350000000 \
        "$(usage_transcript_cost "$dir/haiku-long.jsonl")"
    check "sonnet 5.5 pre-2.1.296 cache read" 0.0200000000 \
        "$(usage_transcript_cost "$dir/sonnet-old-version.jsonl")"
    check "sonnet 5.5 post-2.1.296 cache read" 0.0100000000 \
        "$(usage_transcript_cost "$dir/sonnet-new-version.jsonl")"
    check "sonnet 5.5 missing version refuses to price cache reads" "" \
        "$(usage_transcript_cost "$dir/sonnet-no-version.jsonl")"
    # No cache reads, so the unresolvable multiplier is never applied: 1000 * $2.0/Mtok / 1e6
    check "sonnet 5.5 missing version still prices a read-free request" 0.0020000000 \
        "$(usage_transcript_cost "$dir/sonnet-no-version-no-read.jsonl")"
    # Tier test must use the 5m/1h split, not cache_creation_input_tokens, which is absent here.
    # Prompt = 60000 + 50000 = 110000 > 100000, so long-context $0.5/Mtok applies to the whole
    # request: (60000 * 0.5) + (50000 * 0.5 * 2.0) / 1e6 = (30000 + 50000) / 1e6 = 0.08
    check "haiku 5.5 tier counts split cache writes toward the prompt" 0.0800000000 \
        "$(usage_transcript_cost "$dir/haiku-tier-split-write.jsonl")"
    # 1000 write tokens * $2.0/Mtok * 1.25 (5m) / 1e6 = 2500 / 1e6 = 0.0025
    check "5m cache write, explicit split" 0.0025000000 \
        "$(usage_transcript_cost "$dir/write-5m-split.jsonl")"
    # No cache_creation object: all 1000 tokens treated as 5m, same 1000 * 2.0 * 1.25 / 1e6 = 0.0025
    check "5m cache write, fallback without split" 0.0025000000 \
        "$(usage_transcript_cost "$dir/write-5m-fallback.jsonl")"
    # Version == 2.1.296 is not < 2.1.296, so new multiplier 0.05:
    # 100000 * $2.0/Mtok * 0.05 / 1e6 = 10000 / 1e6 = 0.01
    check "sonnet 5.5 version equal to boundary uses new multiplier" 0.0100000000 \
        "$(usage_transcript_cost "$dir/sonnet-boundary-version.jsonl")"
    # 100000 is not > 100000, so base rate $0.1/Mtok: 100000 * 0.1 / 1e6 = 0.01
    check "haiku 5.5 at long-context threshold stays base" 0.0100000000 \
        "$(usage_transcript_cost "$dir/haiku-at-limit.jsonl")"
    # 100001 > 100000, long-context rate $0.5/Mtok: 100001 * 0.5 / 1e6 = 50000.5 / 1e6 = 0.0500005
    check "haiku 5.5 just over long-context threshold" 0.0500005000 \
        "$(usage_transcript_cost "$dir/haiku-over-limit.jsonl")"
    check "unknown model prints nothing" "" "$(usage_transcript_cost "$dir/unknown-model.jsonl")"
    check "missing requestId prints nothing" "" \
        "$(usage_transcript_cost "$dir/no-request-id.jsonl")"
    check "malformed line skipped" 0.0070000000 "$(usage_transcript_cost "$dir/malformed.jsonl")"
    check "empty file prints nothing" "" "$(usage_transcript_cost "$dir/empty.jsonl")"
    check "missing file prints nothing" "" "$(usage_transcript_cost "$dir/absent.jsonl")"
    check "subagent path from parent transcript" \
        "/x/proj/sess/subagents/agent-t1.jsonl" \
        "$(usage_subagent_transcript_path /x/proj/sess.jsonl t1)"
    check "subagent path without parent prints nothing" "" \
        "$(usage_subagent_transcript_path "" t1)"
}

test_iterations() {
    local dir="$WORK/fixtures"
    # Message pass at sonnet-5-5: (1000 * 2.0 + 500 * 10.0) / 1e6 = 0.007
    # Advisor pass at opus-5-5: (100000 * 4.0 + 1000 * 20.0) / 1e6 = 0.42
    check "advisor pass priced at its own model on top of the message pass" 0.4270000000 \
        "$(usage_transcript_cost "$dir/iter-advisor.jsonl")"
    # Each pass is 60000 <= 100000 so base rate 0.1: 2 * 60000 * 0.1 / 1e6 = 0.012
    check "long-context tier is checked per pass, not on the summed passes" 0.0120000000 \
        "$(usage_transcript_cost "$dir/iter-per-pass-tier.jsonl")"
    check "unknown iteration type leaves the transcript unpriced" "" \
        "$(usage_transcript_cost "$dir/iter-unknown-type.jsonl")"
    check "advisor pass with an unpriced model leaves the transcript unpriced" "" \
        "$(usage_transcript_cost "$dir/iter-advisor-unpriced.jsonl")"
    check "advisor pass without a model leaves the transcript unpriced" "" \
        "$(usage_transcript_cost "$dir/iter-advisor-no-model.jsonl")"
    # Both passes' 5m writes count: (836 + 5058) * 2.0 * 1.25 / 1e6 = 0.014735
    check "each pass's own cache-write split is priced" 0.0147350000 \
        "$(usage_transcript_cost "$dir/iter-split-first-pass.jsonl")"
    # An empty or non-array iterations field must not price the request at zero:
    # (1000 * 2.0 + 500 * 10.0) / 1e6 = 0.007 from top-level usage
    check "empty iterations array falls back to top-level usage" 0.0070000000 \
        "$(usage_transcript_cost "$dir/iter-empty-array.jsonl")"
    check "non-array iterations field falls back to top-level usage" 0.0070000000 \
        "$(usage_transcript_cost "$dir/iter-object.jsonl")"
}

payload() {
    jq -cn --arg parent "$PARENT" --arg id "$1" '{
        session_id: "sess", transcript_path: $parent,
        tasks: [{id: $id, label: "l", agentType: "a", model: "claude-sonnet-5", tokenCount: 1234,
            contextWindowSize: 200000, startTime: 1700000000000, status: "completed"}]
    }'
}

payload_two_tasks() {
    jq -cn --arg parent "$PARENT" --arg a "$1" --arg b "$2" '{
        session_id: "sess", transcript_path: $parent,
        tasks: [$a, $b] | map({id: ., label: "l", agentType: "a", model: "claude-sonnet-5",
            tokenCount: 1234, contextWindowSize: 200000, startTime: 1700000000000,
            status: "completed"})
    }'
}

run_writer() {
    local rc=0 out
    out="$(payload "$1" | bash "$USAGE_DIR/claude-subagent-statusline.sh")" || rc=$?
    check "writer exit code ($1)" "0" "$rc"
    check "writer prints nothing ($1)" "" "$out"
}

stored() {
    sqlite3 "$USAGE_DB_DIR/usage.db" \
        "SELECT quote(estimated_cost_usd) FROM subagent_tasks WHERE task_id = '$1'"
}

test_writer() {
    local project="$WORK/proj"
    local subagent="$project/sess/subagents/agent-t1.jsonl"
    mkdir -p "$project/sess/subagents"
    cp "$WORK/fixtures/normal.jsonl" "$subagent"
    PARENT="$project/sess.jsonl"

    run_writer t1
    check "stored cost from transcript" "0.013" "$(stored t1)"

    run_writer t2
    check "missing transcript stored as NULL" "NULL" "$(stored t2)"

    rm "$subagent"
    run_writer t1
    check "read failure keeps prior value" "0.013" "$(stored t1)"

    cp "$WORK/fixtures/normal.jsonl" "$subagent"
    printf '%s\n' '{"type":"assistant","requestId":' >>"$subagent"
    run_writer t1
    check "partial last line keeps total" "0.013" "$(stored t1)"

    # A firing that reads a cheaper, fully-priceable transcript for a task already stored
    # higher must not lower it.
    cp "$WORK/fixtures/write-5m-split.jsonl" "$subagent"
    run_writer t1
    check "cheaper later reading keeps the higher total" "0.013" "$(stored t1)"

    cp "$WORK/fixtures/normal.jsonl" "$project/sess/subagents/agent-t3.jsonl"
    cp "$WORK/fixtures/sonnet-new-version.jsonl" "$project/sess/subagents/agent-t4.jsonl"
    payload_two_tasks t3 t4 | bash "$USAGE_DIR/claude-subagent-statusline.sh" >/dev/null
    check "two-task payload stores first task" "0.013" "$(stored t3)"
    # 100000 cache-read * $2.0/Mtok * 0.05 / 1e6 = 0.01
    check "two-task payload stores second task" "0.01" "$(stored t4)"
}

# Payload for one task whose description is the JSON text in $2, or left out when $2 is "absent".
# The label differs from the description, as it does while a subagent is working.
payload_description() {
    jq -cn --arg parent "$PARENT" --arg id "$1" --arg desc "$2" '{
        session_id: "sess", transcript_path: $parent,
        tasks: [{id: $id, label: "activity", agentType: "a", model: "claude-sonnet-5",
            tokenCount: 1234, contextWindowSize: 200000, startTime: 1700000000000,
            status: "completed"}
            + (if $desc == "absent" then {} else {description: ($desc | fromjson)} end)]
    }'
}

stored_name() {
    sqlite3 "$USAGE_DB_DIR/usage.db" \
        "SELECT quote(name) FROM subagent_tasks WHERE task_id = '$1'"
}

test_writer_name() {
    PARENT="$WORK/proj/sess.jsonl"
    local rows_before rows_after

    payload_description n1 '"Launch description"' | bash "$USAGE_DIR/claude-subagent-statusline.sh"
    check "name is the launch description, not the label" "'Launch description'" \
        "$(stored_name n1)"

    payload_description n1 absent | bash "$USAGE_DIR/claude-subagent-statusline.sh"
    check "a firing without a description keeps the stored name" "'Launch description'" \
        "$(stored_name n1)"

    payload_description n1 '""' | bash "$USAGE_DIR/claude-subagent-statusline.sh"
    check "a firing with an empty description keeps the stored name" "'Launch description'" \
        "$(stored_name n1)"

    payload_description n2 absent | bash "$USAGE_DIR/claude-subagent-statusline.sh"
    check "a new task without a description has no name" "NULL" "$(stored_name n2)"

    rows_before="$(sqlite3 "$USAGE_DB_DIR/usage.db" 'SELECT count(*) FROM subagent_tasks')"
    payload_description n3 '"one\ntwo\u001fthree\r"' |
        bash "$USAGE_DIR/claude-subagent-statusline.sh"
    rows_after="$(sqlite3 "$USAGE_DB_DIR/usage.db" 'SELECT count(*) FROM subagent_tasks')"
    check "a description with line breaks adds one row" "$((rows_before + 1))" "$rows_after"
    check "line breaks and unit separators in a description become spaces" "'one two three '" \
        "$(stored_name n3)"
}

write_fixtures
write_iteration_fixtures
test_pricing
test_iterations
test_writer
test_writer_name

if [[ "$FAILURES" -gt 0 ]]; then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "all checks passed"
