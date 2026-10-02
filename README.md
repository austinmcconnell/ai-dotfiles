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
installs the CLI tools it manages (kiro-cli, claude-code, codex casks; engram from its tap),
distributes skills/steering to each agent, and symlinks each tool's config into place.

### Standalone vs. colocated with dotfiles

The AI tooling resolves its root from `AI_DOTFILES_DIR`, defaulting to `$HOME/.dotfiles` when unset:

- **Standalone** (this repo): `install.sh` sets `AI_DOTFILES_DIR` to `~/.ai-dotfiles`.
- **Colocated**: the dotfiles `install.sh` sets `AI_DOTFILES_DIR` and sources these scripts.

Export `AI_DOTFILES_DIR` from your shell (`.zshenv`/`.zprofile`) so hooks and MCP servers see it —
not from a project dotenv (kiro-cli 2.24+ no longer auto-loads project dotenv files).

The self-update step (`git pull` on launch) only runs for a standalone git clone with a remote; set
`AI_DOTFILES_SKIP_SELF_UPDATE=1` to skip it.

## Documentation

- Repo-wide conventions for AI tools: [AGENTS.md](./AGENTS.md)
- Skill/steering/prompt distribution matrix: [etc/ai/README.md](./etc/ai/README.md)
- Kiro CLI custom agents, hooks, MCP: [etc/kiro-cli/README.md](./etc/kiro-cli/README.md)
- Claude Code permissions, hooks, personas: [etc/claude-code/README.md](./etc/claude-code/README.md)
- Cursor CLI permissions and MCP: [etc/cursor/README.md](./etc/cursor/README.md)

## Development

This repo carries its own `.pre-commit-config.yaml` with the AI-config validators
(`scripts/validate-*.sh`) plus formatting/lint hooks. Run before committing:

```shell
pre-commit run --all-files
```
