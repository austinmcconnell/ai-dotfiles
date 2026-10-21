# Scripts

Repo maintenance scripts: pre-commit validators, a persona generator, a settings formatter, and one
shell function. Nothing here is installed to a tool config directory. Run from the repo root.

All seven `validate-*.sh` scripts, plus `sort-claude-settings-json.sh`, are registered as
`repo: local` hooks in `.pre-commit-config.yaml` with `pass_filenames: false`, so each runs once
over the whole repo when a file matching its `files:` pattern changes. Run them all with
`pre-commit run --all-files`.

## Validators

Each validator generates and rewrites nothing; it exits non-zero on drift.

| Script                            | What it checks                                                                                                                   | How it is run                             |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `validate-agent-denies.sh`        | The shared deny and allow command lists are present and identical across every `etc/kiro-cli/cli-agents/*.json`.                 | pre-commit `validate-agent-denies`        |
| `validate-claude-path-rules.sh`   | `etc/claude-code/settings.json` has no `Read`/`Edit`/`Write` rule with a single leading slash (needs `//`).                      | pre-commit `validate-claude-path-rules`   |
| `validate-hook-wiring.sh`         | Shared hooks in `etc/ai/hooks/` are wired consistently between the kiro agents and Claude Code.                                  | pre-commit `validate-hook-wiring`         |
| `validate-kiro-steering-globs.sh` | Steering docs sit one level deep in their domain so the per-domain kiro `file://` globs resolve.                                 | pre-commit `validate-kiro-steering-globs` |
| `validate-mcp-server-parity.sh`   | `command` and `args` for `engram` and `jira` match between the kiro configs and `install/claude-code.sh`.                        | pre-commit `validate-mcp-server-parity`   |
| `validate-memory-types.sh`        | The engram memory-type vocabulary and handoff convention in `memory-management/SKILL.md`.                                        | pre-commit `validate-memory-types`        |
| `validate-persona-steering.sh`    | Each Claude persona in `install/persona-domains.sh` has a source file and steering; runs `generate-personas.sh` into a temp dir. | pre-commit `validate-persona-steering`    |

## Other scripts

| Script                         | What it does                                                                                                                              | How it is run                                                                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `generate-personas.sh`         | Writes each Claude persona (`etc/claude-code/agents/<name>.md`) with its steering docs inlined, into the directory given as its argument. | `install/claude-code.sh` (`generate-personas.sh "$CLAUDE_DIR/agents"`); also run by `validate-persona-steering.sh`.                                              |
| `sort-claude-settings-json.sh` | Restores `etc/claude-code/settings.json` to a canonical top-level key order; nested objects are untouched.                                | pre-commit `sort-claude-settings-json`, or `./scripts/sort-claude-settings-json.sh [path]`.                                                                      |
| `ai-prompt.sh`                 | Defines the `ai-prompt` shell function (`save`, `use`, `list`, `show`, `edit`, `delete`, `help`) over `etc/ai/prompts/`.                  | Not executable. No caller found in `install.sh`, `install/`, `bin/`, `.pre-commit-config.yaml`, or `scripts/`; the function must be sourced from a shell config. |

## Notes

- `ai-prompt.sh` locates prompts at `${AI_DOTFILES_DIR:-$HOME/.dotfiles}/etc/ai/prompts`.
