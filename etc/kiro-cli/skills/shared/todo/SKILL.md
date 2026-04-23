---
name: todo
description: Create and maintain git-ignored todo.md working files for tracking open questions, blockers, and tasks. Use when starting a session in a project, when unresolved items arise, or when asked about todo.md conventions.
---

# Todo Working File

## Purpose

`todo.md` (git-ignored via global `todo*.md` pattern) tracks items the repo structure can't express:
open questions, blockers, and tasks. It serves as a session handoff — check it when starting a
session to understand what still needs to be figured out.

## Template

See `references/todo-template.md` for the file structure.

## When to create

Create `todo.md` in the project root when:

- Unresolved questions arise during a session
- External blockers prevent progress
- Internal tasks need tracking (docs review, cleanup, procedures to write)

## When to check

Check for `todo.md` at the start of every session. If it exists, read it to understand open items
before starting new work.

## Conventions

### Resolving items

Mark items as done with `[x]` and add a link to the outcome:

```markdown
- [x] Which platform to use? → [ADR-001](decisions/adr-001-platform-selection.md)
- [x] Write initial setup procedure → [Procedure: Initial Setup](procedures/initial-setup.md)
```

Resolved items stay in the file until actively cleaned out. They provide context for how decisions
were reached.

### What does not belong here

Decisions, specifications, or anything that should be a source of truth. Move items to tracked files
as they are resolved — todo.md is a scratchpad, not a permanent record.

### Cleanup

Periodically remove resolved items that no longer provide useful context. No strict schedule — clean
up when the file gets noisy.
