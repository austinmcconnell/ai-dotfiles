# Cross-Session Memory

## Which Channel: Memory vs Knowledge Base vs Eager Context

An agent has three information channels; reach for the right one rather than defaulting to whichever
is nearest. This boundary is the seam the README-as-pointer scheme routes against (see the
`readme-pointer` skill and the kiro-only `etc/ai/steering/kiro/knowledge-base-usage.md`):

- **Persistent memory (engram)** — cross-session *narrative*: decisions and their rationale, failed
  approaches, corrections, handoffs, user preferences. Use engram for "why we did it this way" and
  "what happened last session," not for facts that live in the repo. Engram is also the *cross-tool*
  memory channel (one shared DB across kiro-cli, Claude Code, and Cursor) — prefer it over Claude
  Code's native auto memory (`~/.claude/projects/<project>/memory/MEMORY.md`), which is
  Claude-Code-only and invisible to every other tool, whenever something needs to reach another AI
  tool.
- **Knowledge base (semantic retrieval)** — *facts that live in the repo or docs corpus*: how the
  code works, what a doc says, cited research. Query the KB for these instead of storing a copy in
  memory.
- **Eager context** — small, stable, high-signal always-loaded files (AGENTS.md, steering) plus a
  thin *map* of what else exists (a README pointing at detailed docs). Not a place to preload a
  whole docs tree.

The failure mode this prevents: duplicating repo/doc facts into engram (they belong in the KB and go
stale in memory), or dumping cross-session narrative into a doc (it belongs in engram). When unsure,
ask which channel *owns* the information — narrative → engram, repo/doc fact → KB, stable
high-signal + a map → eager context.

## When to Save Memories

Save to engram (`mem_save`) at natural breakpoints, not after every small action, when:

- Making an architectural decision with rationale
- Discovering a failed approach (what was tried, why it failed) — don't retry without fixing the
  cause
- Establishing a project convention not documented elsewhere
- Completing a significant milestone in multi-session work
- Finding a non-obvious workaround or solution
- Receiving explicit user preferences about workflow ("User prefers …")

Use descriptive titles. For corrections, use the What/Why/Where/Learned structure in
`etc/ai/steering/code/capturing-corrections.md`.

## Session Start Recall

If the user describes a task or project at the start of a session:

1. Use `mem_search` with relevant keywords to find prior context
1. Use `mem_context` to get recent session history for the project
1. Mention relevant findings briefly: "From a previous session, I recall..."

Surface only what is relevant to the current task. Do not dump every memory into the response.

## When NOT to Save Memories

Never store:

- Secrets, credentials, API keys, tokens, or passwords
- Contents of .env files or encrypted secrets
- SSH keys or certificate material
- Personally identifiable information (PII)
- Temporary debugging state that won't matter next session
- Information already captured in project docs, READMEs, or steering files

## Memory Types

Engram's `type` field is free text — the store accepts any value and enforces nothing at runtime. So
drift is prevented by convention, not by engram. Engram publishes two type lists that do not fully
agree (the README Memory Protocol and the `mem_save` tool schema), so we standardize by
**function**:

**Agent-chosen types** — the types you deliberately pass to `mem_save`. Use one of these:

- `decision` — architectural or design choices with rationale
- `architecture` — system structure, module boundaries, data models
- `bugfix` — bugs found, root causes, and fixes
- `pattern` — conventions established (naming, structure, idioms)
- `config` — configuration changes or environment setup
- `discovery` — non-obvious findings about the codebase or tooling
- `preference` — explicit user preferences about tools or workflow

**Engram-generated types** — engram assigns these; you do not hand-pick them:

- `learning` — produced by `mem_capture_passive` from a `## Key Learnings:` section
- `manual` — the default type when a save supplies no `type`

If engram adds a type in a future version, it joins whichever category fits (something you'd choose
→ agent-chosen; something engram assigns → engram-generated). Do not describe the set by count — the
membership will change, the rule will not. `scripts/validate-memory-types.sh` guards the
agent-chosen list against drift.

## Topic Keys

Use `mem_suggest_topic_key` to get a consistent topic key before saving. This ensures related
memories cluster together for retrieval.

## Memory Hygiene

- Keep memories concise — a few sentences, not paragraphs
- Include the "why" — bare facts without rationale are less useful
- Use project names consistently so memories are findable
- Don't duplicate information that belongs in docs or code comments

## Conflict Relations

Engram surfaces when a new memory may conflict with or supersede an existing one, storing these as
relations with a `judgment_status`. The judge-flow for unjudged (`pending`) relations — when to call
`mem_judge`/`mem_compare` and the ASK-vs-RESOLVE heuristic — is injected automatically by the engram
MCP server's own instructions each session; it is not repeated here.

What that server injection does **not** cover — local dotfiles tooling built on top of engram:

- **Orphaned** — a dangling relation whose source or target observation was deleted. Informational
  only: there is no judge path and no supported cleanup command, so do not attempt to delete
  orphaned relations (that would require unsupported direct-SQL edits that bypass sync). They are
  inert and can be left as-is.
- `bin/engram-hygiene` in `status` mode reports the unjudged count per project; the session-start
  hygiene nudge fires only on unjudged relations for the current project. Orphaned relations are
  intentionally not shown there — engram provides no way to resolve or prune them, so the count only
  grows and is not actionable debt. The raw orphaned count is available via `engram conflicts stats`
  if ever needed.

## Handoff Notices

**First-response obligation:** if session-start context contains a `⚠️ ACTIVE HANDOFF exists` notice
(emitted by the `recall-memory.sh` hook), call `mem_get_observation` on the cited id and read it IN
FULL before doing any other work — a truncated preview cannot carry a handoff, so the notice is a
directive to fetch it, not the handoff itself. A handoff naming an item as "next work" records
what's queued, not that it's refined — if the item is a raw idea, run the idea-refinement funnel
before coding it rather than treating the handoff as approval to implement. A handoff is
authoritative for the live effort state, but its incidental side-claims about repo structure or
tooling (e.g. "directory X is unreadable/unused") are fallible — verify those against the repo
before acting. See the `memory-management` skill's "Handoffs" section for how to write or close one.

When you *write* a handoff for work that will span sessions, end the turn with a suggested **resume
prompt** in chat — a short, pasteable prompt (a few sentences, not a wall of prose) to reopen the
effort that ends in an explicit "…or tell me what you'd rather work on instead." Reading a handoff
is guaranteed by the obligation above; *acting* on it is the user's call, and the resume prompt is
what hands them that choice. See the `memory-management` skill's "Suggesting a resume prompt"
section for the shape.

For writing or closing a handoff, load the `memory-management` skill.
