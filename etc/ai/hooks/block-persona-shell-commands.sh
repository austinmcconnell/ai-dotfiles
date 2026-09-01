#!/bin/bash
set -euo pipefail
# Block operational shell command patterns per Claude persona, mirroring
# kiro-cli's per-agent toolsSettings.shell.deniedCommands for aws/docker/
# kubectl/ssh/package-manager installs and agent-specific destructive
# commands.
#
# Security-pattern denies (.env, sops/age, ssh keys) are intentionally NOT
# duplicated here: block-env-files.sh, block-sops-age-files.sh, and
# block-ssh-private-keys.sh already cover those globally on both tools.
#
# Wired as a PreToolUse hook (matcher: Bash) in each persona's own `hooks:`
# frontmatter block (etc/claude-code/agents/<persona>.md), invoked with the
# persona name as $1:
#   $AI_DOTFILES_DIR/etc/ai/hooks/block-persona-shell-commands.sh docs
#
# Safety: grep runs inside `if` (errexit suppressed there); the empty-command
# early exit avoids testing patterns against nothing.

PERSONA="${1:-}"
TOOL_INPUT=$(cat)
CMD=$(echo "${TOOL_INPUT}" | jq -r '.tool_input.command // empty' 2>/dev/null)

[[ -z "${CMD}" ]] && exit 0

case "${PERSONA}" in
docs)
    PATTERNS=('docker .*' 'kubectl .*')
    ;;
jira)
    PATTERNS=('aws .*' 'brew install .*' 'cp .*' 'docker .*' 'kubectl .*' 'npm install .*' 'pip install .*')
    ;;
datadog)
    PATTERNS=('pup .*(create|update|delete|edit|mute|unmute).*' 'pup auth (login|logout|refresh).*' 'aws .*' 'brew install .*' 'docker .*' 'kubectl .*' 'npm install .*' 'pip install .*' 'ssh .*')
    ;;
ansible)
    PATTERNS=('ansible [^-].*' 'ansible-console .*' 'ansible-pull .*' 'ansible-vault (create|decrypt|edit|encrypt|rekey) .*' 'brew install .*' 'docker (exec|kill|rm|rmi|run|stop|system prune|volume rm|network rm) .*' 'kubectl .*' 'npm install .*' 'pip install .*' 'ssh .*')
    ;;
*)
    exit 0
    ;;
esac

for pattern in "${PATTERNS[@]}"; do
    if echo "${CMD}" | grep -qE "(^|[;&|][[:space:]]*)${pattern}"; then
        echo "BLOCKED: the '${PERSONA}' persona denies this command pattern (mirrors kiro-cli's shell.deniedCommands): ${pattern}" >&2
        exit 2
    fi
done

exit 0
