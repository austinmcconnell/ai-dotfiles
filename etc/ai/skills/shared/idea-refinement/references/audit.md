# Funnel Audit

Leave only items that are still open, each stated briefly. Applies to `ideas.md`, `backlog.md`,
`todo.md`, and the `plan-*.md` / `analysis/*.md` files they link.

## Workflow

1. **Read** the funnel files and the `idea-refinement` and `todo` skills first.
1. **Verify every item against evidence** before judging it. Do not judge from the item's own
   wording; it may be stale.
   - Git history: pickaxe (`git log -S'<string>'` / `-G'<regex>'`), `git log -- <path>`, and
     `git show <sha>` with the full multi-line body. Never `--oneline`; the WHY is in the body.
   - Current files: grep or read what the item claims is missing or present.
   - Other trackers: an item may already be tracked elsewhere (another repo's `todo.md`).
1. **Treat the user's hypotheses as tests, not facts.** Confirm or refute each with evidence; report
   the ones that turn out partly wrong (a feature that shipped but is inert, a "no caller" script
   with a caller in another repo, a count that is higher than stated).
1. **Check the links.** A `plan-<slug>.md` no remaining item points to is an orphan candidate. A
   `→ <file>` pointer to a missing file is broken. A plan whose work landed is obsolete.
1. **Check tier placement.** Each item must sit in the file matching its tier:
   - `ideas.md` holds only unrefined ideas. An item carrying a scope decision, verdict, or critique
     is refined and moves to `backlog.md`.
   - `backlog.md` holds refined, unsequenced work. An item with no scope decision goes back to
     `ideas.md`; one already broken into a commit plan belongs in `todo.md`.
   - `todo.md` holds work with a planned commit breakdown. A raw or unplanned idea goes back
     upstream.
1. **Present one proposal, then pause.** Three groups, each row with commit or file evidence, plus
   any tier moves as a fourth group (item, from file, to file):
   - **Remove**: done, dropped, or obsolete.
   - **Keep, trimmed**: still open, restated briefly.
   - **Keep, evidence changed**: still open but the item's premise or scope is no longer accurate.
   - **Move**: still open but in the wrong tier file.
1. **Wait for approval.** The verdict is the user's call. Deleting a git-ignored plan file cannot be
   undone, so name each file to delete in the proposal.
1. **Apply the whole approved proposal** in one pass.

## Rules for the edit

- A finished item is removed. A dropped idea is removed with no breadcrumb or "dropped" note.
- Removal is a move, not a copy: leave no "done, see commit X" trailing text.
- A long open item is trimmed to one line plus short sub-items. Reasoning worth keeping goes in
  `analysis/<slug>.md`, leaving only a `→ <file>` pointer on the item.
- Decision records and upstream feature requests are not work items: condense to one line or remove.
- Nothing is committed (working files are git-ignored). Say so; a new `analysis/` file may be
  tracked or ignored, so check with `git check-ignore -v`.
