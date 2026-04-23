# Shell Script Conventions

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
