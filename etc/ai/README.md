# AI Tool Configuration

Shared AI tool assets that are distributed to multiple tools by `install/ai-tools.sh`.

## Directory Structure

```text
etc/ai/
├── prompts/    Reusable prompts (clipboard-based, tool-agnostic)
├── skills/     Workflow definitions (SKILL.md format)
└── steering/   Always-on coding principles and conventions
```

## How Distribution Works

`install/ai-tools.sh` reads from these directories and generates tool-specific output:

| Tool        | Skills                           | Steering                                        |
| ----------- | -------------------------------- | ----------------------------------------------- |
| kiro-cli    | Symlinked to `~/.kiro/skills/`   | Loaded as `file://` resources in agent JSON     |
| Codex       | Symlinked to `~/.codex/skills/`  | Reads AGENTS.md (no adapter needed)             |
| Cursor      | Symlinked to `~/.cursor/skills/` | Generated as `.mdc` files in `~/.cursor/rules/` |
| Claude Code | Symlinked to `~/.claude/skills/` | Concatenated into `~/.claude/CLAUDE.md`         |
| Gemini CLI  | Symlinked to `~/.gemini/skills/` | Concatenated into `~/.gemini/GEMINI.md`         |

Only tools listed in `ENABLED_AGENTS` within `install/ai-tools.sh` are active.

## Prompts

Tool-agnostic analysis and workflow prompts managed via the `ai-prompt` shell function. Copied to
clipboard for use with any AI chat service. See `ai-prompt help` for usage.

## Skills

Structured workflow definitions following the SKILL.md format (name/description frontmatter plus
step-by-step instructions). Organized by category:

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
- `documentation/` — writing style, formatting, mdbook
- `scrum/` — JIRA operations, sprint conventions

These are the *source of truth*. Each tool consumes them differently (kiro-cli loads them as
resources, Cursor gets `.mdc` files, Claude/Gemini get a concatenated markdown file).
