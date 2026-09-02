# Cross-Session Memory

## When to Save Memories

Save to engram (`mem_save`) when:

- Making an architectural decision with rationale
- Discovering a failed approach (what was tried, why it failed)
- Establishing a project convention not documented elsewhere
- Completing a significant milestone in multi-session work
- Finding a non-obvious workaround or solution
- Receiving explicit user preferences about workflow

## When NOT to Save Memories

Never store:

- Secrets, credentials, API keys, tokens, or passwords
- Contents of .env files or encrypted secrets
- SSH keys or certificate material
- Personally identifiable information (PII)
- Temporary debugging state that won't matter next session
- Information already captured in project docs, READMEs, or steering files

## How to Use Memory

### Session Start

At the beginning of a session, if the user describes a task or project:

1. Use `mem_search` with relevant keywords to find prior context
1. Use `mem_context` to get recent session history for the project
1. Mention relevant findings briefly: "From a previous session, I recall..."

Do NOT dump all memories into the response. Surface only what's relevant to the current task.

### During Work

Save memories at natural breakpoints — not after every small action. Good triggers:

- "We decided to use X instead of Y because..."
- "Approach X failed because of Z — don't retry without fixing Z first"
- "User prefers [specific workflow/style/tool]"

Use descriptive titles and the What/Why/Where/Learned structure.

### Memory Types

Engram's `type` field is free text — the store accepts any value and enforces nothing at runtime. So
drift is prevented by convention, not by engram. Engram itself publishes **two** authoritative type
lists that do not fully agree: the README Memory Protocol (`bugfix`, `decision`, `architecture`,
`discovery`, `pattern`, `config`, `preference`) and the `mem_save` tool schema embedded in the
binary (`decision`, `architecture`, `bugfix`, `pattern`, `config`, `discovery`, `learning`, default
`manual`). Rather than pick one, we standardize by **function**:

**Agent-chosen types** — the types you deliberately pass to `mem_save`. Use one of these:

- `decision` — architectural or design choices with rationale
- `architecture` — system structure, module boundaries, data models
- `bugfix` — bugs found, root causes, and fixes
- `pattern` — conventions established (naming, structure, idioms)
- `config` — configuration changes or environment setup
- `discovery` — non-obvious findings about the codebase or tooling
- `preference` — explicit user preferences about tools or workflow

**Engram-generated types** — you do not hand-pick these; engram assigns them:

- `learning` — produced by `mem_capture_passive` from a `## Key Learnings:` section
- `manual` — the default type when a save supplies no `type`

The functional split is what matters: if engram adds a type in a future version, it joins whichever
category fits (something you'd choose → agent-chosen; something engram assigns → engram-generated).
Do not describe the set by count — the membership will change, the rule will not.
`scripts/validate-memory-types.sh` guards the agent-chosen list against drift.

### Topic Keys

Use `mem_suggest_topic_key` to get a consistent topic key before saving. This ensures related
memories cluster together for retrieval.

## Handoffs

A **handoff** is the live state of an ongoing effort — "here is where this work stands, pick it up."
It is distinct from a session summary, and the two are not interchangeable:

- **Active handoff** — *mutable current state*. There is exactly **one** active handoff per effort,
  and a new one supersedes the old. This is the "pick up this effort" pointer.
- **Session summary** (`mem_session_summary`) — *append-only history*. You write one per session;
  they accumulate as the trail of "what happened." Engram surfaces the latest via `mem_context`.

Use **both**, each for its strength. Do not collapse a handoff into a session summary: doing so
loses the "exactly one active, auto-superseding" property, which is precisely what prevents a stale
handoff from lingering after the work has moved on.

### Writing an active handoff

Save the handoff with `mem_save` using:

- **topic_key**: `handoff/<project>-active` — e.g. `handoff/dotfiles-active`. The stable `-active`
  key makes every new handoff **upsert** the prior one (same `project + scope + topic_key` updates
  in place and bumps `revision_count`), so there is never more than one live handoff per project.
  This is the mechanism, not a convention you must police by hand.
- **type**: an agent-chosen type from the Memory Types list (usually `decision`). `handoff` is
  **not** a type — it lives only in the topic_key. Adding it as a type would reintroduce the type
  drift the Memory Types section exists to prevent.
- **content**: the full handoff body — what is done and committed, unresolved findings, next steps
  in order, and any hard rules (e.g. "user commits himself; never git commit").
- **The sentinel token `ENGRAM-HANDOFF-ACTIVE` on its own line in the body.** This token is
  **mandatory**, not optional. The session-start recall hook (`recall-memory.sh`) finds the active
  handoff with an FTS5 search, and FTS5 needs a literal term to match on. A handoff written without
  the sentinel is silently invisible to the nudge — writing one without it is doing it wrong.
  `scripts/validate-memory-types.sh` treats the token as part of the convention.

Then **pin** the handoff (`mem_pin`) and **unpin** the prior one. Pinning is local, unsynced, and
ordering-only — it raises salience in `mem_context` output but carries no lifecycle meaning, so it
does not replace the topic_key upsert.

### Closing an effort

When an effort is genuinely finished, write a `mem_session_summary` (the historical record) and stop
refreshing the `handoff/<project>-active` pointer. Not every session needs a handoff — a one-off
task that completes within the session needs only the summary, if anything. Reserve the active
handoff for work that will span sessions.

## Memory Hygiene

- Keep memories concise — a few sentences, not paragraphs
- Include the "why" — bare facts without rationale are less useful
- Use project names consistently so memories are findable
- Don't duplicate information that belongs in docs or code comments

## Conflict Relations

Engram surfaces when a new memory may conflict with or supersede an existing one, storing these as
relations with a `judgment_status`. Two states matter in practice:

- **Unjudged** (`pending`) — a relation awaiting a verdict. This is the only actionable state. The
  intended resolution is the agent conversation flow: read both memories and record a verdict with
  `mem_judge` (for a candidate surfaced by `mem_save`) or `mem_compare` (for a proactive semantic
  comparison). Verdicts are `related` | `compatible` | `scoped` | `conflicts_with` | `supersedes` |
  `not_conflict`. Resolving these stays user-approved — surface the verdict and confidence before
  recording when the call is non-obvious.
- **Orphaned** — a dangling relation whose source or target observation was deleted. Informational
  only: there is no judge path and no supported cleanup command, so do not attempt to delete
  orphaned relations (that would require unsupported direct-SQL edits that bypass sync). They are
  inert and can be left as-is.

`dotfiles memory-check` reports the unjudged count per project; the `agentSpawn` hygiene nudge fires
only on unjudged relations for the current project. Orphaned relations are intentionally not shown
there — engram provides no way to resolve or prune them, so the count only grows and is not
actionable debt. The raw orphaned count is available via `engram conflicts stats` if ever needed.
