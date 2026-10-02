# ai-dotfiles Repository Context

## Repository Purpose

Austin's personal, multi-tool AI coding configuration, extracted from the main dotfiles repo so the
AI surface can be versioned, installed, and shared on its own. It carries the shared skills,
steering, and prompts plus the per-tool configs for Kiro CLI, Claude Code, Cursor, and Codex, and
the engram persistent-memory setup.

This is a *personal* config ("here's my setup") that others can read or adapt — not a vendor-neutral,
configurable AI harness. Paths that point at Austin's knowledge bases or repos ship as-is; a cloner
repoints or ignores them.

## Relocation Model (`AI_DOTFILES_DIR`)

Every install script, hook command, and `ai-prompt.sh` resolves the repo root from `AI_DOTFILES_DIR`,
falling back to `$HOME/.dotfiles` when unset (the colocated-with-dotfiles case). Installed standalone,
`install.sh` sets `AI_DOTFILES_DIR` to this repo's own root. `AI_DOTFILES_DIR` must be exported from
the shell (`.zshenv`/`.zprofile`), never from a project dotenv — kiro-cli 2.24+ no longer auto-loads
project dotenv files into chat/MCP/tools.

Kiro steering resolves through a `~/.kiro/steering -> $AI_DOTFILES_DIR/etc/ai/steering` symlink
(agent JSON `resources` URIs do not expand `$VAR`, so the symlink is the relocation seam); hook
`command` strings do expand `$AI_DOTFILES_DIR` at shell-exec time.

## Multi-Tool AI Configuration

Shared AI assets live in `etc/ai/` and are distributed to each tool by `install/ai-tools.sh`:

- `etc/ai/prompts/` — reusable clipboard-based prompts (tool-agnostic)
- `etc/ai/skills/` — workflow definitions in SKILL.md format
- `etc/ai/steering/` — always-on coding principles and conventions
- `etc/ai/hooks/` — shared cross-tool lifecycle hooks

Tool-specific configs remain in their own directories:

- `etc/kiro-cli/` — agent JSON configs, hooks, settings, MCP server list
- `etc/codex/` — Codex config.toml
- `etc/cursor/` — Cursor CLI permissions and MCP config
- `etc/claude-code/` — Claude Code permissions (settings.json)

See `etc/ai/README.md` for the full distribution matrix.

## Custom Agent Conventions

Kiro-cli agent JSON mechanics (file layout, tool access model, security layers, audit/trace logging,
hook patterns, MCP server conventions, resource patterns, knowledge base conventions, subagent trust
model, and the "Adding a New Agent" checklist) are Kiro-cli-specific and don't apply to Claude Code,
Cursor, or Codex — see **`etc/kiro-cli/README.md`** for the full documentation.

The cross-tool convention that *does* apply everywhere: this repo manages agent/persona configs as
version-controlled files rather than using each tool's default discovery location (`.kiro/agents/`,
`~/.claude/agents/`), and shared cross-tool hooks live in `etc/ai/hooks/` while steering docs live
in `etc/ai/steering/<domain>/**/*.md` (see `skill-loading-triggers` steering for the skill mapping).

## Claude Code Conventions

Claude Code-specific configuration mechanics (permission model, hooks, MCP schema, persona
frontmatter, and the full "What Claude Code Does NOT Have vs kiro-cli" comparison) live in
**`etc/claude-code/README.md`** rather than here — Cursor, Codex, and Kiro-cli never act on this
mechanism directly, and (as of Claude Code v2.1.277+) that file is *also* the more appropriate home
because Claude Code now auto-loads this very file (`AGENTS.md`) as project context whenever no
`CLAUDE.md` exists above the working directory, and a user-scope `~/.claude/CLAUDE.md` (what this
repo generates) doesn't count against that check. Keeping Claude-only plumbing documentation here
would mean Claude re-reading meta-documentation about its own configuration every session for no
coding-task benefit — see `etc/claude-code/README.md`'s "What Claude Code Does NOT Have" section for
the full exception writeup.

## Security Considerations

Security principles (credential handling, environment variables, deny lists) are documented once in
`etc/ai/steering/security/*.md` — auto-loaded for Claude Code, Cursor, and Kiro-cli; read directly
for Codex. Repo-specific reminder: review tool permissions in Kiro CLI agents
(`etc/kiro-cli/README.md`) and Claude Code personas (`etc/claude-code/README.md`) when changing
either.
