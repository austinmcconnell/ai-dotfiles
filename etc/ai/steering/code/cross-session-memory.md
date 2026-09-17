# Cross-Session Memory

## Which Channel: Memory vs Knowledge Base vs Eager Context

An agent has three information channels; reach for the right one rather than defaulting to whichever
is nearest. This boundary is the seam the README-as-pointer scheme routes against (see the
`readme-pointer` skill and `knowledge-base-usage.md`):

- **Persistent memory (engram)** — cross-session *narrative*: decisions and their rationale, failed
  approaches, corrections, handoffs, user preferences. Use engram for "why we did it this way" and
  "what happened last session," not for facts that live in the repo.
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

## Handoff Notices

**First-response obligation:** if session-start context contains a `⚠️ ACTIVE HANDOFF exists` notice
(emitted by the `recall-memory.sh` hook), call `mem_get_observation` on the cited id and read it IN
FULL before doing any other work — a truncated preview cannot carry a handoff, so the notice is a
directive to fetch it, not the handoff itself. A handoff naming an item as "next work" records
what's queued, not that it's refined — if the item is a raw idea, run the idea-refinement funnel
before coding it rather than treating the handoff as approval to implement. See the
`memory-management` skill's "Handoffs" section for how to write or close one.

For how to save, structure, and hand off memories once you've decided to act — session-start recall,
memory types, topic keys, writing/closing a handoff, hygiene, and conflict-relation cleanup — see
the `memory-management` skill.
