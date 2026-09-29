#!/bin/bash
# Block any tool from running shell trace mode (bash -x / set -x).
# Shared hook: works with kiro-cli (preToolUse) and Claude Code (PreToolUse)
#
# Why: trace mode expands every variable and prints its value in cleartext. Running it against a
# script that reads secrets or PII/PHI from the environment dumps those values to the console,
# defeating a script's no-secret-output design. This is a hard block: diagnose gracefully instead
# (capture output into variables, echo only non-secret state, degrade to a SKIPPED line). If a
# trace is genuinely needed, the human runs it ad-hoc and pastes back the redacted result.
#
# Blocked patterns:
#   - `set` with an x in its short-flag cluster (set -x, set -ex, set -eux, set -xe)
#   - `set -o xtrace` / `set +o xtrace`
#   - a shell interpreter invoked with an x trace flag (bash -x, sh -x, zsh -x, bash -ex,
#     bash -o xtrace), including piped/chained forms (... | bash -x, foo && set -x)
#
# Known limitation (accepted): a trace hidden inside a quoted string passed to `bash -c`
# (e.g. bash -c 'set -x; ...') is NOT detected. The goal is preventing the routine diagnosis
# mistake, not defeating a deliberate bypass.

set -euo pipefail

TOOL_INPUT=$(cat)

# Only the shell command field is actionable for this guard.
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$CMD" ]]; then
    exit 0
fi

# `set` enabling xtrace: short-flag cluster containing x, or the -o/+o xtrace long form.
SET_TRACE_RE='(^|[;&|[:space:]])set[[:space:]]+(-[a-wyz]*x[a-z]*|[-+]o[[:space:]]+xtrace)'
# A shell interpreter invoked with an x trace flag (short cluster or -o xtrace).
SHELL_TRACE_RE='(^|[;&|[:space:]])(bash|sh|zsh|dash|ksh)[[:space:]]+([^|;&]*[[:space:]])?(-[a-wyz]*x[a-z]*|-o[[:space:]]+xtrace)'

if echo "$CMD" | grep -qE "$SET_TRACE_RE" || echo "$CMD" | grep -qE "$SHELL_TRACE_RE"; then
    echo "BLOCKED: shell trace mode (bash -x / set -x) is not permitted — it prints every" >&2
    echo "         variable value in cleartext and can leak secrets or PII/PHI. Diagnose" >&2
    echo "         without a trace (capture output into vars, echo only non-secret state," >&2
    echo "         degrade to a SKIPPED line). If a trace is truly needed, ask the human to" >&2
    echo "         run it ad-hoc and paste back a redacted result." >&2
    exit 2
fi
