# Kiro CLI Configuration

Custom agent configurations for Kiro CLI with layered security, audit logging, and semantic
knowledge bases. Agents are managed as dotfiles and symlinked to `~/.kiro/agents/` by
`install/kiro-cli.sh`.

## Philosophy

- **Security in depth**: Three enforcement layers (hooks → toolsSettings → allowedTools) evaluated
  in order so no single misconfiguration exposes sensitive data
- **Least privilege by default**: Write tools excluded from every agent's `allowedTools` — the user
  must approve each write operation
- **Shared infrastructure**: Hooks and steering live in `etc/ai/` for cross-tool reuse; only
  Kiro-specific hooks live here
- **Agent specialization**: Each agent loads only the steering domains and skills relevant to its
  purpose

## Directory Structure

```text
etc/kiro-cli/
├── cli-agents/
│   ├── default.json           # General development agent
│   ├── default-prompt.md      # System prompt for default agent
│   ├── docs.json              # Documentation specialist agent
│   ├── docs-prompt.md         # System prompt for docs agent
│   ├── jira.json              # JIRA/SCRUM agent
│   └── jira-prompt.md         # System prompt for jira agent
├── hooks/
│   ├── check-research-kb.sh   # KB staleness detection (agentSpawn)
│   ├── kb-staleness.sh        # Helper for staleness checks
│   └── clear-research-kb-stale.sh  # Clear staleness warning (postToolUse)
├── settings/
│   ├── cli.json               # Global CLI settings (telemetry, knowledge, diff tool)
│   └── mcp.json               # Global MCP servers (empty — servers defined per-agent)
└── mcp-servers.conf           # Node.js MCP package list for install scripts
```

## Configuration Model

### Security Layers

Security is enforced at three levels, evaluated in order:

1. **Hooks** — `preToolUse` with `matcher: "*"` runs `block-env-files.sh` on every agent. Inspects
   all tool inputs for `.env` file paths and exits `2` (block) if found. This is the first line of
   defense and cannot be bypassed by `allowedTools` or `toolsSettings`.

1. **toolsSettings** — per-tool path and command restrictions. `deniedCommands` are regex patterns
   checked before `allowedCommands`. Deny lists are agent-specific (jira denies `pip install .*`,
   etc.). Write paths restricted to project directories; system paths blocked.

1. **allowedTools** — the whitelist of tools that skip user approval. Only read-oriented tools are
   listed. Anything not in `allowedTools` requires explicit user confirmation.

### Tool Access Model

All agents use `"tools": ["*"]` to make every tool available, then restrict what runs unprompted via
`allowedTools`. This inverts the official examples (which list specific tools in `tools`) but
achieves the same result: agents can use any tool if the user approves, but only `allowedTools`
entries run without a prompt.

### MCP Servers

- **`includeMcpJson: true`** on all agents merges servers from `~/.kiro/settings/mcp.json` and
  `<cwd>/.kiro/settings/mcp.json`
- Agent-specific servers declared inline (jira has `jira`, default has `kubernetes`)
- `"disabled": true` keeps a server version-controlled without starting it
- `"disabledTools"` blocks specific dangerous tools from a server
- Secrets use `${ENV_VAR}` interpolation in `env` blocks

### Resources

Three URI schemes with different loading behavior:

- **`file://`** — loaded into context at startup (steering docs, AGENTS.md, README.md)
- **`skill://`** — metadata loaded at startup, full content on demand (SKILL.md files)
- **`knowledgeBase`** objects — indexed for semantic search (large doc sets and codebases)

### Subagent Trust

Only `default` is trusted — subagents spawned as default inherit full tool approval. Other agents
spawned as subagents require user approval for each tool use.

## Best Practices Followed

These practices come from the
[official configuration reference](https://kiro.dev/docs/cli/custom-agents/configuration-reference/)
and [hooks documentation](https://kiro.dev/docs/cli/hooks/):

- **Start restrictive, expand as needed** — minimal `allowedTools`, broad `deniedCommands`
- **Deny-before-allow evaluation** — `deniedCommands` always checked first
- **Defense-in-depth for sensitive files** — `.env` blocked at hook layer, `read.deniedPaths`,
  `grep.deniedPaths`, `glob.deniedPaths`, and `shell.deniedCommands` simultaneously
- **Hook-based enforcement** — `preToolUse` with exit code 2 for hard blocks
- **Hook timeouts** — `timeout_ms: 5000` on all hooks to prevent hangs
- **Audit logging** — sensitive operations (AWS, kubectl, shell) logged to JSONL files
- **MCP secrets via interpolation** — never hardcoded in config
- **Knowledge base scoping** — `"best"` for docs, `"fast"` for code; descriptive `description`
  fields so the agent knows when to search each KB
- **`include`/`exclude` arrays** — scope indexing to relevant files, exclude `.git/`,
  `__pycache__/`, `.venv/`, `node_modules/`

## Intentional Deviations

- **`tools: ["*"]` on all agents** — official examples list specific tools. This repo makes
  everything available and gates via `allowedTools` instead. Effect is identical but easier to
  maintain.
- **Agents in `etc/kiro-cli/cli-agents/` not `.kiro/agents/`** — dotfiles convention with symlinks.
  Allows version control and cross-machine portability.
- **Shared hooks in `etc/ai/hooks/`** — official examples show hooks co-located with agents. This
  repo shares `block-env-files.sh` and `audit-shell-commands.sh` across Kiro CLI and Claude Code.
- **`aws.autoAllowReadonly: true`** — more permissive than default. Allows read-only AWS calls
  (describe, list, get) without prompting. Appropriate for infrastructure work.

## Considered and Rejected

Features evaluated and intentionally not adopted (last reviewed: 2026-05-26, v2.4):

- **`cache_ttl_seconds` on security hooks** — The hooks docs do not confirm whether caching is keyed
  on input parameters. If caching is global (exit code cached regardless of tool input), a
  successful check for a safe file would bypass the hook for subsequent `.env` access within the
  TTL. Do not add until Kiro documents input-aware cache keys.
- **`autoAllowReadonly` for shell** — Kiro's heuristic for "read-only" is undocumented. Until we can
  verify exactly which commands it auto-approves, the explicit `allowedCommands` list is safer.
  Revisit if the heuristic is documented or if the allowedCommands list becomes unwieldy.
- **`keyboardShortcut` on agents** — Agent switching is infrequent enough that `/agent swap` is
  fine. Shortcuts add config noise without meaningful time savings.
- **`model` field on agents** — Locks agents to specific models. The "Auto" default adapts as new
  models become available without config changes.
- **`welcomeMessage` field** — Agent name and description already provide context on switch.
- **`stop` hook trigger** — No current use case. Tests and builds are triggered explicitly.
- **`denyByDefault` for shell** — Too restrictive for the default agent where novel commands are
  common. Would require constant allowlist maintenance.
- **Tool Search** — Only beneficial with 5+ MCP servers or 50k+ tokens of tool specs. Current setup
  has 1-2 MCP servers per agent.
- **`$AGENT_CONTEXT_OUT` in hooks** — This env var is only set when the agent's shell tool drives a
  command, not during hook execution. Hooks already have their own output mechanism (stdout → agent
  context for agentSpawn, stderr → LLM for preToolUse exit 2).

## Official Documentation

- [Configuration Reference](https://kiro.dev/docs/cli/custom-agents/configuration-reference/)
- [Creating Custom Agents](https://kiro.dev/docs/cli/custom-agents/creating/)
- [Agent Examples](https://kiro.dev/docs/cli/custom-agents/examples/)
- [Hooks](https://kiro.dev/docs/cli/hooks/)
- [MCP Overview](https://kiro.dev/docs/cli/mcp/)
- [MCP Configuration](https://kiro.dev/docs/cli/mcp/configuration/)
- [MCP Security](https://kiro.dev/docs/cli/mcp/security/)
- [Steering](https://kiro.dev/docs/cli/steering/)
- [Skills](https://kiro.dev/docs/cli/skills/)
- [Built-in Tools Reference](https://kiro.dev/docs/cli/reference/built-in-tools/)

## Finding Specific Information

- **Agent permissions**: Check `allowedTools` and `toolsSettings` in each agent JSON
- **Denied commands**: Look at `toolsSettings.shell.deniedCommands` in the relevant agent
- **MCP servers**: Inline `mcpServers` in agent JSON, or `settings/mcp.json` for global
- **Steering docs loaded**: Check `resources` array in agent JSON for `file://` entries
- **Knowledge bases**: Look for `knowledgeBase` objects in the `resources` array
- **Hook behavior**: `etc/ai/hooks/` for shared hooks, `hooks/` for Kiro-specific
- **CLI settings**: `settings/cli.json` for telemetry, knowledge indexing, diff tool config
