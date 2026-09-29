---
paths:
  - '**/*.sh'
  - '**/*.bash'
  - install/**
---

# Shell Conventions

## Agent Shell Tool Usage

- Use the `working_dir` parameter instead of prefixing commands with `cd`. Write
  `cat file.md > out.md` with `working_dir` set, not `cd /path && cat file.md > out.md`.
- Never diagnose a script with `bash -x` / `set -x` (trace mode) when it reads secrets or PII/PHI
  from the environment — trace mode expands every variable and prints their values in cleartext,
  defeating a script's no-secret-output design. Diagnose instead by capturing command output into
  variables, echoing only non-secret state, and making the script degrade gracefully (e.g. a
  `SKIPPED` line) so a trace is never needed. If a trace is genuinely unavoidable, unset or redact
  the secret-bearing variables first. A `block-shell-trace-mode.sh` preToolUse hook hard-blocks
  agent-run trace mode; run any needed trace yourself and paste back the (redacted) result.

## Formatting (enforced by pre-commit)

- 4-space indentation (shfmt)
- Max line length: 100 characters (bashate)
- Executables must have shebangs (check-executables-have-shebangs)
- shfmt, shellcheck, and bashate run on bash scripts only, not zsh

## Bash Scripts

- Shebang: `#!/bin/bash`
- Always set `set -euo pipefail` after the shebang
- Quote all variable expansions: `"${var}"` not `$var`
- Use `[[ ]]` over `[ ]` for conditionals
- Use `$(command)` over backticks
- Locate external tools dynamically (`command -v <tool>`, `brew --prefix`) or against a checked-in
  expected value — never hardcode a version- or machine-specific path (e.g. a pinned
  `Cellar/<tool>/<version>/` path). Hardcoded paths rot silently across upgrades and machines; fail
  loudly or skip with a note when the tool is absent, never silently pass.
- shellcheck directive `disable=SC1091` is set globally (sourced file not found)

## Zsh Autoloaded Functions

- Files in `etc/zsh/functions/` have NO shebang and NO function wrapper
- The function body is the entire file content — the filename IS the function name
- Not checked by shfmt/shellcheck/bashate (zsh excluded from all three)

## Install Scripts

- Source `install/utils.sh` for helpers (`print_header`, `is-macos`, `is-debian`)
- Must be idempotent — safe to run repeatedly
- Check for existing installations before reinstalling
- Handle both macOS and Linux where applicable

## Naming

- `snake_case` for local variables and functions
- `UPPER_CASE` for exported variables and constants
- `local` for function-scoped variables in Bash
- Prefer long-form flags in scripts (`--recursive` over `-r`)
