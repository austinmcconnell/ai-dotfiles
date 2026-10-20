---
name: ticket-writing
description: Cross-cutting rules for writing any Jira ticket (Story, Task, Bug) — section discipline, acceptance-criteria count, sensitive-data handling, scannability, and what to omit. Use when creating or editing any Jira ticket/issue, or when deciding which sections a ticket needs.
---

# Ticket Writing

Rules that apply to **every** Jira ticket type. For type-specific templates and guidance, see the
per-type skills:

- **Story** (including system-behavior/technical work) → `user-story-writing`
- **Bug** → `bug-ticket-writing`
- **Task** → template is defined in this skill (below)

A Story covers both user-facing features and system-behavior/technical work; the latter uses the
same Story template plus an optional Technical Implementation section.

## Cross-Cutting Rules

### Every ticket

Lead with a problem/context section and end with Acceptance Criteria. Everything else is
type-specific or optional.

### Acceptance Criteria

- **Target 2–4 criteria** (an optional 5th only when the case genuinely needs it). Fewer means
  under-specified; more means the ticket should be split.
- Each criterion is binary pass/fail and describes observable behavior, not implementation.
- Prefer measurable statements over adjectives ("returns 503 with a test", not "handles errors
  gracefully").
- Always cover the unhappy path. Never duplicate Definition-of-Done items (tests written, reviewed).
- No terse unverifiable one-liners — "A/C: it works" is an AC in name only.

### Sensitive data

Sensitivity is a gradient, not a binary.

- **Organization details (names, UUIDs) are fine** — organizations are not people.
- **Minimize person-identifying info.** Prefer, in order: role/persona ("a care coordinator") >
  first-name-last-initial > a person's account UUID > full name (worst). Use the least-identifying
  form that still does the job; a person UUID is acceptable when an identifier is genuinely needed.
- **Never** put secrets, tokens, or credentials in a ticket (or its `jira/` mirror) — reference them
  by shape only.

### Omit by default

Do not add these sections unless they carry weight the reader actually needs:

- Sequencing / ordering narrative (use issue links instead)
- Risk / Rollback
- Logging and Observability, Error Handling, Performance Requirements (generic boilerplate)
- Priority Justification
- Essay-style justification of the approach (that belongs in a PR or ADR)

### Out of scope (optional)

A single, tightly-bounded **Out of scope** line is allowed when it genuinely prevents scope creep
(e.g. "Out of scope: the V1 pipeline"). It must stay one bounded line/bullet — not a multi-paragraph
deferral discussion. If deferred work is substantial, it is its own ticket, not a section here.

### Dependencies are links, not prose

Record real functional dependencies as Jira issue links (Blocks / is-blocked-by), never as prose in
the body. A Blocks / is-blocked-by link must never point at a Done ticket — already-shipped work
can't be an active dependency. A generic associative link (Relates to) to a Done ticket is fine when
it's genuinely useful context. Either way, link by relevance: a recent, directly-related ticket is
worth linking; avoid stale/archaeological links (years old or many hundreds of numbers back). Leave
existing links in place even if their target later became Done.

### Scannable and durable

- Lead each section with a one-line statement; push numeric detail and enumerations into tables.
- Keep the summary (title) short — a title, not a sentence restating the body.
- Plain words over jargon coinages. Reserve exact technical terms (identifiers, config keys).
- No session or workflow framing ("re-scoped this session", "as we found"). A dated incident or
  verification fact is fine as a factual field; narrating what changed this session is not.

### Fields are PO/EM's, not the body

Never put issue type, priority, labels, or story points in the description. These are set by the
Product Owner / Engineering Manager during triage — at creation **and** when editing an existing
ticket. Surface a suggestion; do not change them on your own initiative.

## Task Template

A Task is scoped engineering work that is not a user-facing Story and not a defect (Bug). It uses a
lighter four-section shape — no persona line.

```text
Background
[Why this matters; the context a reader needs to understand the work]

Current Issue
[The specific problem or gap as it exists now]

Proposed Change
[What will change, at a high level — not a step-by-step implementation]

Acceptance Criteria
- [Observable, testable completion condition]

Out of scope   (optional — one tightly-bounded line)
```

Apply all cross-cutting rules above. Keep Acceptance Criteria to 2–4 (optional 5th), each testable.

## Validation Checklist

- [ ] Leads with problem/context, ends with Acceptance Criteria
- [ ] 2–4 acceptance criteria (optional 5th), each binary and observable
- [ ] No person full-names/secrets in the body; org data and minimal identifiers only
- [ ] No omit-by-default sections unless genuinely needed
- [ ] Any Out-of-scope note is a single bounded line
- [ ] Dependencies are issue links (not prose); no Blocks/is-blocked-by link points at a Done ticket
  (a Relates-to a recent, relevant Done ticket is fine); new links aren't stale; existing links left
  as-is
- [ ] No session/workflow framing; scannable sections with tables for detail
- [ ] Type/priority/labels/points left for PO/EM
