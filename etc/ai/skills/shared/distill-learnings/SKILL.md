---
name: distill-learnings
description: Review captured corrections in engram and propose exact, reviewed edits promoting durable ones into the specific steering doc or skill they belong to. Use when promoting corrections to steering, distilling learnings, reviewing captured preferences, or when prompted after a correction is captured or a task list completes.
---

# Distill Learnings

Promote captured corrections from engram (the capture tier) into durable steering docs or skills
(the durable tier) — one tight, relevant edit at a time, with per-item user approval.

This is the *promotion* half of the capture-and-promote system. Capture is automatic (see the
`capturing-corrections` steering). Promotion is never automatic: every change is proposed as an
exact edit to a specific file and applied only after the user approves it.

## Core Principles

- **No aggregated dump.** There is no `lessons.md`. Each promoted correction becomes a concise edit
  to the *one* steering doc or skill it belongs to. If nothing fits, propose where a new focused doc
  should live — do not invent a catch-all.
- **User approves every promotion.** Present exact before/after edits and wait for explicit approval
  per item. Never write to a steering doc or skill without it.
- **Frequency is not the gate.** A single important correction ("never force-push main") is
  promotable immediately. A situational one stays in engram. Judgment lives with the user, informed
  by your proposal — do not apply an occurrence-count threshold.
- **Durable ≠ everything.** Corrections too situational to generalize stay in engram and decay.
  Promotion is for rules that will apply again across sessions.

## Workflow

### 1. Gather candidates

Pull captured corrections for the current project from engram:

- `mem_search` with `type: preference` and query terms like `correction`, plus the topic area.
- Corrections are saved under `topic_key: correction/<area>-<slug>` (see `capturing-corrections`
  steering). Prefer `mem_context` to see recent session captures if search is too narrow.
- Skip corrections already marked promoted (see step 5).

If there are no candidates, say so and stop — do not manufacture promotions.

### 2. Classify each candidate

For each correction, decide exactly one destination:

- **A steering doc** (`etc/ai/steering/<domain>/*.md`) — if it's a principle, convention, or rule
  that applies broadly (coding style, git, security, workflow). Steering is always-loaded, so it's
  for rules that should shape every relevant session.
- **A skill** (`etc/ai/skills/<category>/<name>/SKILL.md` or its `references/`) — if it's a
  workflow/procedure detail that belongs to a specific task the skill already covers.
- **Leave in engram** — if it's too situational or project-specific to generalize. State why.

Match to an *existing* doc/skill first. Read the candidate destination before proposing an edit —
respect its scope (one responsibility per doc; see `code-health` steering). Only propose a new file
when no existing home fits, and justify it.

### 3. Propose exact edits

For each promotable correction, present a proposal using the format in
`references/promotion-proposal-template.md`. Each proposal must show:

- The source correction (title + the rule)
- The target file and section
- The exact edit (the concrete lines to add or change, in context)
- A one-line rationale for the destination

Group all proposals in one review so the user can approve, reject, or redirect each. Keep each edit
tight — a sentence or a bullet, not a paragraph. Do not restate what the doc already says.

### 4. Apply approved edits

For each approved item:

- Make the edit with the `write` tool, matching the target doc's existing style and formatting.
- After editing steering or skills, run `pre-commit run --files <changed-files>` (see the
  `pre-commit-validation` skill). If hooks reformat the file, re-read it before any further edit.
- Do **not** commit. Staging and commits remain the user's decision per the git conventions.

### 5. Close the loop in engram

For each promoted correction, mark it so it is not re-proposed next time:

- `mem_update` the observation to note where it was promoted (e.g. append
  `Promoted to: etc/ai/steering/code/git-conventions.md` to its content), **or**
- If the correction is now fully captured by the durable doc, consider whether it still needs to
  live in engram at all. Prefer annotating over deleting — the engram record is cheap and provides
  provenance.

Report a short summary: what was promoted and where, what was left in engram, and what was skipped.

## When NOT to Promote

- The correction duplicates a rule already in steering/skills — skip it (optionally annotate the
  engram record as already-covered).
- The correction is a one-off situational instruction — leave it in engram.
- The correction encodes secrets, credentials, or machine-specific paths — never promote these into
  version-controlled steering; leave them out entirely.

## Validation Checklist

- [ ] Every proposed promotion targets exactly one specific file (no aggregated notes file)
- [ ] Each edit is concise and matches the target doc's style
- [ ] User approved each promotion before it was written
- [ ] `pre-commit` ran on changed files and passed
- [ ] No commit was made without the user asking
- [ ] Promoted corrections annotated in engram so they aren't re-proposed
- [ ] Situational / secret / duplicate corrections were left in engram or dropped, with reasons
