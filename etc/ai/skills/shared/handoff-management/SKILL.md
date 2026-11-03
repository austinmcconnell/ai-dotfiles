---
name: handoff-management
description: How to write, close, and resume engram handoffs. Use when writing or closing a cross-session handoff, or resuming an effort from an ACTIVE HANDOFF notice.
---

# Handoff Management

## Handoffs

A **handoff** is the live state of an ongoing effort — "here is where this work stands, pick it up."
It is distinct from a session summary, and the two are not interchangeable:

- **Active handoff** — *mutable current state*. There is exactly **one** active handoff per effort,
  and a new one supersedes the old. This is the "pick up this effort" pointer.
- **Session summary** (`mem_session_summary`) — *append-only history*. You write one per session;
  they accumulate as the trail of "what happened." Engram surfaces the latest via `mem_context`.
- **Durable detail** — *lives on disk* (docs/ or analysis/), not in the handoff. Substantive
  reasoning, framing, tradeoffs, and open questions belong in a versioned file; the handoff only
  points at it. Before a handoff/summary/compact checkpoint, write the detail to its file first —
  prefer updating the one authoritative file for a topic over a new overlapping one.

Use **both**, each for its strength. Do not collapse a handoff into a session summary: doing so
loses the "exactly one active, auto-superseding" property, which is precisely what prevents a stale
handoff from lingering after the work has moved on.

### Writing an active handoff

Save the handoff with `mem_save` using:

- **topic_key**: `handoff/<project>-active` — e.g. `handoff/dotfiles-active`. The stable `-active`
  key makes every new handoff **upsert** the prior one (same `project + scope + topic_key` updates
  in place and bumps `revision_count`), so there is never more than one live handoff per project.
  This is the mechanism, not a convention you must police by hand.
- **type**: an agent-chosen type from `etc/ai/steering/shared/cross-session-memory.md` (usually
  `decision`). `handoff` is **not** a type — it lives only in the topic_key. Adding it as a type
  would reintroduce the type drift that the steering vocabulary exists to prevent.
- **content**: the full handoff body — what is done and committed, unresolved findings, next steps
  in order, and any hard rules (e.g. "user commits himself; never git commit"). For each next step,
  mark its refinement state — a raw/captured idea still needs the idea-refinement funnel
  (stress-test, scope, research flags) before coding; only a *refined, scoped* item is ready for a
  commit plan. Naming a step as "next work" does not make it refined. When a next step lives in the
  idea-refinement funnel, name the artifact and tier that holds its detail (`ideas.md` Unrefined/
  Refined, `backlog.md`, `todo.md`, or a linked `plan-<slug>.md`/`analysis/<slug>.md`) rather than
  restating that detail inline, and instruct the resuming agent to read that artifact *together with
  its owning skill* before acting — the artifact→skill pairing is a stable 1:1 map (`todo.md` →
  `todo`, `ideas.md`/`backlog.md` → `idea-refinement`, a recorded commit plan → `commit-workflow`).
  Spell the pairing out because reading the file is not itself a skill trigger: an agent that opens
  `todo.md` to see what's next may never hit the task-keyed trigger that would load the skill, so
  the handoff must make "read the file AND its skill" explicit rather than hope the trigger fires.
  This is *not* the "list skills to read" anti-pattern — the skill is named as the artifact's owner,
  not as a free-floating reading list, so it never misfires on handoffs whose remaining work isn't
  funnel work at all (operator actions, cross-repo follow-ups, a decision to facilitate), which name
  no funnel artifact and therefore invoke no skill.
- **The structured marker line `ENGRAM-HANDOFF-ACTIVE: handoff/<project>-active` on its own line in
  the body** (e.g. `ENGRAM-HANDOFF-ACTIVE: handoff/dotfiles-active`). This line is **mandatory**,
  not optional. The session-start recall hook (`recall-memory.sh`) seeds an FTS search on the
  `ENGRAM-HANDOFF-ACTIVE` token, then confirms a match by requiring this exact self-referential line
  — because engram search cannot filter by topic_key, the bare token alone would also match any
  memory that merely *mentions* the convention (a correction, this skill), not only real handoffs.
  The `KEY: value` line naming the current project is what distinguishes "this observation *is* the
  active handoff" from "this observation *talks about* handoffs." A handoff written without it is
  silently invisible to the nudge — writing one without it is doing it wrong. Do not paste the exact
  line into prose elsewhere: two matches make the hook fail loud (it will not guess which is
  current). `scripts/validate-memory-types.sh` checks the structured form is documented here.

Then **pin** the handoff (`mem_pin`) and **unpin** the prior one. Pinning is local, unsynced, and
ordering-only — it raises salience in `mem_context` output but carries no lifecycle meaning, so it
does not replace the topic_key upsert.

### Suggesting a resume prompt

After writing or refreshing an active handoff, end the turn by presenting a suggested **resume
prompt** in chat — a short, pasteable prompt (aim for 1–5 sentences; the bar is "not a wall of
prose," not a literal single line) the user can use to open the next session on this effort. The
session-start obligation guarantees the handoff is *read*, not that the user *wants to act on it*
today: a handoff from N days ago is often not what the user came to do this session. The handoff is
a snapshot that may be stale, so if the user's message does not match it, follow the user's message
— a request for unrelated work is the signal that they want something else.

The chat copy is authoritative (the user won't open the engram observation to find it); echo the
same prompt into the handoff body too so a resuming agent can reconstruct it. A good resume prompt:

- **Is a clean, imperative paste** — no trailing questions or offers to the user. The prompt is an
  instruction the next agent follows, so a closing question makes it stop and ask before doing
  anything.
- **Names the target** — repo/project and working dir, so a cold-start agent lands in the right
  place. Name any must-read file by absolute path rather than making the agent discover it.
- **States where the work stands briefly**, including its funnel tier when it's funnel work (e.g.
  "refined but not yet approved — run idea-refinement first", not "start coding").
- **Names the skill the next step needs**, when that step is a mode-entry skill the agent would
  otherwise miss (`idea-refinement` for funnel work, `commit-workflow` before committing
  implementation work, `todo` for open questions). Name only that skill, not the full set — the
  trigger table covers the rest.

The chat message that accompanies the prompt carries the choice instead, in one line, e.g. "Paste
this to continue; if you'd rather work on something else, just say so."

Example:

> Resume the state-geometry simplification handoff in relocation-map-viz
> (`~/projects/.../relocation-map-viz`). It's refined-but-not-approved — run idea-refinement on the
> simplify-tolerance question first (detail in `analysis/state-geometry-simplification.md`), don't
> jump to a commit plan.

A resume prompt is only for work that will actually span sessions — skip it for an effort you're
closing out (see below).

### Closing an effort

When an effort is genuinely finished, overwrite the `handoff/<project>-active` observation with a
closed body that drops the `ENGRAM-HANDOFF-ACTIVE` marker line. The same topic_key upserts it, so
the session-start hook no longer matches it and stops emitting the ACTIVE HANDOFF notice. Then
`mem_unpin` the handoff and write a `mem_session_summary` (the historical record). Not every session
needs a handoff — a one-off task that completes within the session needs only the summary, if
anything. Reserve the active handoff for work that will span sessions.
