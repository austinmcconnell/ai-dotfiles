# mdBook Conventions

**Purpose**: Content organization conventions for mdBook documentation repositories.

Full reference: `skills/documentation/mdbook-setup/references/mdbook-conventions-reference.md`

## SUMMARY.md Structure

Flat list under `# Table of Contents`. No `# Section` headers as sidebar dividers.

- Introduction links to INTRODUCTION.md (book intro), not README.md (repo-level intro)
- AGENTS.md is excluded — it is AI agent guidance, not reader content

**Section order:** Introduction/README → Planning → Research → Decisions → Components →
Configuration → Procedures

**Within sections:** Alphabetical by default. Logical progression when order matters. ADRs by number
(ascending).

**Indentation:** 2-space, maximum 3 levels. README.md as section overview (parent item).

## File Organization

```text
.
├── INTRODUCTION.md
├── SUMMARY.md
├── {planning,decisions,components,configuration,procedures}/
│   ├── README.md
│   └── *.md
└── images/*.png
```

**File naming:** kebab-case, descriptive (`component-setup.md` not `setup.md`), ADRs as
`adr-NNN-title-with-dashes.md`, README.md for directory overviews (always capitalized).

**Images:** Store in `images/` or alongside document. Descriptive filenames. Relative paths.

## Heading Hierarchy

- H1 (`#`) — Document title, one per file, must match SUMMARY.md entry
- H2 (`##`) — Major sections
- H3 (`###`) — Subsections
- H4 (`####`) — Sub-subsections (use sparingly)

Never skip heading levels.

## Cross-References

Use relative paths from the current file. Link to sections with `#anchor` syntax.

Follow link-conventions.md for link text patterns and formatting standards.

## Admonitions

Use blockquote format (mdBook has no native admonitions):

```markdown
> **Note:** Additional helpful information.

> **Warning:** Potential issues or data loss.
```

Types: **Note** (helpful info), **Warning** (issues/data loss), **Tip** (best practices),
**Important** (critical info).
