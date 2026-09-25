---
name: readme-pointer
description: Navigate a project's documentation via README-as-pointer, treating the nearest README.md as a map and following its one-hop pointers to detailed docs on demand. Use when exploring an unfamiliar project, looking for documentation on a topic, deciding whether a doc exists before searching, or authoring a README that should point to detailed docs.
---

# README as Pointer

## Purpose

A `README.md` is a thin, always-relevant **map** of the docs at its directory level — not the docs
themselves. It names the specific detailed doc to read for a given topic and when to read it, so the
agent can pull the right document on demand instead of eager-loading a whole `docs/` tree.

This is the navigation half of the auto-loaded-doc-context design: the eager-context layer stays
thin (a README as signpost), and the detailed docs live in the retrieval channel, fetched with
`read`/`grep` only when a pointer says they are relevant. Eager-loading whole documentation trees
measurably degrades answer accuracy (context rot) before the window is even full — the pointer model
avoids that cost while keeping the agent aware of what exists.

## How to navigate (reading)

When exploring a project or looking for documentation on a topic:

1. **Read the nearest `README.md` as a map.** Start at the project root; when working inside a
   subdirectory, read that directory's `README.md` too if one exists. Treat it as an index of what
   documentation exists here, not as the full answer.
1. **Follow one-hop pointers to the target doc.** A pointer names an actual detailed doc
   (`docs/<topic>.md`), not another README. Read that target doc directly with `read`.
1. **Do not chain README → README → doc.** Agents reliably follow a single plain-text pointer but
   bail on chained ones. If the root README points at a subdirectory rather than a doc, look for a
   direct pointer to the target; don't hop through a second index expecting it to relay you further.
1. **Fall back to search when no pointer matches.** If the README's map has no entry for the topic,
   use `grep`/`glob` to locate docs directly, or the knowledge base if the repo is indexed. A
   missing pointer means "not mapped," not "does not exist."

## How to author (writing a README map)

When writing or updating a README that should point to detailed docs:

- **One line per important doc**, naming the file and when to read it — e.g.
  `- For the <topic>, read docs/<topic>.md`.
- **One-hop rule (hard constraint):** each pointer names the *actual target doc*, never another
  README. If a chain is genuinely unavoidable, use a mechanical include, not a plain-text pointer —
  only mechanical includes chain reliably.
- **Flat, not deep (hard constraint):** one level of indexing. Do not build a tree of nested index
  files that re-creates context pressure — deeper hierarchy hurts navigation, it does not help.
- Keep the map to high-signal docs. A README that lists everything is as useless as one that lists
  nothing; name the docs a reader would actually need to find.
- **These constraints govern the map, not the target docs.** One-hop and flat apply to how README
  pointers are structured. They do not limit how much a target doc — the JIT/retrieval-channel doc a
  pointer leads to — contains. Growing a target doc's content is not doc-sprawl; only adding it to
  eager-context, or adding another pointer hop, is.

## Narrow exception: eager-loading a doc

The default is to point, not preload. Expand a pointer into a full eager-load (a `file://<path>`
resource entry, kiro-cli only) *only* for a single small, stable, high-signal doc where
whole-document reasoning genuinely helps every session — e.g. a compact architecture overview. This
is a deliberate, named per-repo exception, never a `file://docs/*.md` glob. When in doubt, point.

## Tool parity

- **kiro-cli** loads the top-level `README.md` eagerly (via each agent's `file://README.md`
  resource); nested READMEs and the docs they point to are pulled on demand with `read`/`grep`.
- **Claude Code** has no per-project relative `resources` mechanism, so nothing auto-loads — this
  skill *is* the parity mechanism. On entering a project, read the nearest `README.md` as a map and
  follow its one-hop pointers, exactly as above. Functional (skill-driven) coverage, not automatic
  (context-preloaded).
