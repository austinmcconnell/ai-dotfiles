# Mode-Entry Skills

Some skills mark the *entry into a kind of conversation*, not the creation of a particular artifact.
They must be loaded when that mode begins — not after you have already started producing the output,
by which point the skill's cadence can no longer shape the work. These always-on pointers name the
mode; the workflow itself stays in the skill body (README-as-pointer: the principle lives here, the
numbered loop lives in the skill).

- **Before committing any implementation work** — before writing code you intend to commit, load the
  `commit-workflow` skill. It sets the plan → verify → pause-for-review → confirm-it-landed cadence
  (plus, when the work spans several commits, the one-commit-at-a-time discipline), which only helps
  if loaded *before* you start, not after. The cadence applies even to work that turns out to be a
  single commit — only the "one at a time" iteration is multi-commit-specific.
- **Entering planning or ideation mode** — when deciding what to work on, scoping, or stress-testing
  an idea (as opposed to executing an already-agreed plan), load the `idea-refinement` skill. This
  also covers session-start todo tracking: `idea-refinement`'s committed tier is `todo.md`, so
  reaching for it pulls in the `todo` skill's workflow — there is no separate mode-entry trigger for
  `todo`.
- **Before a non-trivial decision stands** — when about to commit non-trivial code, cross a module
  or service boundary, or assert a property a compiler cannot verify (thread-safety, idempotence,
  ordering, invariants), load the `doubt-driven-development` skill. Its value is catching a wrong
  direction *in flight*, while course-correction is cheap, so it must be loaded before the decision
  stands — not after, when it degrades into a post-hoc review. Main-session `code` orchestrator
  only; scoped personas surface the decision rather than run the loop.

These pointers reinforce the mode-keyed rows in `skill-loading-triggers.md`; they do not restate the
trigger table. When in doubt about which skill maps to a task, that table remains the single index —
this file only ensures these mode-entry cases are noticed at the moment the mode begins.
