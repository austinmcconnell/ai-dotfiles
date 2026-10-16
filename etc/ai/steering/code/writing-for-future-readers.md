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

## Relationship to Commit Messages

This is the same principle the `commit-message-writing` skill states for commit messages ("write
from the committed diff") — generalized to every committed artifact, because a committed doc is
permanent repo history in the same sense a commit message is.
