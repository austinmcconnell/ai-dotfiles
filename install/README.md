# Install Scripts

Scripts sourced by `install.sh` at the repo root. None is meant to be run directly: they depend on
`AI_DOTFILES_DIR` and the helpers from `utils.sh`, which `install.sh` sets up before sourcing them.

## Order

`install.sh` runs these steps in order (self-update first, when eligible):

1. `extra-sources.sh` — writes the `~/.extra` source templates (see
   [Host-local source files](#host-local-source-files)).
1. `ai-tools.sh` — distributes skills and steering to every enabled agent.
1. `kiro-cli.sh` (via `install_agent`)
1. `engram.sh` (always runs)
1. `codex.sh` (via `install_agent`)
1. `cursor.sh` (via `install_agent`)
1. `claude-code.sh` (via `install_agent`)

`install_agent <name>` sources `install/<name>.sh` only when `<name>` is in `ENABLED_AGENTS`
(`enabled-agents.sh`) and otherwise logs "Skipping … (not in ENABLED_AGENTS)". Currently enabled:
`claude-code` and `kiro-cli`; the other entries in the array are commented out. Re-enable one by
uncommenting it and re-running `install.sh`; disabling an agent stops future installs and removes
nothing.

## Scripts

| Script               | What it does                                                                                                                                                                                                                                                  | How it is run                                                                            |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `utils.sh`           | Logging helpers, `print_section_header`, and the Homebrew helpers (`init_brew_cache`, `install_if_needed`, `tap_if_needed`, ...).                                                                                                                             | Sourced by `install.sh` and by the per-agent scripts.                                    |
| `enabled-agents.sh`  | Defines `ENABLED_AGENTS` and `agent_enabled`.                                                                                                                                                                                                                 | Sourced by `install.sh` and `ai-tools.sh`.                                               |
| `extra-sources.sh`   | Writes `~/.extra/skill-sources.example` and `~/.extra/steering-sources.example`, refreshing them when the templates change. Never writes the live files.                                                                                                      | Sourced by `install.sh` before `ai-tools.sh`.                                            |
| `ai-tools.sh`        | Symlinks `etc/ai/skills` into each enabled agent's skills path and builds each agent's steering output (kiro steering tree, Claude `rules/` plus `CLAUDE.md`, Cursor `.mdc`, or a single file).                                                               | Sourced by `install.sh` before the per-agent scripts. Holds the `agent_config` registry. |
| `kiro-cli.sh`        | Installs the `kiro-cli` cask, symlinks `etc/kiro-cli/settings/{cli,mcp}.json` and each file in `etc/kiro-cli/cli-agents/` into `~/.kiro/`, installs the npm MCP servers when `npm` exists, and clones seven `geerlingguy` repos into `~/sources/geerlingguy`. | `install_agent kiro-cli`.                                                                |
| `claude-code.sh`     | Installs the `claude-code` cask, symlinks `etc/claude-code/settings.json`, runs `scripts/generate-personas.sh` into `~/.claude/agents`, and merges `engram` and `jira` into `~/.claude.json` with `jq`.                                                       | `install_agent claude-code`.                                                             |
| `codex.sh`           | Installs the `codex` cask and copies `etc/codex/config.toml` to `~/.codex/` unless a config already exists there.                                                                                                                                             | `install_agent codex` (disabled).                                                        |
| `cursor.sh`          | Symlinks `etc/cursor/cli-config.json` and `etc/cursor/mcp.json` into `~/.cursor/`.                                                                                                                                                                            | `install_agent cursor` (disabled).                                                       |
| `engram.sh`          | Installs the `engram` formula from its Homebrew tap and creates `~/.config/engram`.                                                                                                                                                                           | Sourced directly by `install.sh`.                                                        |
| `persona-domains.sh` | Maps each Claude persona to its steering domain.                                                                                                                                                                                                              | Sourced by `scripts/generate-personas.sh` and `scripts/validate-persona-steering.sh`.    |

## Host-local source files

Two optional, git-ignored files under `~/.extra` mount machine-specific skills and steering that
must stay out of this public repo. `extra-sources.sh` writes a `.example` sibling for each; copy it
to the live filename to activate:

- `~/.extra/skill-sources`: one `name=path` per line — mounts host-local skill directories under
  each agent's `extra/` skills umbrella (`ai-tools.sh`). Env equivalent: `$EXTRA_SKILL_SOURCES`
  (colon-separated `name=path` pairs).
- `~/.extra/steering-sources`: one `domain=path` per line — merges host-local steering docs into the
  matching domain (`ai-tools.sh`, `scripts/generate-personas.sh`). Env equivalent:
  `$EXTRA_STEERING_SOURCES`.

Every consumer degrades cleanly when the live file is absent (in-repo content only, no error). Keep
example lines commented until their paths exist: an uncommented path that is missing emits a
non-fatal warning at install time, whereas an absent file is silent — which is why these ship as
`.example` templates you copy to activate rather than live files.
