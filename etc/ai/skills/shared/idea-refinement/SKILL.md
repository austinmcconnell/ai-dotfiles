---
name: idea-refinement
description: Critically analyze, stress-test, and refine project ideas through a lightweight capture-refine-promote funnel using ideas.md, an optional backlog.md, and todo.md. Use when brainstorming next steps, reviewing captured ideas, deciding what to work on next, or asking to stress-test or scope a feature idea.
---

# Idea Refinement

## Purpose

A lightweight funnel for moving work from raw thought to committed action, for solo personal
projects. It sits *upstream* of committed work — the point where an idea is critically analyzed,
stress-tested against the project, scoped, and only then promoted toward planned commits.

This is deliberately **not** a Scrum/Jira process. There are no story points, acceptance-criteria
templates, or user-story boilerplate. That overhead earns its place when coordinating a team; for a
solo project it is friction. Keep the funnel prose minimal and the critique substantive.

## The Three Tiers

The funnel has three states. Only two files are required.

| Tier      | File                                | Holds                                                       |
| --------- | ----------------------------------- | ----------------------------------------------------------- |
| Capture   | `ideas.md` (unrefined)              | Raw ideas, half-formed thoughts, "might want to do this"    |
| Refined   | `ideas.md` (refined) → `backlog.md` | Ideas that survived stress-testing but aren't sequenced yet |
| Committed | `todo.md`                           | Work broken into planned commits, in dependency order       |

- **`ideas.md` is required.** It has two sections: an **Unrefined** capture area and a **Refined**
  area for ideas that have passed critique.
- **`backlog.md` is optional and graduated.** Until it exists, the **Refined** section of `ideas.md`
  *is* the backlog. `backlog.md` is only created when the refined body earns its own file (see Tier
  Transitions).
- **`todo.md` is owned by the `todo` skill** and tied to the `commit-workflow` skill. This skill
  feeds it; it does not redefine it.

See `references/ideas-template.md` and `references/backlog-template.md` for file structure.

## When to Engage

Engage this skill when **beginning planning or ideation work** — not when troubleshooting a specific
bug or executing an already-planned commit. Concretely:

- The user asks for ideas, next steps, or "what should I work on."
- The user floats a new feature or expansion idea.
- The user asks to stress-test, scope, or critique an idea.
- `ideas.md` exists and the user is reviewing or triaging it.
- A handoff or todo item names an idea as "next work" — being *queued* is not evidence it was
  *refined*. Check its funnel tier (Unrefined vs Refined/backlog) before treating it as ready to
  code; if settling its scope surfaces open questions, it belongs back in refinement, not in a
  commit plan.

If `ideas.md` and `todo.md` are auto-loaded into context (they are for the code/docs/ansible
agents), use that content proactively: if the user raises an idea already captured, say so and pick
up where refinement left off rather than starting over.

## Capturing Ideas

When the user floats an idea, append it to the **Unrefined** section of `ideas.md` verbatim enough
to preserve intent. Do not critique at capture time unless asked — capture is cheap and
interruption-free by design.

## Refining Ideas (the core work)

When asked to refine, analyze next steps, or stress-test, work each idea through this critique. Be a
critical partner, not a cheerleader — the value is in finding the weaknesses.

For each idea, produce:

1. **Stress-test against the project.** Does it fit the project's purpose, constraints, and existing
   architecture? What does it conflict with or duplicate? What breaks if it ships?
1. **Scope assessment.** Is the ask too big, too vague, or bundling several changes? Recommend
   splitting, narrowing, or reshaping the ask itself — not just accepting it.
1. **Research flags.** What is unknown and must be settled before committing? Name the specific
   question, not "needs research" in the abstract.
1. **Verdict** — one primary verdict; add a secondary note when an idea genuinely straddles two
   (e.g. "Reshape — also needs research on X before promoting"):
   - **Promote** — survived critique; ready to move to the Refined section (or `backlog.md`).
   - **Reshape** — worth doing but not as asked; record the recommended change to scope/approach.
   - **Needs research** — sound but blocked on a named unknown; stays in Unrefined with the question
     recorded.
   - **Drop** — doesn't fit; record the one-line reason so it isn't re-proposed.

Use the output contract in `references/critique-output.md`. Keep each critique tight — a few
sentences per section, not an essay.

## Promotion

- **Unrefined → Refined**: on a `Promote` verdict, move the idea (with its scope decision) into the
  Refined section of `ideas.md`, or into `backlog.md` if it exists.
- **Refined/backlog → todo**: when an item is validated and the user is ready to commit to it, hand
  it to the `commit-workflow` cadence — break it into atomic commits in dependency order and record
  the plan in `todo.md` (see the `todo` skill's template for its structure). This skill stops at the
  boundary of committed work; `commit-workflow` owns what happens after.

Promotion is a write to git-ignored working files, so it follows the "non-committable work" note in
the `commit-workflow` skill — there is nothing to commit, so say so and move on.

## Detailed Designs

When an item is complex enough to need a worked-out design before it can be broken into commits — a
security fix, a migration, a multi-file refactor — link an implementation guide from the item (see
the `implementation-guide` skill). Reference it as a git-ignored `plan-<slug>.md` in the project
root, e.g. `- Migrate auth to OAuth2 → plan-oauth2-migration.md`.

The guide is a **point-in-time execution snapshot** — the before/after code, exact file paths, and
step order are only true at one moment. It is throwaway and never committed. Durable reasoning (why
the change was made, tradeoffs chosen) belongs in the commit message, not the guide.

Most items do not need a guide. Reach for one only when the design is non-obvious enough that
working it out separately de-risks the commit breakdown.

## Tier Transitions

Recommend restructuring the files based on **behavioral signals, not line counts**. Never nag about
size thresholds.

- **Graduate `ideas.md` refined section → `backlog.md`** when capture and refined work are getting
  *tangled* — the growing body of validated-but-unsequenced items is crowding the raw-capture space
  and making the file hard to scan. The trigger is separation of concerns, not length. Recommend
  creating `backlog.md` and moving the Refined section into it.
- **Consolidate `backlog.md` → `todo.md`** when there is *downstream demand*: `todo.md` is empty or
  nearly done and `backlog.md` holds validated items ready to sequence. The trigger is pull (ready
  for more committed work), not backlog scarcity. Recommend promoting the top items into a commit
  plan.

Surface these as recommendations for the user to accept, not automatic restructures.

## What This Skill Does Not Do

- It does not commit anything (working files are git-ignored).
- It does not redefine `todo.md` — that is the `todo` skill's role.
- It does not import Scrum/Jira structure, story templates, or estimation.
