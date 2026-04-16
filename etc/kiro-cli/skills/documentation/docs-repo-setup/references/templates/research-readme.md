# research/README.md Template

Use this template when research content has outgrown a single `RESEARCH.md` file. See the migration
criteria in `references/templates/research.md` for when to switch.

```markdown
# Research & reference materials

Curated resources for [project topic] research.

## Getting started

**Project context** (read first):

- [Requirements](../planning/requirements.md) - Project requirements and constraints

**Then explore**:

- [Topic A](topic-a.md) — [one-line description] + comparison table
- [Topic B](topic-b.md) — [one-line description]
- [Topic C](topic-c.md) — [one-line description] + comparison table
- [Topic D](topic-d.md) — [one-line description]
- [Topic E](topic-e.md) — [one-line description]

## Community resources

- **[Community 1]**: <https://example.com> — [Description]
- **[Community 2]**: <https://example.com> — [Description]
- **[Community 3]**: <https://example.com> — [Description]
```

## Template conventions

- README.md serves as the index — keep it concise (getting started + topic links + community)
- Each topic link includes a one-line description of what the file covers
- Note which topic files contain comparison tables so readers can find evaluations quickly
- Community resources live in README.md, not duplicated across topic files
- Getting started links to requirements (and key ADR if one exists)

## SUMMARY.md placement

When using the directory format, research is a top-level section with children:

```markdown
- [Research](research/README.md)
  - [Topic A](research/topic-a.md)
  - [Topic B](research/topic-b.md)
  - [Topic C](research/topic-c.md)
  - [Topic D](research/topic-d.md)
  - [Topic E](research/topic-e.md)
```

This replaces the single-file appendix entry:

```markdown
---
- [Research & References](RESEARCH.md)
```
