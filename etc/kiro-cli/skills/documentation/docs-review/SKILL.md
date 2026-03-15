---
name: docs-review
description: Review documentation for content ownership violations, duplicate specifications, and structural issues. Use when reviewing docs, auditing documentation structure, validating WHAT/HOW/WHY separation, or checking for content duplication.
---

# Documentation Review Skill

## Overview

Systematically review documentation repositories to identify content ownership violations, duplicate specifications, broken cross-references, and structural issues.

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
- [ ] No network/system assignments (belongs in configuration/)
- [ ] No implementation steps (belongs in procedures/)
- [ ] References configuration/ for how component is used

### Step 3: Duplicate Specification Detection

Search for duplicate content across files:

1. **Identify specification tables** - Look for tables in multiple files
1. **Check IP addresses** - Search for IP addresses appearing in multiple places
1. **Look for repeated lists** - Component lists, feature lists, requirement lists
1. **Find duplicate diagrams** - Same diagram in multiple files

**Common duplication patterns:**
- Network topology tables in both configuration/ and procedures/
- Component specifications in both components/ and configuration/
- Security rules in both configuration/ and procedures/
- IP assignments scattered across multiple files

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
grep -r "http" src/ | grep -v "\[.*\](http"

# Find "click here" anti-pattern
grep -ri "click here" src/
```

### Step 5: SUMMARY.md Accuracy

Verify SUMMARY.md matches actual file structure:

1. **Check for missing files** - Files exist but not in SUMMARY.md
1. **Check for dead links** - SUMMARY.md references non-existent files
1. **Verify organization** - Files grouped logically by content type
1. **Check ordering** - Logical progression (planning → components → configuration → procedures → decisions)

**Commands to help:**
```bash
# List all markdown files
find src/ -name "*.md" | sort

# Compare with SUMMARY.md entries
grep "\.md" src/SUMMARY.md
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

### Step 7: Generate Review Report

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

2. **Medium Priority:**
   - Fix broken links
   - Update SUMMARY.md
   - Add missing README.md files

3. **Low Priority:**
   - Improve link text patterns
   - Add section links for specificity
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

**Fix:**
Add Prerequisites section:
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
grep -r "http" src/ | grep -v "\[.*\](http"

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

Recommended hooks for documentation:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    hooks:
      - id: check-yaml
      - id: check-added-large-files
      - id: trailing-whitespace
      - id: end-of-file-fixer

  - repo: https://github.com/DavidAnson/markdownlint-cli2
    hooks:
      - id: markdownlint-cli2
```

### mdBook Link Checker

```toml
# book.toml
[output.linkcheck]
follow-web-links = false
exclude = ["^http://localhost"]
```

Run with:
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

- `references/review-checklist.md` - Detailed review checklist
- `steering/documentation/content-ownership.md` - Content ownership principles
- `steering/documentation/link-conventions.md` - Cross-referencing standards
