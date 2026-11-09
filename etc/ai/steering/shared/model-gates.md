# Model Gates

Match model strength to the gate, not to each step. Spend the strongest model where a wrong
direction costs the most to undo, and the cheaper models where the direction is already set.

| Gate                                             | Model                                                               |
| ------------------------------------------------ | ------------------------------------------------------------------- |
| Idea refinement, commit plan                     | Strongest, while the context is still small                         |
| Doubt check on a non-trivial plan or commit      | Strongest, as a fresh-context reviewer (`doubt-driven-development`) |
| Implementation                                   | Mid                                                                 |
| Mechanical work (renames, moves, running checks) | Small                                                               |

## Switch the Main Model Only While Context Is Small

Where prompt caches are per model (they are on Claude Code), switching the main session's model
makes the next request re-read the whole conversation uncached. That cost grows with the session,
so:

- Switch at a session boundary, or early while the context is small, never deep into a long session.
- Let the plan files carry the handoff: plan on the strongest model, record the plan in `todo.md`
  (and any `plan-*.md`), then start a fresh session on the mid model to implement.
- To step up mid-session, use a fresh-context reviewer or a stronger-model consult the tool offers.
  Either leaves the main session's model and cache alone.

Each tool's mechanics for these gates live in its own README; for Claude Code, see
`etc/claude-code/README.md`.
