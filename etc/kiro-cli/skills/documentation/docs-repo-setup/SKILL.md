---
name: docs-repo-setup
description: Guide for setting up structured documentation repositories with mdBook. Use when creating new docs repos, understanding structure, or avoiding common mistakes in technical documentation projects.
---

# Documentation Repository Setup

## Overview

Set up structured technical documentation repositories using mdBook with proper content separation
(WHAT/HOW/WHY/SPECS). Based on lessons from real projects that underwent major refactorings due to
poor initial structure.

**Key principle:** Establish content ownership model on day 1 to prevent costly refactoring later.

## When to Use This Skill

- Creating a new documentation repository from scratch
- Understanding documentation structure and organization
- Avoiding common documentation mistakes
- Setting up mdBook-based documentation
- Establishing content ownership models

## Architecture

### Stage-Based Structure

Aligns with DITA framework (Darwin Information Typing Architecture):

```text
project-root/
├── planning/          # Requirements and constraints
├── research/          # External research and evaluations
├── decisions/         # Architecture decisions (WHY)
├── components/        # Physical/logical component specs
├── configuration/     # System specifications (WHAT)
└── procedures/        # Implementation steps (HOW)
```

**Why stage-based?**

- Clear separation of concerns
- Supports sequential learning
- Scales well as project grows
- Prevents duplication

**Alternative (not recommended):** Item-based structure breaks WHAT/HOW separation.

### Content Ownership

See `references/templates/agents.md` for the full AGENTS.md template.

configuration/ = WHAT

- Specifications, design, schemas
- Tables, diagrams, reference docs
- Never include implementation steps

procedures/ = HOW

- Step-by-step instructions
- Numbered steps, checklists
- Never duplicate specifications

decisions/ = WHY

- ADRs with context and rationale
- Alternatives and consequences
- Never include implementation details

components/ = SPECS

- Component specifications
- Physical/logical setup
- Performance metrics

### Root-level files

- **README.md** — repo-level introduction for GitHub/contributors (getting started, how to build,
  pre-commit setup). Not included in the book.
- **INTRODUCTION.md** — book introduction for readers (project goals, documentation structure).
  First entry in SUMMARY.md.
- **AGENTS.md** — AI agent guidance for content ownership. Not included in the book.
- **SUMMARY.md** — mdBook table of contents. Use a flat list under `# Table of Contents`. Do not use
  `# Section` headers as sidebar dividers.

### Optional: .kiro/ directory

A `.kiro/` directory is optional. It is only needed for project-specific skill overrides (e.g., a
local `create-adr` skill with project-specific ADR conventions). The global docs agent loads its
skills from `~/.kiro/skills/` — local `.kiro/skills/` takes precedence when present.

## Project Context (Before Setup)

Before scaffolding, gather minimal project context. This input populates book.toml, INTRODUCTION.md,
and planning/requirements.md with meaningful content instead of empty placeholders.

**Required:**

1. **Project name** — used in book.toml `title` and README.md heading
1. **One-sentence description** — used in book.toml `description` and README.md overview
1. **Key requirements or goals** (bullet list) — populates INTRODUCTION.md project goals and seeds
   planning/requirements.md

**Optional:**

1. **Known constraints** (budget, space, power, noise, etc.) — populates the constraints section of
   planning/requirements.md

This is not a formal requirements analysis. A brief statement like "compact, quiet, power-efficient
homelab with PCIe expansion, dual NVMe, and 2 DIMM slots" is enough to generate useful content
across multiple files.

## Quick Start (30 Minutes)

```bash
# 1. Create structure
mkdir -p planning research decisions components configuration procedures
touch README.md INTRODUCTION.md SUMMARY.md AGENTS.md

# 2. Copy templates (see references/templates/)
# 3. Create README.md in each subdirectory
# 4. Set up pre-commit hooks
# 5. Create SUMMARY.md
```

Done! Structure prevents 70% of common refactoring issues.

## Common Patterns

### Adding New Component

1. Create components/[component].md with specifications
1. Add to configuration/[relevant-config].md if needed
1. Create procedures/[component]-setup.md
1. Create ADR if significant decision
1. Update SUMMARY.md
1. Add cross-references
1. Update components/bom.md if project uses a bill of materials

### Changing Specification

1. Update configuration/[spec].md (single source of truth)
1. Verify procedures/ still reference correctly
1. Update affected ADRs if rationale changed

### Cross-Referencing

- Use descriptive link text: `[Configuration: System](../configuration/system.md)`
- Link to directories, not README.md: `[Components](../components/)` not
  `[Components](../components/README.md)` (mdBook compiles README.md to index.html)
- SUMMARY.md is the exception — it requires `README.md` paths for navigation
- Add "Related Documentation" section at end of files
- Reference, never duplicate

## Common Mistakes to Avoid

### ❌ Duplicating Specifications

**Cost:** 135 lines deleted in real project refactoring

**Wrong:** Including full spec table in procedures file

**Right:** "For complete specifications, see [Configuration: X](../configuration/x.md)"

### ❌ Mixing WHAT and HOW

**Cost:** 369 lines removed, 20 files updated in real project

**Wrong:** Configuration file with both specs AND step-by-step UI instructions

**Right:** Separate files - configuration/ for specs, procedures/ for steps

### ❌ No README.md in Subdirectories

**Cost:** Content had to be moved between directories

**Solution:** Create README.md in each subdirectory on day 1 with (see
`references/templates/subdirectory-readme.md`):

- Purpose statement
- Content ownership (WHAT/HOW/WHY/SPECS)
- What belongs here vs elsewhere

### ❌ Generic Procedures

**Cost:** 20 files updated with cross-reference changes

**Wrong:** device-adoption.md with generic steps

**Right:** switch-setup.md, module-setup.md (component-specific)

### ❌ Starting Without Content Ownership Model

**Cost:** 3 major refactorings, 19 commits, ~500 lines deleted

**Solution:** Create AGENTS.md on day 1 documenting content ownership (see
`references/templates/agents.md`)

## Best Practices

### 1. Single Source of Truth

Each specification exists in exactly one place. All other files link to it.

### 2. Cross-Reference Liberally

Link to related content, don't repeat it. Add "Related Documentation" sections.

### 3. Use Templates with Guidance

Add HTML comments: `<!-- WHAT, not HOW -->` to explain separation.

### 4. README.md as Directory Guide

Every subdirectory explains its purpose and content ownership.

### 5. Validation Scripts

Automate quality checks with pre-commit hooks.

### 6. External References in research/

Centralize external links to prevent link rot. Default to a `research/` directory with
`research/README.md` as the index (see `references/templates/research-readme.md` and
`references/templates/research-topic.md`). For very small projects with only a few research links, a
single `RESEARCH.md` file is acceptable (see `references/templates/research.md`).

### 7. Working file for open questions, blockers, and tasks

Use `todo.md` (git-ignored via global `todo*.md` pattern) to track items the repo structure can't
express. This file serves as a session handoff — agents can read it to understand what still needs
to be figured out. See `references/templates/todo.md` for the template.

Three sections:

- **Open questions** — unresolved questions that will become research topics, ADRs, or configuration
  specs
- **Blockers** — external dependencies or waits that prevent progress
- **Tasks** — internal action items (docs review, cleanup, procedures to write)

Resolved items stay with a link to the outcome (e.g., `[x] Question → [ADR-001](...)`) until
actively cleaned out.

**What does not belong here:** Decisions, specifications, or anything that should be the source of
truth. Move items to tracked files as they are resolved.

## Full Setup Checklist

### Repository Setup (10 minutes)

- [ ] Initialize git: `git init`
- [ ] Create .gitignore (exclude book/, .DS_Store)
- [ ] Add README.md with repo-level getting started guide
- [ ] Add INTRODUCTION.md with book introduction
- [ ] Choose mdBook

### Directory Structure (5 minutes)

- [ ] Create directories:
  `mkdir -p planning research decisions components configuration procedures scripts`
- [ ] Create README.md in each subdirectory
- [ ] Create SUMMARY.md

### Content Ownership (15 minutes)

- [ ] Create AGENTS.md with content ownership model
- [ ] Document configuration/ = WHAT
- [ ] Document procedures/ = HOW
- [ ] Document decisions/ = WHY
- [ ] Document components/ = SPECS
- [ ] Add "Common Mistakes to Avoid" section

### Templates (20 minutes)

Copy from `references/templates/` and customize:

- [ ] Create decisions/adr-template.md
- [ ] Create components/component-template.md (see `references/templates/component.md`)
- [ ] Create configuration/config-template.md (see `references/templates/configuration.md`)
- [ ] Create procedures/procedure-template.md (see `references/templates/procedure.md`)
- [ ] Add HTML comments explaining WHAT vs HOW

### Quality Gates (15 minutes)

- [ ] Create .pre-commit-config.yaml
- [ ] Run `pip install pre-commit`
- [ ] Run `pre-commit install`
- [ ] Add validation scripts
- [ ] Test pre-commit hooks

### Shared Resource Registration (5 minutes)

If this repo references or owns resources shared with other repos (IP addresses, switch ports, rack
slots, PDU ports, VLAN assignments), register it in the `cross-repo-audit` skill:

- [ ] Add the repo to the "Repositories and Source Files" section with its owned resources
- [ ] Add any new resource types to the "Ownership Rules" table
- [ ] Run a targeted conflict check: read the authoritative source file for each resource the new
  repo touches and verify no assignments overlap (see the ownership table in `cross-repo-audit`)

### Reference Files (10 minutes)

- [ ] Create research/README.md
- [ ] Create glossary.md
- [ ] Add custom.css (optional)

### mdBook Configuration (10 minutes)

- [ ] Create book.toml (see `mdbook-setup` skill for recommended settings)
- [ ] Test `mdbook serve`
- [ ] Test `mdbook build`
- [ ] Verify navigation

**Total time:** ~90 minutes

## Validation After Setup

### Structure Check

- [ ] All directories have README.md
- [ ] AGENTS.md documents content ownership
- [ ] SUMMARY.md references all main files
- [ ] book.toml configured correctly

### Content Check

- [ ] No duplicate specifications
- [ ] Configuration files contain no implementation steps
- [ ] Procedure files reference (not duplicate) specifications
- [ ] All cross-references use descriptive link text

### Build Check

- [ ] `mdbook serve` runs without errors
- [ ] `mdbook build` completes successfully
- [ ] Navigation works correctly
- [ ] All links resolve properly

### Quality Check

- [ ] Pre-commit hooks installed
- [ ] Pre-commit hooks pass
- [ ] Validation scripts run successfully
- [ ] No linting errors

## Troubleshooting

### "Where does this content belong?"

1. Is it a specification? → configuration/
1. Is it implementation steps? → procedures/
1. Is it a decision rationale? → decisions/
1. Is it component specs? → components/
1. Is it external links, product evaluations, or comparison research? → research/

### "Should I duplicate this spec?"

**No.** Always reference, never duplicate.

### "This procedure needs specs from configuration/"

**Good!** Reference them: "For complete specs, see [Configuration: X]"

### "mdbook build fails"

- Check SUMMARY.md references existing files
- Verify file names match exactly (case-sensitive)
- Check for circular references
- Ensure book.toml is valid TOML

### "Pre-commit hooks fail"

- Run hooks individually to identify issue
- Check .markdownlintrc configuration
- Verify all links are valid
- Fix spelling errors or add to ignore list

## Success Criteria

After setup:

1. ✅ Complete directory structure
1. ✅ Know exactly where each content type belongs
1. ✅ Never duplicate specifications
1. ✅ Working templates for all file types
1. ✅ Quality gates (pre-commit hooks)
1. ✅ Understand WHAT/HOW/WHY separation
1. ✅ Can add content without restructuring

## Time Investment

- **Quick start:** 30 minutes
- **Full setup:** 90 minutes
- **Refactoring avoided:** 10+ hours
- **Net savings:** 8-10 hours

Plus eliminates mental overhead of "where does this belong?"

## Reference Documentation

- `references/directory-structure.md` - Recommended directory layout
- `references/setup-checklist.md` - Day 1 setup checklist
- `references/templates/agents.md` - AGENTS.md content ownership template
- `references/templates/bom.md` - Bill of materials template
- `references/templates/component.md` - Component specification template
- `references/templates/configuration.md` - Configuration specification template
- `references/templates/procedure.md` - Procedure (step-by-step) template
- `references/templates/readme.md` - Repo-level README.md template
- `references/templates/requirements.md` - Planning requirements template
- `references/templates/research.md` - Single-file RESEARCH.md template
- `references/templates/research-readme.md` - Multi-file research/README.md index template
- `references/templates/research-topic.md` - Multi-file research topic file template
- `references/templates/subdirectory-readme.md` - Subdirectory README.md template
- `references/templates/summary.md` - SUMMARY.md table of contents template
- `references/templates/todo.md` - Working file template (open questions, blockers, tasks)

For mdBook-specific setup, see the `mdbook-setup` skill.
