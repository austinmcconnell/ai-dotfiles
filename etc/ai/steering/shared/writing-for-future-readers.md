# Writing for Future Readers

Committed files — research docs, markdown, ADRs, READMEs, frontmatter — are permanent repo history,
read by someone months later with none of this session's context. Write them to stand on their own.

## No Session or Workflow Framing

Do not write transient session/workflow framing into committed text:

- Session identifiers from git-ignored working files (e.g. a `todo.md` "Q2", "item 3")
- "Resolved this session", "as of this re-verification", "round 2 of the cleanup"
- "Changes since <prior session date>", "added <date>" as a narrative of what changed this session

These are invisible in the committed tree and meaningless to a future reader. Describe the *content
and finding itself*, not the workflow that produced it. Transient state belongs in git-ignored
working files (`todo.md`, handoffs), not committed prose.

A verification/source **timestamp** is fine as a factual field (frontmatter `last_verified`, a dated
source line). It is not fine as narrative "what I changed this session" framing.

## No Pointers to Git-Ignored or Temporary Files

A committed artifact must not reference a git-ignored or temporary working file — a future reader
cannot open it, so the pointer dangles. This commonly bites when a committed README or code comment
points at a working/design doc under a git-ignored path (`analysis/`, `todo.md`, a handoff). Restate
the needed substance inline in the committed file instead. Before citing a path in committed text,
confirm it is tracked (`git check-ignore -v <path>` — a match means it is ignored and must not be
cited). Referencing another *tracked* file is fine; the hazard is specifically the git-ignored or
temporary ones.

## Relationship to Commit Messages

This is the same principle the `commit-message-writing` skill states for commit messages ("write
from the committed diff") — generalized to every committed artifact, because a committed doc is
permanent repo history in the same sense a commit message is.
