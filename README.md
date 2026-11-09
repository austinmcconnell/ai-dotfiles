# ai-dotfiles

Austin's personal, multi-tool AI coding configuration — shared skills, steering, and prompts plus
per-tool configs for Kiro CLI, Claude Code, Cursor, and Codex, and the engram persistent-memory
setup. Extracted from [dotfiles](https://github.com/austinmcconnell/dotfiles) so the AI surface
installs and versions on its own.

## Install

Requires [Homebrew](https://brew.sh): the installer uses `brew` to install engram and the kiro-cli
and claude-code casks.

```shell
git clone https://github.com/austinmcconnell/ai-dotfiles.git ~/.ai-dotfiles
cd ~/.ai-dotfiles
./install.sh
```

`install.sh` is idempotent — safe to run repeatedly. It sets `AI_DOTFILES_DIR` to the repo root,
installs the CLI tools it manages (engram from its tap, plus the kiro-cli and claude-code casks),
distributes skills/steering to each agent, and symlinks each tool's config into place. Per-agent
installs follow `ENABLED_AGENTS`; see [install/README.md](./install/README.md) for which agents are
enabled and how to change that.

### Repo root (`AI_DOTFILES_DIR`)

The AI tooling resolves its root from `AI_DOTFILES_DIR`. When it is unset, install and validation
scripts use the repo they live in, and hooks and shell helpers use `$HOME/.ai-dotfiles`. A dotfiles
`install.sh` may also set `AI_DOTFILES_DIR` and source `install.sh` from this repo.

Export `AI_DOTFILES_DIR` from your shell (`.zshenv`/`.zprofile`) so hooks and MCP servers see it —
not from a project dotenv (kiro-cli 2.24+ no longer auto-loads project dotenv files).

The self-update step (`git pull` on launch) only runs for a standalone git clone with a remote; set
`AI_DOTFILES_SKIP_SELF_UPDATE=1` to skip it.

## How the pieces fit

The repo is a personal config, not a configurable framework, but its pieces work together as a
lightweight harness around each AI tool. No orchestrator drives the work: each layer below shapes
one part of how an agent behaves, and the person in the session decides when to move from planning
to implementation and which model runs each step.

| Layer                          | Role                                                                                     | Where it lives                                                                                                                            |
| ------------------------------ | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Steering                       | Always-on policy: conventions, guardrails, which skill to load when                      | `etc/ai/steering/` ([etc/ai/README.md](./etc/ai/README.md))                                                                               |
| Skills                         | Step-by-step procedures loaded on demand (commit cadence, reviews)                       | `etc/ai/skills/` ([etc/ai/README.md](./etc/ai/README.md))                                                                                 |
| Personas                       | Scoped agents, including the strongest-model `doubt-reviewer`                            | `etc/claude-code/agents/`, `etc/kiro-cli/cli-agents/`                                                                                     |
| Hooks, permissions, pre-commit | Enforcement: block secret access, gate costly or outward actions, validate config        | [etc/ai/hooks/README.md](./etc/ai/hooks/README.md), [etc/claude-code/README.md](./etc/claude-code/README.md), [Development](#development) |
| engram                         | Cross-session memory: decisions, corrections, handoffs                                   | [etc/ai/steering/shared/cross-session-memory.md](./etc/ai/steering/shared/cross-session-memory.md)                                        |
| Working files                  | Work queue: `ideas.md` → `backlog.md` → `todo.md`, kept out of git by a global gitignore | [etc/ai/skills/shared/idea-refinement/SKILL.md](./etc/ai/skills/shared/idea-refinement/SKILL.md)                                          |

Which model runs each step, and why, is in
[etc/ai/steering/shared/model-gates.md](./etc/ai/steering/shared/model-gates.md).

## Directory map

- Repo-wide conventions for AI tools: [AGENTS.md](./AGENTS.md)
- Skill/steering/prompt distribution matrix: [etc/ai/README.md](./etc/ai/README.md)
- Reusable prompts and the `ai-prompt` commands:
  [etc/ai/prompts/README.md](./etc/ai/prompts/README.md)
- Shared hook scripts and where each is wired: [etc/ai/hooks/README.md](./etc/ai/hooks/README.md)
- Token/cost tracking store and statusline scripts:
  [etc/ai/usage/README.md](./etc/ai/usage/README.md)
- Kiro CLI custom agents, hooks, MCP: [etc/kiro-cli/README.md](./etc/kiro-cli/README.md)
- Claude Code permissions, hooks, personas: [etc/claude-code/README.md](./etc/claude-code/README.md)
- Cursor CLI permissions and MCP: [etc/cursor/README.md](./etc/cursor/README.md)
- Install scripts and their order: [install/README.md](./install/README.md)
- Validators, persona generator, and `ai-prompt.sh`: [scripts/README.md](./scripts/README.md)
- Commands on `PATH` (`ai-usage`, `engram-hygiene`, `trace-search`):
  [bin/README.md](./bin/README.md)

Directories without their own README:

| Directory     | What it holds                        | How it is used                                                                                      |
| ------------- | ------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `etc/codex/`  | `config.toml`                        | Copied to `~/.codex/` by `install/codex.sh` (codex is disabled).                                    |
| `etc/dprint/` | `dprint.jsonc`                       | Passed to `dprint fmt` by the `dprint` pre-commit hook.                                             |
| `etc/taplo/`  | `taplo.toml`                         | Passed to the `taplo-format` and `taplo-lint` pre-commit hooks.                                     |
| `etc/yaml/`   | `yamllint`                           | Passed to the `yamllint` pre-commit hook.                                                           |
| `etc/zsh/`    | `init.zsh`, `completions/_ai-prompt` | Sourced from an interactive zsh config; see [etc/ai/prompts/README.md](./etc/ai/prompts/README.md). |

## Development

This repo carries its own `.pre-commit-config.yaml` with the AI-config validators
(`scripts/validate-*.sh`) plus formatting/lint hooks. Run before committing:

```shell
pre-commit run --all-files
```
