# AI Tool Parity Audit

Audit the AI tool configurations in this dotfiles repo for permission and security parity across
tools. The guiding principle is that all tools should enforce the same protections — same commands
blocked, same files protected, same paths allowed.

## Tool Discovery

Read `install/ai-tools.sh` and check which tool directories exist under `etc/` to determine the
available AI tools. Each tool has a directory in `etc/` with its configuration files and a
`README.md` documenting its setup. Read all discovered tool configs and READMEs before comparing.

## Parity Dimensions

For each dimension, compare across all three tools and flag discrepancies:

### 1. Sensitive File Blocking

- `.env` file patterns (read, grep, shell access)
- Credential files (`.key`, `.pem`, `credentials*`)
- Are the same patterns present in all tools?

### 2. Deny Lists (Destructive Commands)

- System commands (`rm`, `sudo`, `kill`, `reboot`, etc.)
- Git commands (`git add .`, `git add -A`)
- GitHub CLI commands (mutating `gh` operations)
- Kubernetes commands (mutating `kubectl` operations)
- Are the same commands blocked in all tools?

### 3. Allow Lists (Pre-approved Commands)

- Read-only shell commands (`cat`, `grep`, `head`, `tail`, `sed`, `ls`, `find`, etc.)
- Git read commands (`git log`, `git diff`, `git status`, etc.)
- Are the same commands pre-approved in all tools?

### 4. Path Restrictions

- Read allows/denies
- Write/Edit allows (project directories)
- Write/Edit denies (system paths)
- Are the same paths allowed and denied?

### 5. MCP Server Versions

- Are pinned versions consistent across tools that share the same server?

## What to Ignore

- Features one tool has that others don't support (hooks, knowledge bases, subagents, audit logging)
- Tool-specific commands that only apply to one context (e.g., `mdbook` in docs agent)
- Differences documented as "intentional deviations" in the READMEs

## Output Format

Write findings to `analysis/ai-tool-parity-audit.md` with:

1. **Summary** — overall parity status (aligned / minor gaps / significant gaps)
1. **Discrepancies Table** — one row per finding:

| Dimension | Item | Kiro CLI | Claude Code | Cursor | Action |
|-----------|------|----------|-------------|--------|--------|

1. **Recommended Fixes** — specific changes to restore parity, grouped by tool
