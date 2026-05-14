---
name: docs-review
description: Review documentation for content ownership violations, duplicate specifications, and structural issues. Use when reviewing docs, auditing documentation structure, validating WHAT/HOW/WHY separation, or checking for content duplication.
---

# Documentation Review Skill

## Overview

Systematically review documentation repositories to identify content ownership violations, duplicate
specifications, broken cross-references, and structural issues.

## When to Use This Skill

- Reviewing existing documentation for quality and compliance
- Auditing documentation structure before major changes
- Validating that WHAT/HOW/WHY/SPECS separation is maintained
- Checking for duplicate specifications across files
- Verifying cross-reference completeness and accuracy
- Ensuring SUMMARY.md reflects actual file structure

## Review Workflow

### Step 1: Understand Project Structure

1. Read `AGENTS.md` or `README.md` for project-specific conventions
1. Check `SUMMARY.md` to understand intended structure
1. Check for `todo.md` — if it exists, read it to understand prior unresolved items
1. Identify content directories: `configuration/`, `procedures/`, `decisions/`, `components/`
1. Note any project-specific naming conventions or patterns

### Step 2: Content Ownership Audit

Review each file for proper content type separation:

**Check configuration/ files (WHAT):**

- [ ] Contains only specifications, not implementation steps
- [ ] No "click here" or UI navigation instructions
- [ ] Tables and diagrams for specifications
- [ ] References to procedures/ for implementation
- [ ] Single source of truth for each specification

**Check procedures/ files (HOW):**

- [ ] Contains step-by-step instructions
- [ ] References configuration/ instead of duplicating specs
- [ ] Includes verification steps
- [ ] No duplicate specification tables
- [ ] Links to relevant configuration files in Prerequisites

**Check decisions/ files (WHY):**

- [ ] Follows ADR format (MADR or project-specific)
- [ ] Contains context, options, decision, consequences
- [ ] No implementation details (links to procedures/ instead)
- [ ] No duplicate specifications (links to configuration/ instead)

**Check components/ files (SPECS):**

- [ ] Contains component specifications and capabilities
- [ ] No system-level assignments (belongs in configuration/)
- [ ] No implementation steps (belongs in procedures/)
- [ ] References configuration/ for how component is used

**Check components/bom.md (if exists):**

- [ ] Links to components/ for details — does not duplicate specifications
- [ ] Every component in components/ has a corresponding BOM entry
- [ ] BOM prices match the actual prices in component files (ledger accuracy)
- [ ] Status tracking is current (Bought / Needed / On order)
- [ ] Unit prices are pre-tax, pre-shipping per pricing conventions

### Step 3: Duplicate Specification Detection

Search for duplicate content across files:

1. **Identify specification tables** - Look for tables in multiple files
1. **Check for repeated values** - Values (IDs, addresses, names) appearing in multiple places
1. **Look for repeated lists** - Component lists, feature lists, requirement lists
1. **Find duplicate diagrams** - Same diagram in multiple files

**Common duplication patterns:**

- Specification tables in both configuration/ and procedures/
- Component specifications in both components/ and configuration/
- Policy or rule definitions in both configuration/ and procedures/
- Configuration values scattered across multiple files

**How to fix:**

- Keep specification in ONE file (usually configuration/)
- Replace duplicates with cross-references
- Update procedures/ to reference, not duplicate

### Step 4: Cross-Reference Validation

Check that cross-references are complete and accurate:

**Verify link text patterns:**

- [ ] Uses descriptive patterns: `[Configuration: X]`, `[Procedure: Y]`, `[ADR-NNN: Z]`
- [ ] No "click here" or "see here" links
- [ ] No bare URLs in documentation

**Check link targets:**

- [ ] All internal links use relative paths
- [ ] Links point to existing files
- [ ] Section anchors are correct
- [ ] External links use absolute URLs
- [ ] Links to subdirectory overviews use directory paths (`../configuration/`), not README.md paths
  (`../configuration/README.md`) — mdBook compiles README.md to index.html, so README.md links
  produce broken README.html references. SUMMARY.md is the only place that uses README.md paths.

**Verify cross-reference completeness:**

- [ ] Procedures/ files link to relevant configuration/ files
- [ ] Configuration/ files link to implementation procedures/
- [ ] ADRs link to related decisions
- [ ] Components/ files link to configuration/ where used

**Tools to use:**

```bash
# Check for broken links
mdbook build

# Or use linkcheck
mdbook-linkcheck

# Search for bare URLs
grep -r "http" . | grep -v "\[.*\](http"

# Find "click here" anti-pattern
grep -ri "click here" .
```

### Step 5: SUMMARY.md Accuracy

Verify SUMMARY.md matches actual file structure:

1. **Check for missing files** - Files exist but not in SUMMARY.md
1. **Check for dead links** - SUMMARY.md references non-existent files
1. **Verify organization** - Files grouped logically by content type
1. **Check ordering** - Logical progression (planning → research → decisions → components →
   configuration → procedures)

**Commands to help:**

```bash
# List all markdown files
find . -name "*.md" | sort

# Compare with SUMMARY.md entries
grep "\.md" SUMMARY.md
```

### Step 6: README.md Completeness

Check that each subdirectory has README.md with:

- [ ] Purpose statement
- [ ] Content ownership (WHAT/HOW/WHY/SPECS)
- [ ] What belongs here vs elsewhere
- [ ] Links to key files

**Directories that need README.md:**

- `configuration/`
- `procedures/`
- `decisions/`
- `components/`
- `planning/` (if exists)

### Step 7: Cross-Repo Consistency Check

**Scope**: Only check *outbound* references — resources this repo references that are owned by a
different repo. Do not check whether other repos correctly reference this repo; that is handled by
docs-review runs in those repos.

If the repo references shared resources (IP addresses, switch ports, rack slots, PDU ports, VLAN
assignments, DNS records), verify this repo's values match the authoritative source.

**Ownership quick reference** (for full details, see the `cross-repo-audit` skill):

| Resource                   | Authoritative repo → file                                      |
| -------------------------- | -------------------------------------------------------------- |
| IP addresses, VLANs, DNS   | ubiquiti-network-stack → `configuration/network-topology.md`   |
| Rack slots, PDU ports      | tiny-lab → `configuration/rack-layout.md`, `components/pdu.md` |
| Compute switch ports       | tiny-lab → `configuration/network.md`                          |
| Main switch, gateway ports | ubiquiti-network-stack → `configuration/network-topology.md`   |

**How to determine what to check:**

If the repo has no shared infrastructure dependencies (check AGENTS.md, README.md, or the knowledge
base description), skip this step.

1. Identify which resources this repo is authoritative for — check the ownership table above, the
   repo's AGENTS.md, and relevant steering docs or knowledge base descriptions. Skip those
   resources; this repo is the source of truth for them.
1. Find references to resources owned by other repos (IP addresses, port numbers, rack slot values,
   VLAN IDs mentioned in configuration or procedure files) — these are the outbound references to
   verify
1. Read the authoritative source for each outbound reference and compare

**For each outbound shared resource found in this repo:**

- [ ] Read the authoritative source file listed above
- [ ] Verify values in this repo match the authoritative source
- [ ] Hostnames use `.lan` suffix, not `.local`
- [ ] Cross-repo GitHub links point to valid files

If conflicts are found, update this repo to match the authoritative source. If the authoritative
source is wrong, fix it first. Never modify repos outside the current working directory without
proposing the changes and receiving explicit approval first.

### Step 8: Write Actionable Findings to todo.md

**Skip this step if the review found no actionable items** (all findings are informational or
already resolved).

Persist actionable items from the review to the project's `todo.md` so they survive across sessions.
Follow the `todo` skill conventions.

**Rules:**

1. If `todo.md` does not exist in the project root, create it using the template from the `todo`
   skill (three sections: `## Open questions`, `## Blockers`, `## Tasks`)
1. If `todo.md` already exists, read it first — append new items to the appropriate sections without
   removing or modifying existing content. Do not re-open resolved items (marked `[x]`).
1. Do not duplicate items already present — use the `todo.md` content read in Step 1 as the baseline
   and check whether an existing item covers the same file and issue type before adding a new one
1. Only write items that require follow-up action — skip informational observations

**What goes where:**

| Finding type                                      | Section        | Example                                                                               |
| ------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------- |
| Unanswered design question surfaced during review | Open questions | `- [ ] Should component specs live in components/ or configuration/?`                 |
| Cross-repo conflict needing upstream fix first    | Blockers       | `- [ ] IP conflict with ubiquiti-network-stack — needs resolution there first`        |
| Content ownership violation to fix                | Tasks          | `- [ ] Move implementation steps from configuration/x.md to procedures/`              |
| Broken link to repair                             | Tasks          | `- [ ] Fix broken link in procedures/setup.md → configuration/network.md`             |
| Missing cross-reference                           | Tasks          | `- [ ] Add prerequisite link from procedures/deploy.md to configuration/env.md`       |
| Missing README.md                                 | Tasks          | `- [ ] Add README.md to configuration/ directory`                                     |
| SUMMARY.md drift                                  | Tasks          | `- [ ] Add procedures/new-file.md to SUMMARY.md`                                      |
| Duplicate specification to consolidate            | Tasks          | `- [ ] Remove duplicate spec table from procedures/x.md — keep in configuration/y.md` |

**Cross-repo issues (from Step 7):** If the review found conflicts with authoritative sources in
other repos, write them as blockers referencing the upstream repo and file that needs correction.

### Step 9: Generate Review Report

Create a structured report with findings:

```markdown
# Documentation Review Report

## Summary

- Total files reviewed: X
- Issues found: Y
- Critical issues: Z

## Content Ownership Violations

### configuration/ Issues

- [ ] File X contains implementation steps (lines A-B)
- [ ] File Y duplicates specifications from Z

### procedures/ Issues

- [ ] File X duplicates specification table from Y
- [ ] File Y missing reference to configuration/Z

### decisions/ Issues

- [ ] ADR-NNN contains implementation details
- [ ] ADR-MMM missing consequences section

## Duplicate Specifications

- Specification X appears in:
  - configuration/file1.md (lines 10-20)
  - procedures/file2.md (lines 30-40)
  - **Recommendation:** Keep in configuration/file1.md, replace in file2.md with reference

## Cross-Reference Issues

- [ ] Broken link in file X to file Y
- [ ] Missing cross-reference from procedure X to configuration Y
- [ ] Bare URL in file Z (line N)

## SUMMARY.md Issues

- [ ] File X exists but not in SUMMARY.md
- [ ] SUMMARY.md references non-existent file Y
- [ ] Files not grouped by content type

## Missing README.md

- [ ] configuration/ directory
- [ ] procedures/ directory

## Recommendations

1. **High Priority:**
   - Fix content ownership violations in configuration/
   - Remove duplicate specifications
   - Add missing cross-references

1. **Medium Priority:**
   - Fix broken links
   - Update SUMMARY.md
   - Add missing README.md files

1. **Low Priority:**
   - Improve link text patterns
   - Add section links for specificity

## Tracking

Actionable items written to `todo.md` — X open questions, Y blockers, Z tasks.

> Omit this section if Step 8 was skipped (no actionable items).
```

## Review Checklist

Use `references/review-checklist.md` for detailed checklist.

### Quick Checklist

**Content Ownership:**

- [ ] configuration/ contains only WHAT (specifications)
- [ ] procedures/ contains only HOW (implementation steps)
- [ ] decisions/ contains only WHY (rationale)
- [ ] components/ contains only SPECS (component details)

**No Duplication:**

- [ ] Each specification exists in exactly one place
- [ ] Procedures reference, not duplicate, specifications
- [ ] No duplicate tables across files

**Cross-References:**

- [ ] All links use descriptive text
- [ ] Internal links use relative paths
- [ ] No broken links
- [ ] Procedures link to relevant configuration files

**Structure:**

- [ ] SUMMARY.md matches actual files
- [ ] Each subdirectory has README.md
- [ ] Files follow naming conventions
- [ ] Logical organization by content type

**Quality:**

- [ ] No bare URLs
- [ ] No "click here" links
- [ ] Consistent heading hierarchy
- [ ] Pre-commit hooks pass

## Common Issues and Fixes

### Issue: Duplicate Specification Tables

**Problem:** Same table appears in configuration/ and procedures/

**Fix:**

1. Keep table in configuration/ file
1. In procedures/ file, replace table with:

```markdown
Configure according to [Configuration: X](../configuration/x.md#section).
```

### Issue: Implementation Steps in Configuration

**Problem:** configuration/ file contains "Step 1, Step 2" instructions

**Fix:**

1. Move steps to procedures/ file
1. In configuration/ file, add:

```markdown
For implementation, see [Procedure: X](../procedures/x.md).
```

### Issue: Missing Cross-References

**Problem:** Procedure doesn't reference relevant configuration

**Fix:** Add Prerequisites section:

```markdown
## Prerequisites

Before proceeding, review:

- [Configuration: System Settings](../configuration/system-settings.md)
```

### Issue: Bare URLs

**Problem:** `https://example.com` instead of `[Example](https://example.com)`

**Fix:**

```bash
# Find bare URLs
grep -r "http" . | grep -v "\[.*\](http"

# Replace with descriptive links
[Resource Name](https://example.com)
```

### Issue: Generic Link Text

**Problem:** `[here](../config/system.md)` or `[link](../config/system.md)`

**Fix:**

```markdown
[Configuration: System Settings](../configuration/system-settings.md)
```

## Automated Checks

### Pre-commit Hooks

Verify pre-commit hooks are configured and passing:

```bash
pre-commit run --all-files
```

### mdBook Link Checker

```bash
mdbook build
```

## Review Frequency

**When to review:**

- Before major releases
- After significant content additions
- When refactoring documentation structure
- Quarterly for active projects
- When onboarding new documentation contributors

**Quick reviews (15-30 min):**

- Check for new duplicate specifications
- Verify SUMMARY.md is current
- Run link checker

**Comprehensive reviews (2-4 hours):**

- Full content ownership audit
- Duplicate specification detection
- Cross-reference validation
- Generate detailed report

## Reference Documentation

- Read `references/review-checklist.md` when performing a full documentation review — it expands on
  the quick checklist above
- Read `references/content-ownership-reference.md` when evaluating whether content is in the correct
  directory or when flagging ownership violations
- Read `references/link-conventions-reference.md` when checking cross-references between files or
  validating link formats
- Load the `cross-repo-audit` skill when the review involves shared resources across multiple repos
