---
name: create-docs-research
description: Create project-specific research files in documentation repositories. Use when adding research topics, product evaluations, or comparison tables to a project's research/ directory.
---

# Create Docs Research

## Scope

This skill creates research content within a documentation project's `research/` directory. It is
for **project-specific** research — evaluations and comparisons that inform decisions for a
particular project.

**Cross-cutting research** (product lineups, technology comparisons useful across projects) lives in
`$PROJECTS_DIR/austinmcconnell/_research_/` and is managed by the `create-research` skill via the
default agent. The docs agent can search cross-cutting research via its knowledge base but does not
write to it.

## Templates

- **[research-readme-template.md](references/research-readme-template.md)** — index for the
  `research/` directory (getting started, topic links, community resources)
- **[research-topic-template.md](references/research-topic-template.md)** — individual topic file
  (comparison table, key findings, deep-dives)

## Workflow

### Step 1: Check existing research

1. List files in `research/` directory
1. Read `research/README.md` to understand existing topics
1. Verify no file already covers this topic

### Step 2: Create topic file

1. Generate filename: `research/[topic-name].md` (kebab-case)
1. Use `references/research-topic-template.md` as the starting structure
1. Not every topic needs a comparison table — omit it for single-product evaluations or reference
   collections

### Step 3: Update research/README.md

Add the new topic to the "Then explore" list:

```markdown
- [Topic Name](topic-name.md) — [one-line description] + comparison table
```

Note which topics contain comparison tables so readers can find evaluations quickly.

### Step 4: Update SUMMARY.md

Add the new topic under the Research section:

```markdown
- [Research](research/README.md)
  - [Topic Name](research/topic-name.md)
```

### Step 5: Cross-reference related files

1. Link to requirements: `[Requirements](../planning/requirements.md)`
1. Link to ADRs this research informs: `[ADR-NNN: Title](../decisions/adr-NNN-title.md)`
1. Link to related research topics: `[Research: Other Topic](other-topic.md)`

## Populating research/README.md

If the project was scaffolded with cookiecutter-docs, `research/README.md` exists but is minimal.
Use `references/research-readme-template.md` to flesh it out as topics are added.

## Validation Checklist

- [ ] File is in `research/` directory with kebab-case name
- [ ] Comparison tables use emoji indicators (✅/❌/⚠️) for quick scanning
- [ ] Key findings state opinionated conclusions, not neutral summaries
- [ ] Deep-dive entries include Limitations and Relevance fields
- [ ] No specifications included (those belong in `configuration/`)
- [ ] No decision rationale included (those belong in `decisions/`)
- [ ] research/README.md updated with new topic
- [ ] SUMMARY.md updated
- [ ] `mdbook build` succeeds

## Common Mistakes

- Putting specifications in research files — research informs decisions, specs go in
  `configuration/`
- Writing neutral summaries instead of opinionated conclusions in key findings
- Forgetting to update research/README.md and SUMMARY.md
- Duplicating community resources across topic files — keep them in README.md only
