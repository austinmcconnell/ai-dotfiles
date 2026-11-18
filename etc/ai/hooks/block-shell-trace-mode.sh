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
#   - `set` with an x in a short-flag cluster among its options (set -x, set -eux,
#     set -Eeuxo pipefail, set -e -x)
#   - `set -o xtrace` / `set +o xtrace`, also after other options (set -u -o xtrace)
#   - a shell interpreter invoked with an x trace flag among its leading options (bash -x,
#     sh -x, bash -ex, bash -o pipefail -x, bash --norc -x, bash -o xtrace), including piped,
#     chained, path, and subshell forms (... | bash -x, foo && set -x, /bin/bash -x,
#     $(bash -x ...))
#
# Only option words may sit between the interpreter and the trace flag, so an x-bearing word in a
# `-c` command string or after the script name (bash -c "find . -maxdepth 2", bash s.sh -lx) is
# not a trace.
#
# Known limitation (accepted): a trace hidden inside a quoted string passed to `bash -c`
# (e.g. bash -c 'set -x; ...') is NOT detected. The goal is preventing the routine diagnosis
# mistake, not defeating a deliberate bypass.

set -euo pipefail

TOOL_INPUT=$(cat)
source "$(dirname "${BASH_SOURCE[0]}")/lib/hook-input.sh"
check_hook_input "${TOOL_INPUT}"

# Only the shell command field is actionable for this guard.
CMD=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$CMD" ]]; then
    exit 0
fi

# A command starts at the line start, a separator, whitespace, a subshell, or a backtick.
CMD_START='(^|[;&|[:space:](`])'
# An interpreter may also follow a path slash (/bin/bash); `set` may not (sed 's/set -x//').
INTERP_START='(^|[;&|[:space:]/(`])'
# A short-flag cluster containing x.
TRACE_FLAG='-[A-Za-wyz]*x[A-Za-z]*'
# One option word: a cluster ending in o or O with its option name, --rcfile or --init-file with
# its file, or any other short or long option.
OPTION_WORD='([-+][A-Za-z]*[oO][[:space:]]+[A-Za-z_]+|--(rcfile|init-file)[[:space:]]+[^[:space:]]+|[-+][^-[:space:]][^[:space:]]*|--[a-z-]+)'
# `set` whose options include an x cluster or the -o/+o xtrace long form (set -e -x,
# set -u -o xtrace).
SET_TRACE_RE="${CMD_START}set([[:space:]]+${OPTION_WORD})*[[:space:]]+(${TRACE_FLAG}|[-+][A-Za-z]*o[[:space:]]+xtrace)"
# A shell interpreter whose leading options include a trace flag.
SHELL_TRACE_RE="${INTERP_START}(bash|sh|zsh|dash|ksh)([[:space:]]+${OPTION_WORD})*[[:space:]]+(${TRACE_FLAG}|-[A-Za-z]*o[[:space:]]+xtrace)"

if echo "$CMD" | grep -qE "$SET_TRACE_RE" || echo "$CMD" | grep -qE "$SHELL_TRACE_RE"; then
    echo "BLOCKED: shell trace mode (bash -x / set -x) is not permitted — it prints every" >&2
    echo "         variable value in cleartext and can leak secrets or PII/PHI. Diagnose" >&2
    echo "         without a trace (capture output into vars, echo only non-secret state," >&2
    echo "         degrade to a SKIPPED line). If a trace is truly needed, ask the human to" >&2
    echo "         run it ad-hoc and paste back a redacted result." >&2
    exit 2
fi
