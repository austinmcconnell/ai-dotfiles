# Capturing Corrections

## Why This Matters

Corrections, redirections, and stated preferences are the highest-value signal a user gives during a
session — they encode how the user wants work done. If they are not captured, they are lost when the
session ends, and the same mistake recurs next session. This rule makes capture a **standing
behavior**, not something the user has to request.

This is the *capture* half of a two-tier system: corrections are captured to engram immediately
(cheap, searchable, decays if unimportant), and later promoted to durable steering/skills only after
explicit user review via the `distill-learnings` skill. Capture is automatic; promotion is not.

## When to Capture

Save a memory **immediately** — without being asked — when the user:

- Corrects an approach ("no, use X", "that's wrong", "don't do Y")
- Redirects mid-task ("actually, do it this way instead")
- States a preference about tools, style, or workflow ("I prefer…", "always…", "never…")
- Rejects a tool action and explains why
- Says "remember this" or an equivalent explicit marker

Do **not** capture: simple factual questions, clarifications that don't change behavior, or one-off
situational instructions that won't apply again.

## How to Capture

Use `mem_save` with this exact shape so corrections are consistently findable:

- **type**: `preference`
- **topic_key**: `correction/<area>-<short-slug>` — e.g. `correction/python-quote-style`,
  `correction/git-no-force-push`, `correction/pr-description-format`. Use `mem_suggest_topic_key` if
  unsure, then normalize it under the `correction/` prefix.
- **title**: a short, searchable imperative — e.g. "Use single quotes for Python strings"
- **content**: the What/Why/Where/Learned structure. Capture the *rule*, the *reason* the user gave,
  and (if known) *where* it should eventually live (a steering doc or skill).

The `correction/` topic_key prefix is the retrieval handle: the `distill-learnings` skill and the
promotion-prompt hook both find candidates by searching that prefix. Reusing a topic_key updates the
existing correction rather than duplicating it.

## What Happens Next

Captured corrections stay in engram until you review them. When a correction is captured, a prompt
to run the `distill-learnings` skill surfaces on your next turn — a reminder, not an automatic
action. That skill proposes promoting durable corrections into the specific steering doc or skill
they belong to, always with your per-item approval. Corrections that are too situational to promote
simply remain in engram and decay over time.

## What NOT to Do

- Do not batch corrections to save "at the end" — capture each one when it happens, so nothing is
  lost to a forgotten end-of-session save.
- Do not write corrections into a catch-all notes file. engram is the capture tier; steering and
  skills are the durable tier. There is no aggregated `lessons.md`.
- Never store secrets or credentials in a correction memory (the `block-memory-secrets` hook guards
  this, but do not rely on it).
