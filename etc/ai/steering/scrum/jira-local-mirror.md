# Local `jira/` Mirror Files

Some repos keep a git-ignored `jira/` directory that mirrors their Jira tickets as local markdown —
one file per ticket, named `<project-prefix>-<number>.md` (e.g. `scrn-1677.md`), plus `draft-*.md`
for pre-creation drafts. `code` agents read these files to understand the scope of work, so they
must stay in sync with remote Jira.

## Rule

- **At session start / before Jira work, check whether the repo has a `jira/` directory.** If it
  does, this convention is in force for that repo.
- **When you create or update a Jira ticket, also create/update the matching `jira/<key>.md`** (use
  the lowercased key). Keep the local file in sync with what you changed in Jira.
- **Match the existing files' format** — open a sibling file in the same `jira/` directory and
  mirror its structure rather than inventing a layout.
- **Git-ignored ≠ unused.** These files are agent-readable and load-bearing; do not skip them
  because the directory is untracked, and do not trust a handoff/side-claim that says otherwise over
  what the repo shows.
- Apply the same secret/PII rule as the tickets themselves: reference credentials/auth material by
  shape only; never write tokens, user ids, client IPs, or PHI into these files.

Project-specific layout details (exact section headings, metadata fields) live in that project's own
conventions doc.
