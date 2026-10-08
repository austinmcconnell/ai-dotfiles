# ai-dotfiles

Austin's personal, multi-tool AI coding configuration — shared skills, steering, and prompts plus
per-tool configs for Kiro CLI, Claude Code, Cursor, and Codex, and the engram persistent-memory
setup. Extracted from [dotfiles](https://github.com/austinmcconnell/dotfiles) so the AI surface
installs and versions on its own.

## Install

```shell
git clone https://github.com/austinmcconnell/ai-dotfiles.git ~/.ai-dotfiles
cd ~/.ai-dotfiles
./install.sh
```

`install.sh` is idempotent — safe to run repeatedly. It sets `AI_DOTFILES_DIR` to the repo root,
installs the CLI tools it manages (engram from its tap, plus the kiro-cli and claude-code casks),
distributes skills/steering to each agent, and symlinks each tool's config into place. Per-agent
installs follow `ENABLED_AGENTS` in `install/enabled-agents.sh`; only `claude-code` and `kiro-cli`
are enabled today (`codex` and `cursor` are commented out and skipped).

### Standalone vs. colocated with dotfiles

The AI tooling resolves its root from `AI_DOTFILES_DIR`, defaulting to `$HOME/.dotfiles` when unset:

- **Standalone** (this repo): `install.sh` sets `AI_DOTFILES_DIR` to `~/.ai-dotfiles`.
- **Colocated**: the dotfiles `install.sh` sets `AI_DOTFILES_DIR` and sources these scripts.

Export `AI_DOTFILES_DIR` from your shell (`.zshenv`/`.zprofile`) so hooks and MCP servers see it —
not from a project dotenv (kiro-cli 2.24+ no longer auto-loads project dotenv files).

The self-update step (`git pull` on launch) only runs for a standalone git clone with a remote; set
`AI_DOTFILES_SKIP_SELF_UPDATE=1` to skip it.

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

Directories without their own README:

| Directory     | What it holds                                     | How it is used                                                   |
| ------------- | ------------------------------------------------- | ---------------------------------------------------------------- |
| `bin/`        | `engram-hygiene`, `is-executable`, `trace-search` | Put on `PATH` by `install.sh`.                                   |
| `etc/codex/`  | `config.toml`                                     | Copied to `~/.codex/` by `install/codex.sh` (codex is disabled). |
| `etc/dprint/` | `dprint.jsonc`                                    | Passed to `dprint fmt` by the `dprint` pre-commit hook.          |
| `etc/taplo/`  | `taplo.toml`                                      | Passed to the `taplo-format` and `taplo-lint` pre-commit hooks.  |
| `etc/yaml/`   | `yamllint`                                        | Passed to the `yamllint` pre-commit hook.                        |

## Development

This repo carries its own `.pre-commit-config.yaml` with the AI-config validators
(`scripts/validate-*.sh`) plus formatting/lint hooks. Run before committing:

```shell
pre-commit run --all-files
```
