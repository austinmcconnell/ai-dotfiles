# Kiro CLI Configuration

Custom agent configurations for Kiro CLI with layered security, audit logging, and semantic
knowledge bases. Agents are managed as dotfiles and symlinked to `~/.kiro/agents/` by
`install/kiro-cli.sh`.

This repo manages kiro-cli agents as dotfiles rather than using the standard `.kiro/agents/` or
`~/.kiro/agents/` locations directly. The conventions below document repo-specific patterns that go
beyond the
[official configuration reference](https://kiro.dev/docs/cli/custom-agents/configuration-reference/).

## Philosophy

- **Security in depth**: Three enforcement layers (hooks → toolsSettings/permissions → allowedTools)
  evaluated in order so no single misconfiguration exposes sensitive data
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
│   ├── code.json / code-prompt.md          # Generalist agent (fills the role of a "default")
│   ├── docs.json / docs-prompt.md          # Documentation specialist
│   ├── jira.json / jira-prompt.md          # JIRA/SCRUM specialist
│   ├── ansible.json / ansible-prompt.md    # Ansible/Proxmox specialist
│   └── datadog.json / datadog-prompt.md    # Datadog observability specialist
├── hooks/                       # Kiro-only: not ported to Claude Code (see "What Claude Code
│   │                             # Does NOT Have" in etc/claude-code/README.md)
│   ├── check-research-kb.sh     # KB staleness detection (agentSpawn)
│   ├── kb-staleness.sh          # Helper for staleness checks
│   ├── clear-research-kb-stale.sh  # Clear staleness warning (postToolUse)
│   ├── trace-tool-call.sh       # Session-scoped trace logging (postToolUse, code agent only)
│   └── rotate-traces.sh         # Trace file cleanup (agentSpawn, code agent only)
├── settings/
│   ├── cli.json               # Global CLI settings (telemetry, knowledge, diff tool)
│   └── mcp.json               # Global MCP servers (empty — servers defined per-agent)
└── mcp-servers.conf           # Node.js MCP package list for install scripts
```

Each agent has a co-located prompt file using a relative `file://` URI (e.g.
`"prompt": "file://./code-prompt.md"`). Cross-tool hooks (security denies, correction-capture,
audit-shell-commands, `recall-memory.sh`/`check-engram-hygiene.sh`) live in `etc/ai/hooks/` instead
of here, referenced via the `$AI_DOTFILES_DIR` env var (`$AI_DOTFILES_DIR/etc/ai/hooks/<script>.sh`,
resolving to `~/.dotfiles` by default) — they moved out of `etc/kiro-cli/hooks/` once Claude Code
started wiring them too. Steering docs (principles) live in `etc/ai/steering/<domain>/**/*.md`;
skills (workflows, templates) live in `.kiro/skills/<category>/**/SKILL.md` — see the
`skill-loading-triggers` steering for the mapping.

## Configuration Model

### Tool Access Model

All agents use `"tools": ["*"]` to make every tool *available*, then restrict what runs unprompted
via `allowedTools`. This is the inverse of the official examples, which list specific tools in
`tools`. The effect: agents can use any tool if the user approves, but only `allowedTools` entries
run without a prompt.

Each agent's `allowedTools` is scoped to its purpose:

- **code** — broad read access, git read tools, `gh` CLI commands, code search, knowledge, web,
  subagent
- **docs** — same read tools as code, no domain-specific MCP tools
- **jira** — adds `@jira/*` read tools, no mutating JIRA tools in allowedTools
- **datadog** — read tools + Pup CLI read-only commands for querying Datadog (monitors, logs,
  metrics, dashboards, synthetics)

Write tools (`write`, `shell`) are intentionally excluded from every agent's `allowedTools` — the
user must approve each write operation. Git write commands (`git add`, `git commit`) are not in
`shell.allowedCommands`, so they also require explicit user approval before each use.

### Security Layers

Security is enforced at three levels, evaluated in order:

1. **Hooks** — `preToolUse` with `matcher: "*"` runs `block-env-files.sh`,
   `block-sops-age-files.sh`, and `block-ssh-private-keys.sh` on *every* agent. These inspect all
   tool inputs for sensitive file paths and exit `2` (block) if found. This is the first line of
   defense and cannot be bypassed by `allowedTools` or `permissions`. `block-memory-secrets.sh` runs
   on `matcher: "@engram/*"` to prevent storing credentials in persistent memory — the glob (`/*`)
   is required because kiro-cli reports MCP tools with the `@server/` prefix (e.g.
   `@engram/mem_save`); a bare `@engram` matcher does not fire and the hook is silently skipped. The
   hook normalizes both MCP naming conventions before comparing (`${TOOL_NAME##*/}` strips kiro's
   `@server/` prefix, `${TOOL_NAME##mcp__*__}` strips Claude Code's `mcp__server__` prefix), so it
   works for both tools.
1. **Permissions / toolsSettings** — per-tool path and command restrictions. The configs contain
   both formats for V2/V3 compatibility:
   - **V2 (`toolsSettings`)** — regex-based `shell.deniedCommands` / `shell.allowedCommands`, path
     restrictions on `write`, `grep`, `glob`, and `read` tools
   - **V3 (`permissions.rules`)** — capability-based rules with `match` (glob patterns), `exclude`,
     and `effect` (deny/ask/allow). Effects resolve by restrictiveness: deny > ask > allow
   - Both express the same intent: deny secrets access, allow read-only commands, block destructive
     operations
   - The shell deny rule includes `"exclude": ["chmod +x *"]` to prevent the broadened glob
     `"chmod * *"` from blocking executable permission grants under V3's deny-takes-precedence model
   - The two engines spell the chmod deny differently on purpose: V2 uses the precise regex
     `chmod [0-7]{3,4} .*` (octal modes only, no exclude needed), while V3 uses the broad glob
     `chmod * *` plus `"exclude": ["chmod +x *"]` because globs can't express the octal-only match.
     Both deny octal-mode chmod while allowing `chmod +x` — do NOT "reconcile" them into one
     spelling
1. **allowedTools** — the whitelist of tools that skip user approval (see Tool Access Model above)

**Important:** Do not re-run `/upgrade-agent` on agents that have manual edits to the `permissions`
block (e.g., the `exclude` fix on the chmod deny rule). The command regenerates permissions from
`toolsSettings` and will overwrite manual additions.

### Audit Logging

The `code` agent logs sensitive operations to `~/.kiro/logs/`:

- `use_aws` matcher → appends to `aws-audit.jsonl`
- `@kubernetes` matcher → appends to `kubectl-audit.jsonl`
- `execute_bash` matcher → `audit-shell-commands.sh` catches `aws` and `kubectl` invoked via shell

Other agents do not have audit hooks — they deny these commands outright via `deniedCommands`.

### Trace Logging

The `code` agent logs all tool calls to session-scoped trace files at
`~/.kiro/logs/traces/<session-id>.jsonl`:

- `postToolUse` with `matcher: "*"` → `trace-tool-call.sh` records tool name, truncated
  input/output, duration, and timestamp
- Sensitive values are redacted via regex before writing (keys matching
  password/secret/token/key/credential/authorization/private)
- Trace directory is created with `700` permissions (owner-only access)
- `rotate-traces.sh` runs on `agentSpawn` to delete files older than 7 days or trim when total size
  exceeds 100MB
- `bin/trace-search` provides CLI querying: filter by tool, grep patterns, session, or date

Trace logging is intentionally scoped to the `code` agent only — other agents don't need the
overhead, and restricting to one agent avoids write races on shared session files.

### Hook Patterns

Hooks use the V3 array format: each hook is an object with `name`, `trigger`, `matcher` (optional),
`action` (`type` + `command`), and `timeout` (seconds). The V2 engine also reads this format.

- `agentSpawn` — all agents run `recall-memory.sh` (surfaces engram memories for the current
  project) and `check-engram-hygiene.sh`, which delegates to `bin/engram-hygiene check`: a
  time-throttled (6-week default, `ENGRAM_HYGIENE_CADENCE_DAYS`) nudge that fires only when the
  current project has pending engram conflict relations awaiting review. Hygiene is wired to every
  agent (not just the KB-using three) because conflict debt accrues in the shared local DB
  regardless of which agent created the memories — it tracks the `recall-memory.sh` footprint, not
  the `check-research-kb.sh` one. It is deliberately current-project scoped to stay low-noise; the
  all-projects view is the on-demand `dotfiles memory-check` command (`bin/engram-hygiene status`).
  Both are read-only — conflict resolution stays user-approved via `mem_judge`/`mem_compare`, never
  auto-applied. The `code`, `docs`, and `ansible` agents additionally run `check-research-kb.sh` for
  KB staleness detection (their agent name must appear in the `kb-staleness.sh` sentinel for the
  warning to fire). The `code` agent additionally runs `rotate-traces.sh` for trace file cleanup.
  Claude Code runs the same `recall-memory.sh`/`check-engram-hygiene.sh` pair via `SessionStart`
  (see `etc/claude-code/README.md`) — that pair has parity across both tools. The KB-staleness and
  trace hooks remain kiro-only; see "What Claude Code Does NOT Have" there for why.
- `preToolUse` — every agent has the `block-env-files.sh`, `block-sops-age-files.sh`, and
  `block-ssh-private-keys.sh` hooks on `matcher: "*"`. The `code` agent adds audit hooks for
  `use_aws`, `@kubernetes`, and `execute_bash`. All agents have `block-memory-secrets.sh` on
  `matcher: "@engram/*"` (see Security Layers above for the matcher/normalization detail).
- `postToolUse` — the `code` and `docs` agents use this (runs `clear-research-kb-stale.sh` after
  knowledge operations to clear staleness warnings). The `code` agent also runs `trace-tool-call.sh`
  on `matcher: "*"` for session-scoped trace logging.
- `userPromptSubmit` — every agent runs `correction-capture.sh`, the capture half of the
  capture-and-promote learning system (see the `capturing-corrections` steering and the
  `distill-learnings` skill). On each prompt it does two things via stdout (the one hook channel
  documented to reach the model on both kiro-cli and Claude Code): (1) if the prompt looks like a
  correction/preference, it nudges the agent to `mem_save` it immediately with `type: preference`
  and a `topic_key: correction/<area>-<slug>`; (2) if a correction was captured on a prior turn (a
  session-scoped sentinel under `$TMPDIR/ai-corrections/<session>.pending`), it reminds the user to
  run the `distill-learnings` skill, then clears the sentinel. The promotion prompt rides
  `userPromptSubmit` rather than a `stop` hook on purpose: the `stop` event's exit-0 stdout is not
  added to the model's context on either tool, so a stop-based reminder would silently vanish. The
  session key is read from the payload's `session_id` first (Claude Code provides it), then
  `KIRO_SESSION_ID`, then a `date+PID` fallback — matching `trace-tool-call.sh` so parallel sessions
  don't collide on a shared sentinel. The kiro-cli `userPromptSubmit` payload has only
  `hook_event_name`, `cwd`, and `prompt` (no `session_id`, verified by capturing a real payload), so
  on kiro the key always comes from the exported `KIRO_SESSION_ID`; Claude Code supplies
  `session_id` in the payload — these are per-tool paths, not degradation. The hook never writes to
  memory itself (the agent's `mem_save` still passes through `block-memory-secrets.sh`) and never
  promotes anything (promotion is the user-approved `distill-learnings` skill).

### MCP Server Conventions

- `includeMcpJson: true` on all agents — merges servers from `~/.kiro/settings/mcp.json` and
  `<cwd>/.kiro/settings/mcp.json` into the agent's server list
- Shared servers in `~/.kiro/settings/mcp.json`: `engram` (cross-session memory, available to all
  agents via `includeMcpJson`)
- Agent-specific servers are declared inline in the config (jira has `jira`, code has `kubernetes`)
- Use `"disabled": true` to define a server without starting it (code's `kubernetes` server). The
  config stays version-controlled and ready to enable.
- Use `"disabledTools"` to block specific MCP tools (jira blocks `jira_delete`)
- Secrets use `${ENV_VAR}` interpolation in `env` blocks:
  `"GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PAT}"`
- Agents that don't need a service deny it entirely via `toolsSettings` (docs, jira, datadog, and
  ansible set `aws.allowedServices: []`; docs denies `docker .*` and `kubectl .*` in shell). Only
  `code` keeps a populated `allowedServices` list.

### Resource Patterns

Resources use three URI schemes with different loading behavior:

- `file://` — loaded into context at startup. Used for AGENTS.md, README.md, and steering docs.
  Paths can be relative to cwd (`file://AGENTS.md`) or absolute (`file://~/.dotfiles/etc/...`)
- `skill://` — metadata loaded at startup, full content on demand. Used for SKILL.md files. Agents
  load both project-local (`.kiro/skills/`) and global (`~/.kiro/skills/`) skills.
- `knowledgeBase` objects — indexed for semantic search. Used for large doc sets and codebases.

The `code`, `docs`, and `ansible` agents additionally load `file://ideas.md` and `file://todo.md`
(relative → per-project, silently skipped when absent) so the idea-refinement funnel's working files
are in context without the agent stumbling onto them. `backlog.md` is deliberately NOT auto-loaded —
it can grow large, so it is read on demand instead. `jira` and `datadog` omit all three (no
planning/ideation work). See the `idea-refinement` and `todo` skills for the funnel itself.

Documentation follows a **README-as-pointer** scheme rather than eager-loading a `docs/` tree. The
top-level `file://README.md` (already loaded on all five agents) is the always-on entry point and
should be maintained as a thin *map*: one line per important doc naming the file and when to read
it. Detailed docs live in the retrieval channel — the agent pulls them on demand with `read`/`grep`
(or the KB, where the repo is indexed) by following the map's pointers. Two hard constraints keep
this from re-creating context pressure: pointers are **one-hop** (a README names the actual target
doc, never another README) and the indexing is **flat** (one level, no nested index trees) — both
are accuracy findings from the context-rot literature, not style preferences. A blunt
`file://docs/*.md` glob is deliberately **NOT added** to any agent: eager-loading whole docs trees
degrades answer accuracy (predominantly Claude agents *abstain* under over-stuffed context), so it
is a rejected default, not a missing feature. The one narrow exception is opt-in per-repo: a single
small, stable, high-signal doc that benefits from whole-document reasoning every session may be
added as an explicit `file://<path>` entry — a named exception within the pointer model, never a
glob. The pointer scheme is agent-agnostic (all five benefit — e.g. datadog reading a service
runbook); the KB scoping is unchanged. See the `readme-pointer` skill for the convention and the
"Which Channel" boundary in `knowledge-base-usage` / `cross-session-memory` steering for how agents
route between the eager map, the KB, and engram.

Resource scoping per agent:

- **code** — all steering domains (`code/`, `github/`, `security/`),
  development/operations/research/ shared skill categories, multiple knowledge bases (research,
  project code, analysis docs)
- **docs** — `documentation/` steering, documentation + shared skills, many knowledge bases for
  cross-project doc work
- **jira** — `scrum/` steering and `env-file-protection.md` only, development + scrum + shared
  skills
- **ansible** — `ansible/` steering, ansible + shared skills, multiple knowledge bases (geerlingguy
  reference repos, research, homelab docs)
- **datadog** — `datadog/` steering and `env-file-protection.md`, operations + shared skills, no
  knowledge bases

### Knowledge Base Conventions

- `indexType: "best"` for documentation and markdown-heavy repos (higher quality search)
- `indexType: "fast"` for code-heavy repos with frequent changes (screenings-ingestion)
- `autoUpdate: true` for actively changing content, `false` for stable cross-project indexes
- Use `include`/`exclude` arrays to scope what gets indexed — exclude `.git/`, `__pycache__/`,
  `.venv/`, `node_modules/`, build artifacts
- Write specific `description` fields — the agent uses these to decide which KB to search
- Keep `description` claims honest to the actual `include`/`exclude` scope. The description is the
  routing signal, so advertising coverage the globs don't provide causes wrong routing (an agent
  searches a KB that cannot return the content). When narrowing a description because content is
  deliberately unindexed, say so and name the fallback (e.g. "the YAML assets are not indexed — grep
  them") so a future reader doesn't "helpfully" widen the `include` back. Don't oversell a
  separation between two KBs whose `include` arrays overlap (e.g. two KBs both indexing
  `docs/**/*.md`) — describe the retrieval preference, not an exclusive split.
- Don't index bulk domain *data* into a code-comprehension (`fast`) KB. Large, repetitive structured
  data (e.g. template/asset YAML, fixtures, generated files) crowds out the sparse code/prose signal
  and surfaces as noise in results — the same retrieval-pollution failure the `.pytest_cache`
  exclusion fixed, at larger scale. A `fast` KB should index the code that *consumes or produces*
  such data, not the data itself. If the data genuinely needs searching, use `grep`/`glob` over its
  directory, or a separate purpose-built KB scoped to just those assets.
- Knowledge bases referencing repos on other machines (work vs personal) will silently return no
  results — this is expected

### Subagent Trust Model

All agents share the same subagent config:

```json
"subagent": {
    "availableAgents": ["code", "docs", "jira", "ansible", "datadog"],
    "trustedAgents": ["code"]
}
```

Only `code` is trusted — subagents spawned as code inherit full tool approval. Other agents spawned
as subagents require user approval for each tool use. This prevents a jira or docs subagent from
performing write operations without oversight.

### Adding a New Agent

1. Create `etc/kiro-cli/cli-agents/<name>.json` and `<name>-prompt.md`
1. Start from an existing agent config — copy the closest match
1. Set `tools: ["*"]` and define a restrictive `allowedTools` list
1. Add `block-env-files.sh` as a `preToolUse` hook with `matcher: "*"`
1. Add `.env` deny patterns to `shell.deniedCommands`, `grep.deniedPaths`, and `glob.deniedPaths`
1. Set `includeMcpJson: true`
1. Scope `resources` to only the steering domains and skills the agent needs
1. Set `aws.allowedServices: []` unless the agent needs AWS access
1. Run `/upgrade-agent` (in a `kiro-cli --v3` session) on the new agent only to generate its
   `permissions.rules` block, then add the `"exclude": ["chmod +x *"]` to its shell deny rule
1. Test with `kiro-cli chat --agent <name>`

## Best Practices Followed

These practices come from the
[official configuration reference](https://kiro.dev/docs/cli/custom-agents/configuration-reference/)
and [hooks documentation](https://kiro.dev/docs/cli/hooks/):

- **Start restrictive, expand as needed** — minimal `allowedTools`, broad `deniedCommands`
- **Deny-before-allow evaluation** — `deniedCommands` always checked first
- **Defense-in-depth for sensitive files** — `.env`/sops/SSH keys blocked at the hook layer,
  `read.deniedPaths`, `grep.deniedPaths`, `glob.deniedPaths`, and `shell.deniedCommands`
  simultaneously
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
  repo shares security-deny, correction-capture, and audit hooks across Kiro CLI and Claude Code.
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
- **`denyByDefault` for shell** — Too restrictive for the `code` agent where novel commands are
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

- **Agent permissions**: Check `allowedTools`, `toolsSettings`, and `permissions.rules` in each
  agent JSON
- **Denied commands**: Look at `toolsSettings.shell.deniedCommands` in the relevant agent
- **MCP servers**: Inline `mcpServers` in agent JSON, or `settings/mcp.json` for global
- **Steering docs loaded**: Check `resources` array in agent JSON for `file://` entries
- **Knowledge bases**: Look for `knowledgeBase` objects in the `resources` array
- **Hook behavior**: `etc/ai/hooks/` for shared hooks, `hooks/` for Kiro-specific
- **CLI settings**: `settings/cli.json` for telemetry, knowledge indexing, diff tool config
