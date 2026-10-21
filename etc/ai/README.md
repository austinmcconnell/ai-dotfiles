# AI Tool Configuration

Shared AI tool assets that are distributed to multiple tools by `install/ai-tools.sh`.

## Directory Structure

```text
etc/ai/
├── hooks/      Shared lifecycle hook scripts (wired by Kiro agent JSON and Claude settings.json)
├── prompts/    Reusable prompts (clipboard-based, tool-agnostic)
├── skills/     Workflow definitions (SKILL.md format)
├── steering/   Always-on coding principles and conventions
└── usage/      Claude Code statusline scripts and SQLite schema for token/cost tracking
```

`hooks/` and `usage/` are not distributed by `install/ai-tools.sh`: the tool configs call the
scripts in place through `$AI_DOTFILES_DIR` (see `etc/ai/usage/README.md` for the usage store).

## How Distribution Works

`install/ai-tools.sh` reads from these directories and generates tool-specific output:

| Tool                  | Skills                           | Steering                                                                                        |
| --------------------- | -------------------------------- | ----------------------------------------------------------------------------------------------- |
| kiro-cli              | Symlinked to `~/.kiro/skills/`   | Symlinked to `~/.kiro/steering/`, loaded via `file://~/.kiro/steering/` resources in agent JSON |
| Claude Code           | Symlinked to `~/.claude/skills/` | Generated as individual rule files in `~/.claude/rules/`, plus a slim pointer `CLAUDE.md`       |
| Codex (disabled)      | Symlinked to `~/.codex/skills/`  | Reads AGENTS.md (no adapter needed)                                                             |
| Cursor (disabled)     | Symlinked to `~/.cursor/skills/` | Generated as `.mdc` files in `~/.cursor/rules/`                                                 |
| Gemini CLI (disabled) | Symlinked to `~/.gemini/skills/` | Concatenated into `~/.gemini/GEMINI.md`                                                         |

Only `kiro-cli` and `Claude Code` are currently active. The rows above marked `(disabled)` are fully
wired in the `agent_config` registry (`install/ai-tools.sh`) but commented out of `ENABLED_AGENTS`
in `install/enabled-agents.sh` — re-enable by uncommenting there. That array gates both skill and
steering distribution and the per-agent install scripts (`install/<agent>.sh`); a disabled agent is
skipped, never uninstalled. Check that array, not this table, for the authoritative current state.

## Prompts

Tool-agnostic analysis and workflow prompts managed via the `ai-prompt` shell function. Copied to
clipboard for use with any AI chat service. See `ai-prompt help` for usage.

## Skills

Structured workflow definitions following the SKILL.md format (name/description frontmatter plus
step-by-step instructions). Organized by category:

- `ansible/` — Ansible role, playbook, and project workflows
- `shared/` — cross-cutting (commit messages, todo management)
- `development/` — coding workflows (specs, implementation, pre-commit)
- `documentation/` — doc creation and review
- `operations/` — AWS and Kubernetes operations
- `research/` — structured research creation and verification
- `scrum/` — JIRA operations, story writing, sprint workflows

## Steering

Always-on principles that guide AI behavior. Organized by domain:

- `code/` — python, shell, git, testing conventions
- `github/` — PR, issue, code review, actions conventions
- `security/` — env file protection, best practices
- `shared/` — skill-loading triggers common to every agent
- `documentation/` — writing style, formatting, mdbook
- `scrum/` — JIRA operations, sprint conventions
- `datadog/` — observability and UST conventions
- `ansible/` — Proxmox automation conventions

These are the *source of truth*. Each tool consumes them differently (kiro-cli reads them through a
`~/.kiro/steering/` symlink referenced by `file://~/.kiro/steering/` resource globs in each agent
JSON, Cursor gets `.mdc` files, Claude gets individual rule files, Gemini gets a concatenated
markdown file).

### Why Some Steering Is Universal and Some Is Per-Persona

`install/ai-tools.sh` only ships `code`, `github`, `security`, and `shared`
(`UNIVERSAL_STEERING_DOMAINS`) to every session on every tool. `datadog`, `ansible`,
`documentation`, and `scrum` are deliberately left out — not an oversight, but a consequence of a
structural asymmetry between the distributed tools:

- **kiro-cli** has no "main session" distinct from its agents — every invocation is an agent, and
  each agent JSON declares its own `resources` array. Steering scoping is native and per-invocation
  (`jira.json` only pulls `scrum/`, `datadog.json` only pulls `datadog/`). That's why kiro-cli's
  entry in `install/ai-tools.sh` is a raw `symlink:` of the whole `etc/ai/steering/` tree: Kiro
  never needs a universal/domain-specific split, because each agent already filters at load time.
- **Claude Code's main session, Cursor, and Gemini CLI** have exactly one always-on global context
  surface with no runtime scoping (`~/.claude/rules/` + `CLAUDE.md`, `.mdc` files with
  `alwaysApply: true`, `GEMINI.md`). Claude's four custom subagents
  (`docs`/`jira`/`datadog`/`ansible`) claw back Kiro-style scoping by having their domain steering
  inlined into the generated persona files, but the main session — and Cursor and Gemini entirely —
  have no equivalent. Whatever a generator writes there loads on *every* session, forever.

Because three of the five tools can't filter downstream, filtering has to happen at distribution
time instead: `UNIVERSAL_STEERING_DOMAINS` is that preselected "safe for any session, any tool" set.
Specialist domains stay out because they'd otherwise pollute a plain coding session on the tools
that can't scope them away.

This asymmetry exists because this repo's AI tooling was originally designed around kiro-cli's
per-agent resource model (see `etc/kiro-cli/README.md`); tools without that concept — added later —
inherited a distribution script that had to invent a static substitute.
