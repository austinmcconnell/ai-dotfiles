#!/bin/bash
# Checks the exit code each blocking hook returns for a tool-call payload: 2 blocks, 0 allows.
#
# Sensitive fixture strings (dot-env paths, key paths, credentials) are assembled at runtime. The
# hooks scan the strings of every tool call, so writing them literally into this file would trip the
# same hooks under test; credential fixtures also use example values to stay clear of secret
# scanners.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$(dirname "$TEST_DIR")"

FAILURES=0
# A PATH with the tools the hooks use, minus jq.
NO_JQ_BIN="$(mktemp -d)"
trap 'rm -rf "$NO_JQ_BIN"' EXIT
for tool in cat grep dirname basename; do
    ln -s "$(type -P "$tool")" "$NO_JQ_BIN/$tool"
done
DOT_ENV=".""env"
SSH_KEY_DIR=".""ssh/id_"
AWS_KEY="AKIA""IOSFODNN7EXAMPLE"
GITHUB_TOKEN="ghp_$(printf 'a%.0s' {1..36})"
PEM_HEADER="-----BEGIN ""RSA PRIVATE KEY-----"
ZERO_WIDTH_SPACE=$'\xe2\x80\x8b'

# $1 is the hook script, $2 the payload, $3 an optional PATH for the hook. Prints its exit code.
exit_code() {
    local status=0
    printf '%s' "$2" | PATH="${3:-$PATH}" "$HOOKS_DIR/$1" >/dev/null 2>&1 || status=$?
    echo "$status"
}

check() {
    local name="$1" hook="$2" expected="$3" payload="$4" actual
    actual="$(exit_code "$hook" "$payload" "${5:-}")"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $hook: $name"
    else
        echo "FAIL  $hook: $name: expected exit $expected, got $actual"
        FAILURES=$((FAILURES + 1))
    fi
}

bash_call() {
    jq --null-input --compact-output --arg command "$1" \
        '{tool_name: "Bash", tool_input: {command: $command}}'
}

read_call() {
    jq --null-input --compact-output --arg path "$1" \
        '{tool_name: "Read", tool_input: {file_path: $path}}'
}

# Kiro's fs_read passes paths inside an operations array.
kiro_read_call() {
    jq --null-input --compact-output --arg path "$1" \
        '{tool_name: "fs_read", tool_input: {operations: [{mode: "Line", path: $path}]}}'
}

# $1 is the file path, $2 the content.
write_call() {
    jq --null-input --compact-output --arg path "$1" --arg content "$2" \
        '{tool_name: "Write", tool_input: {file_path: $path, content: $content}}'
}

# $1 is the file path, $2 the new content.
edit_call() {
    jq --null-input --compact-output --arg path "$1" --arg content "$2" \
        '{tool_name: "Edit", tool_input: {file_path: $path, old_string: "old", new_string: $content}}'
}

# The built-in Grep tool: $1 is the pattern, $2 the search path.
grep_call() {
    jq --null-input --compact-output --arg pattern "$1" --arg path "$2" \
        '{tool_name: "Grep", tool_input: {pattern: $pattern, path: $path}}'
}

# $1 is the tool name as the tool sends it, $2 the memory content.
memory_call() {
    jq --null-input --compact-output --arg tool "$1" --arg content "$2" \
        '{tool_name: $tool, tool_input: {title: "note", content: $content}}'
}

# $1 is the persona's agent_type (empty for a main session), $2 the command.
persona_call() {
    jq --null-input --compact-output --arg agent "$1" --arg command "$2" \
        '{tool_name: "Bash", tool_input: {command: $command}}
        + (if $agent == "" then {} else {agent_type: $agent} end)'
}

hook=block-env-files.sh
check "reads a dot-env file" "$hook" 2 "$(read_call "/repo/$DOT_ENV")"
check "cats a suffixed dot-env file" "$hook" 2 "$(bash_call "cat config/$DOT_ENV.production")"
check "kiro reads a dot-env file" "$hook" 2 "$(kiro_read_call "/repo/$DOT_ENV.local")"
check "reads a README" "$hook" 0 "$(read_call "/repo/README.md")"
check "reads an envrc file" "$hook" 0 "$(read_call "/repo/${DOT_ENV}rc")"
check "reads a file named environment" "$hook" 0 "$(read_call "/repo/docs/environment.md")"
check "greps a dot-env file by name" "$hook" 2 "$(bash_call "grep KEY config/$DOT_ENV")"
check "built-in Grep names a dot-env path" "$hook" 2 "$(grep_call KEY "/repo/$DOT_ENV")"
check "built-in Grep pattern names a dot-env file" "$hook" 2 "$(grep_call "$DOT_ENV" "/repo/src")"

# Known false positives pin current behavior. When a hook change drops one, flip its expected exit
# code in the same commit.
check "ordinary recursive grep passes" "$hook" 0 "$(bash_call "grep -r KEY src/")"
check "known false positive: template file" "$hook" 2 "$(bash_call "cat config/$DOT_ENV.example")"
check "known false positive: prose in a markdown write" "$hook" 2 \
    "$(write_call notes.md "Never read the $DOT_ENV file.")"

REPO_ROOT="$(cd "$HOOKS_DIR/../../.." && pwd)"
ALLOWED_DOC="$REPO_ROOT/etc/ai/steering/security/env-file-protection.md"
check "allowlisted doc write may quote the guard" "$hook" 0 \
    "$(write_call "$ALLOWED_DOC" "Never read the $DOT_ENV file.")"
check "allowlisted doc edit may quote the guard" "$hook" 0 \
    "$(edit_call "$ALLOWED_DOC" "Never read the $DOT_ENV file.")"
check "allowlist ignores a suffixed path" "$hook" 2 \
    "$(write_call "$ALLOWED_DOC.bak" "Never read the $DOT_ENV file.")"
check "allowlist ignores a prefixed path" "$hook" 2 \
    "$(write_call "/other$ALLOWED_DOC" "Never read the $DOT_ENV file.")"
check "allowlist ignores a dot-dot path" "$hook" 2 \
    "$(write_call "$REPO_ROOT/etc/ai/steering/../steering/security/env-file-protection.md" "Never read the $DOT_ENV file.")"
check "allowlist never covers hooks" "$hook" 2 \
    "$(write_call "$REPO_ROOT/etc/ai/hooks/block-env-files.sh" "Never read the $DOT_ENV file.")"
check "allowlist never covers settings" "$hook" 2 \
    "$(write_call "$REPO_ROOT/etc/claude-code/settings.json" "Never read the $DOT_ENV file.")"
check "other tracked docs stay blocked" "$hook" 2 \
    "$(write_call "$REPO_ROOT/etc/ai/steering/code/git-conventions.md" "Never read the $DOT_ENV file.")"
check "write to a dot-env path stays blocked" "$hook" 2 \
    "$(write_call "$REPO_ROOT/config/$DOT_ENV" "KEY=fake")"
check "plain write to an unlisted path passes" "$hook" 0 \
    "$(write_call "$REPO_ROOT/notes.md" "plain text")"

hook=block-sops-age-files.sh
check "reads the age key file" "$hook" 2 "$(read_call "$HOME/.config/sops/age/keys.txt")"
check "reads an agekey file" "$hook" 2 "$(kiro_read_call "/keys/host.agekey")"
check "runs sops decrypt" "$hook" 2 "$(bash_call "sops decrypt secrets.enc.yaml")"
check "runs sops -d" "$hook" 2 "$(bash_call "sops -d secrets.enc.yaml")"
check "reads the sops config" "$hook" 0 "$(read_call "/repo/.sops.yaml")"
check "reads an encrypted file" "$hook" 0 "$(read_call "/repo/secrets.enc.yaml")"
check "runs sops encrypt" "$hook" 0 "$(bash_call "sops --encrypt secrets.yaml")"

hook=block-ssh-private-keys.sh
check "reads a private key" "$hook" 2 "$(read_call "$HOME/${SSH_KEY_DIR}ed25519")"
check "cats a private key" "$hook" 2 "$(bash_call "cat ~/${SSH_KEY_DIR}rsa")"
check "kiro reads a private key" "$hook" 2 "$(kiro_read_call "$HOME/${SSH_KEY_DIR}ecdsa")"
check "reads a public key" "$hook" 0 "$(read_call "$HOME/${SSH_KEY_DIR}ed25519.pub")"
check "reads the ssh config" "$hook" 0 "$(read_call "$HOME/.ssh/config")"
check "reads known_hosts" "$hook" 0 "$(read_call "$HOME/.ssh/known_hosts")"

hook=block-shell-trace-mode.sh
check "bash with -x" "$hook" 2 "$(bash_call "bash -""x script.sh")"
check "set -x before a command" "$hook" 2 "$(bash_call "set -""x; make")"
check "set with x in a flag cluster" "$hook" 2 "$(bash_call "set -eu""x")"
check "set -o xtrace" "$hook" 2 "$(bash_call "set -o x""trace")"
check "piped into sh -x" "$hook" 2 "$(bash_call "cat script.sh | sh -""x")"
check "bash -o xtrace" "$hook" 2 "$(bash_call "bash -o x""trace script.sh")"
check "bash without flags" "$hook" 0 "$(bash_call "bash script.sh")"
check "set -euo pipefail" "$hook" 0 "$(bash_call "set -euo pipefail")"
check "grep -x" "$hook" 0 "$(bash_call "grep -x pattern file")"
check "tar -xzf" "$hook" 0 "$(bash_call "tar -xzf archive.tgz")"
check "a call with no command" "$hook" 0 "$(read_call "/repo/README.md")"

for hook in block-env-files.sh block-sops-age-files.sh block-ssh-private-keys.sh \
    block-shell-trace-mode.sh; do
    check "payload that is not JSON" "$hook" 2 '{"tool_input": {"command": "cat'
    check "empty payload" "$hook" 0 ''
    check "null payload" "$hook" 0 'null'
    check "jq missing" "$hook" 2 "$(read_call "/repo/README.md")" "$NO_JQ_BIN"
done

hook=block-memory-secrets.sh
check "payload that is not JSON" "$hook" 2 '{"tool_name": "mcp__engram__mem_save"'
check "AWS key in a Claude save" "$hook" 2 "$(memory_call mcp__engram__mem_save "key $AWS_KEY")"
check "GitHub token in a kiro save" "$hook" 2 "$(memory_call @engram/mem_save "token $GITHUB_TOKEN")"
check "private key header in an update" "$hook" 2 "$(memory_call mcp__engram__mem_update "$PEM_HEADER")"
check "password assignment" "$hook" 2 "$(memory_call mcp__engram__mem_save "password: hunter2")"
check "zero-width character" "$hook" 2 "$(memory_call mcp__engram__mem_save "a${ZERO_WIDTH_SPACE}b")"
check "plain save" "$hook" 0 "$(memory_call mcp__engram__mem_save "Prefer tuned allow rules")"
check "AWS key in a search" "$hook" 0 "$(memory_call mcp__engram__mem_search "$AWS_KEY")"

hook=block-persona-shell-commands.sh
check "docs runs kubectl" "$hook" 2 "$(persona_call docs "kubectl get pods")"
check "docs chains docker" "$hook" 2 "$(persona_call docs "cd app && docker ps")"
check "jira installs a package" "$hook" 2 "$(persona_call jira "pip install requests")"
check "datadog deletes a monitor" "$hook" 2 "$(persona_call datadog "pup monitors delete 123")"
check "ansible runs ad hoc" "$hook" 2 "$(persona_call ansible "ansible all -m ping")"
check "main session runs kubectl" "$hook" 0 "$(persona_call "" "kubectl get pods")"
check "docs runs git" "$hook" 0 "$(persona_call docs "git status")"
check "ansible checks its version" "$hook" 0 "$(persona_call ansible "ansible --version")"
check "datadog lists monitors" "$hook" 0 "$(persona_call datadog "pup monitors list")"

# $1 is the hook script, $2 the payload. Prints the permissionDecision the hook asks for, or "none".
ask_decision() {
    local out
    out="$(printf '%s' "$2" | "$HOOKS_DIR/$1" 2>/dev/null |
        jq -r '.hookSpecificOutput.permissionDecision // empty')" || true
    echo "${out:-none}"
}

check_ask() {
    local name="$1" hook="$2" expected="$3" payload="$4" actual
    actual="$(ask_decision "$hook" "$payload")"
    if [[ "$expected" == "$actual" ]]; then
        echo "ok    $hook: $name"
    else
        echo "FAIL  $hook: $name: expected [$expected], got [$actual]"
        FAILURES=$((FAILURES + 1))
    fi
}

# $1 is the subagent_type, $2 an optional model.
agent_call() {
    jq --null-input --compact-output --arg type "$1" --arg model "${2:-}" \
        '{tool_name: "Agent", tool_input: ({subagent_type: $type}
            + (if $model == "" then {} else {model: $model} end))}'
}

hook=ask-opus-subagents.sh
check_ask "doubt-reviewer persona" "$hook" ask "$(agent_call doubt-reviewer)"
check_ask "opus alias" "$hook" ask "$(agent_call general-purpose opus)"
check_ask "full opus model id" "$hook" ask "$(agent_call Explore claude-opus-5-5)"
check_ask "fable alias" "$hook" ask "$(agent_call general-purpose fable)"
check_ask "full fable model id" "$hook" ask "$(agent_call general-purpose claude-fable-5-1)"
check_ask "upper-case model name" "$hook" ask "$(agent_call general-purpose OPUS)"
check_ask "doubt-reviewer on a cheap model" "$hook" ask "$(agent_call doubt-reviewer haiku)"
check_ask "sonnet model" "$hook" none "$(agent_call general-purpose sonnet)"
check_ask "haiku model" "$hook" none "$(agent_call Explore haiku)"
check_ask "no model set" "$hook" none "$(agent_call general-purpose)"
check_ask "another persona" "$hook" none "$(agent_call docs)"
check_ask "a call that is not an Agent launch" "$hook" none "$(read_call "/repo/README.md")"
check "payload that is not JSON" "$hook" 2 '{"tool_input": {"model": "opus"'
check "empty payload" "$hook" 0 ''
check "null payload" "$hook" 0 'null'
check "jq missing" "$hook" 2 "$(agent_call doubt-reviewer)" "$NO_JQ_BIN"

if ((FAILURES > 0)); then
    echo "$FAILURES check(s) failed"
    exit 1
fi
echo "All hook checks passed"
