# Commit Workflow

This is the default cadence for multi-step implementation work. It applies when a task naturally
breaks into more than one commit. The user may override any part of it ("just do the whole thing",
"go ahead and commit yourself") — treat it as the default, not a straitjacket.

## The Loop

1. **Determine scope.** Clarify what the task covers before touching code.
1. **Plan the commits.** Read the `commit-message-writing` skill, then break the work into atomic
   commits along logical boundaries, in dependency order. One logical change per commit. Present the
   plan and wait for approval before starting.
1. **Record the plan.** After the user approves, check for a `todo.md` (see the `todo` skill) and
   record the approved commit plan there. If none exists and the work spans multiple commits, offer
   to create one.
1. **Work one commit at a time.** Implement exactly one commit's worth of work, then stop. Do not
   run ahead into the next commit.
1. **Verify before pausing.** Run the project's build/tests/pre-commit for the change (see
   `verification-loop` and `pre-commit-validation` skills). Fix what breaks before presenting.
1. **Pause for review, and suggest a commit message.** Present the finished work and a suggested
   message that follows the `commit-message-writing` skill (subject ≤72 chars imperative; exactly
   one context paragraph; change-list bullets). Do not commit unless the user has said to.
1. **Act on feedback.** If the user asks for changes, make them and re-verify before pausing again.
1. **After the user commits, verify it landed.** Run `git log -1` (and `git status` for a clean
   tree). Then mark that commit's item done in `todo.md`.
1. **Continue** with the next commit's worth of work, repeating from step 4, until the plan is
   complete.

## Notes

- **Plan before writing, not after.** Do steps 1–3 (scope → plan + get approval → record in todo.md)
  *before* editing any file. The commit message itself is written after the change (you can only
  describe work that exists) — what must come first is the agreed plan, not the message. Having this
  steering loaded is not the same as executing it.
- **The user commits by default.** Do not create commits unless the user explicitly asks you to
  (this reinforces `git-conventions.md` Commit Discipline). The default is: you prepare and verify,
  the user commits.
- **Commits never cross repos.** If a change spans repositories, it is at least one commit per repo,
  sequenced by dependency.
- **Pausing is per commit, not per file.** Finish a whole logical change before pausing, not each
  edit.
- **Non-committable work** (e.g. git-ignored analysis docs) still follows the plan/verify rhythm,
  but there is nothing to commit — say so and move on rather than waiting for a commit that will not
  happen.
