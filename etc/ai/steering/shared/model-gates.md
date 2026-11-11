# Model Gates

Spend the strongest model where a wrong direction is expensive to undo, and a cheaper one where the
direction is set or an error is cheap to catch. A gate is named by its risk, not by the step.

| Gate                                             | Model                                                                                                                                                                                | How                                                            |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- |
| Idea refinement                                  | Matches the idea's depth: mid for scoping a known or simple idea; strongest for an architectural idea, one that crosses components, or one whose stress-test needs adversarial depth | The main session, with the model chosen at session start       |
| Commit plan                                      | Mid; a risky plan gets the doubt check below rather than a stronger main model                                                                                                       | The main session                                               |
| Doubt check on a non-trivial plan or commit      | Strongest                                                                                                                                                                            | A fresh-context reviewer subagent (`doubt-driven-development`) |
| Implementation                                   | Mid                                                                                                                                                                                  | A new session on the mid model, picking up the plan files      |
| Mechanical work (renames, moves, running checks) | Small                                                                                                                                                                                | A small-model subagent, delegated from the main session        |

A risky plan gets its cover from the doubt check, not from a stronger main model: a fresh
strongest-model reviewer leaves the main model and its cache alone, so the main session can plan on
the mid model and still have the plan cross-examined.

## Switch the Main Model Only While Context Is Small

Where prompt caches are per model (they are on Claude Code), switching the main session's model
makes the next request re-read the whole conversation uncached. That cost grows with the session,
so:

- Switch at a session boundary, or early while the context is small, never deep into a long session.
- Let the plan files carry the handoff. When refinement needed the strongest model, refine there,
  record the outcome in `todo.md` (and any `plan-*.md`), then start a fresh session on the mid model
  to plan and implement.
- To step up mid-session, use a fresh-context reviewer or a stronger-model consult the tool offers.
  Either leaves the main session's model and cache alone.
- To step down mid-session, delegate to a small-model subagent rather than switching the main model.
  A subagent starts with its own small context and cache, so it never resets the main session's.

Each tool's mechanics for these gates live in its own README; for Claude Code, see
`etc/claude-code/README.md`.
