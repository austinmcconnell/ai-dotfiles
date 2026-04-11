# Documentation Review Checklist

Comprehensive checklist for reviewing documentation repositories. Use this for systematic reviews to
ensure content ownership compliance and quality standards.

## Pre-Review Setup

- [ ] Clone/pull latest version of documentation repository
- [ ] Read `AGENTS.md` or `README.md` for project-specific conventions
- [ ] Review `SUMMARY.md` to understand intended structure
- [ ] Identify content directories (configuration/, procedures/, decisions/, components/)
- [ ] Note any custom naming conventions or patterns

## Content Ownership Audit

### configuration/ Files (WHAT - Specifications)

For each file in configuration/:

- [ ] Contains only specifications, design, and requirements
- [ ] No step-by-step implementation instructions
- [ ] No UI navigation steps ("click here", "navigate to")
- [ ] Uses tables, diagrams, or structured data for specifications
- [ ] References procedures/ for implementation (not inline steps)
- [ ] Each specification appears only once (single source of truth)
- [ ] No duplicate tables from other files
- [ ] Appropriate cross-references to related configuration files

**Common violations:**

- Step-by-step setup instructions
- "First, do X. Then, do Y." procedural language
- Duplicate specification tables
- UI screenshots with navigation steps

### procedures/ Files (HOW - Implementation)

For each file in procedures/:

- [ ] Contains step-by-step implementation instructions
- [ ] References configuration/ instead of duplicating specifications
- [ ] Includes Prerequisites section linking to relevant configuration files
- [ ] Has verification steps or checklist
- [ ] No duplicate specification tables
- [ ] Uses numbered lists for sequential steps
- [ ] Includes troubleshooting section (if applicable)
- [ ] Links to related procedures

**Common violations:**

- Duplicate specification tables from configuration/
- Missing cross-references to configuration files
- Specifications embedded in procedure steps
- No verification steps

### decisions/ Files (WHY - Rationale)

For each file in decisions/:

- [ ] Follows ADR format (MADR or project-specific)
- [ ] Contains context and problem statement
- [ ] Lists considered options
- [ ] States decision outcome with justification
- [ ] Includes consequences (positive and negative)
- [ ] No implementation details (links to procedures/ instead)
- [ ] No duplicate specifications (links to configuration/ instead)
- [ ] Cross-references related ADRs
- [ ] Has proper ADR number and filename

**Common violations:**

- Implementation steps in ADR
- Duplicate specifications from configuration/
- Missing consequences section
- No cross-references to related decisions

### components/ Files (SPECS - Component Details)

For each file in components/:

- [ ] Contains component specifications and capabilities
- [ ] Includes model numbers, versions, or identifiers
- [ ] Documents performance metrics (if applicable)
- [ ] No system-level assignments (belongs in configuration/)
- [ ] No implementation steps (belongs in procedures/)
- [ ] References configuration/ for how component is used
- [ ] Links to vendor documentation (if applicable)
- [ ] Includes upgrade path or compatibility notes

**Common violations:**

- Configuration specifications
- Setup procedures
- Mixing component specs with system design

### planning/bom.md (if exists)

- [ ] Links to components/ for details — does not duplicate specifications
- [ ] Every component in components/ has a corresponding BOM entry
- [ ] No duplicate specification tables (prices, model numbers stay in components/)
- [ ] Status tracking is current (bought/needed)
- [ ] Prices and dates match component files

## Duplicate Specification Detection

### Specification Tables

- [ ] Search for tables appearing in multiple files
- [ ] Check that each table exists in only one canonical location
- [ ] Verify procedures/ reference tables instead of duplicating
- [ ] Confirm configuration/ is the source of truth for specifications

**How to check:**

```bash
# Find all tables
grep -r "^|" .

# Look for similar table structures in multiple files
```

### Repeated Values

- [ ] Search for values (IDs, addresses, names) appearing in multiple files
- [ ] Verify each value is defined in only one place (usually configuration/)
- [ ] Check that procedures/ reference configuration/ instead of repeating values

### Component Lists

- [ ] Check for component lists in multiple files
- [ ] Verify canonical list exists (usually components/ or configuration/)
- [ ] Confirm other files reference the canonical list

### Policy and Rule Definitions

- [ ] Search for policy or rule definitions across files
- [ ] Verify definitions exist in configuration/ only
- [ ] Check that procedures/ reference configuration/

## Cross-Reference Validation

### Link Text Patterns

For each link in documentation:

- [ ] Uses descriptive pattern: `[Configuration: X]`, `[Procedure: Y]`, `[ADR-NNN: Z]`
- [ ] No "click here" or "see here" links
- [ ] No "link" or "here" as link text
- [ ] No bare URLs (all URLs wrapped in descriptive links)
- [ ] External links use resource name as link text

**How to check:**

```bash
# Find "click here" anti-pattern
grep -ri "click here" .

# Find "here" as link text
grep -r "\[here\]" .

# Find bare URLs
grep -r "http" . | grep -v "\[.*\](http"
```

### Link Targets

- [ ] All internal links use relative paths
- [ ] No absolute paths for internal documentation
- [ ] Links point to existing files (no 404s)
- [ ] Section anchors are correct (if used)
- [ ] External links use absolute URLs
- [ ] Links to subdirectory overviews use directory paths (`../section/`), not README.md paths —
  mdBook compiles README.md to index.html, so README.md links break in the built HTML

**How to check:**

```bash
# Run mdBook link checker
mdbook build

# Or use linkcheck directly
mdbook-linkcheck
```

### Cross-Reference Completeness

- [ ] Procedures/ files link to relevant configuration/ files in Prerequisites
- [ ] Configuration/ files link to implementation procedures/ (where applicable)
- [ ] ADRs link to related decisions
- [ ] Components/ files link to configuration/ where component is used
- [ ] Each major file has "Related Documentation" section

### Link Text Consistency

- [ ] Configuration files use `[Configuration: Title]` or `[Config: Title]`
- [ ] Procedure files use `[Procedure: Title]` or `[Setup: Title]`
- [ ] ADRs use `[ADR-NNN: Title]` format
- [ ] Components use `[Component: Name]` or `[Name Specs]`

## SUMMARY.md Validation

### File Coverage

- [ ] All markdown files are listed in SUMMARY.md
- [ ] No orphaned files (exist but not in SUMMARY.md)
- [ ] No dead links (SUMMARY.md references non-existent files)

**How to check:**

```bash
# List all markdown files
find . -name "*.md" | sort > /tmp/actual-files.txt

# Extract files from SUMMARY.md
grep "\.md" SUMMARY.md | sed 's/.*(\(.*\))/\1/' | sort > /tmp/summary-files.txt

# Compare
diff /tmp/actual-files.txt /tmp/summary-files.txt
```

### Organization

- [ ] Files grouped logically by content type
- [ ] Logical progression (planning → components → configuration → procedures → decisions)
- [ ] Consistent indentation for hierarchy
- [ ] Flat list format under `# Table of Contents` (no `# Section` headers as dividers)

### Ordering

- [ ] Planning files first (if exists)
- [ ] Components before configuration (if applicable)
- [ ] Configuration before procedures
- [ ] Decisions can be anywhere (often at end)
- [ ] Within each section, logical ordering (basic → advanced, or alphabetical)

## README.md Completeness

### Directory README Files

For each content directory:

- [ ] configuration/ has README.md
- [ ] procedures/ has README.md
- [ ] decisions/ has README.md
- [ ] components/ has README.md (if exists)
- [ ] planning/ has README.md (if exists)

### README Content

Each README.md should have:

- [ ] Purpose statement (what this directory contains)
- [ ] Content ownership (WHAT/HOW/WHY/SPECS)
- [ ] What belongs here vs elsewhere
- [ ] Links to key files or index
- [ ] Naming conventions (if applicable)

## File Structure and Naming

### Naming Conventions

- [ ] Files use kebab-case: `system-configuration.md` not `System_Configuration.md`
- [ ] Descriptive names: `gateway-setup.md` not `setup.md`
- [ ] Content type clear from name: `security-rules.md` (specs) vs `security-configuration.md`
  (steps)
- [ ] ADRs follow pattern: `adr-NNN-title.md` or `NNNN-title.md`

### File Organization

- [ ] Files in correct directory for content type
- [ ] No misplaced files (procedures in configuration/, etc.)
- [ ] Logical grouping within directories
- [ ] No deeply nested subdirectories (max 2-3 levels)

## Quality Standards

### Markdown Quality

- [ ] Consistent heading hierarchy (H1 → H2 → H3, no skipping)
- [ ] Tables properly formatted
- [ ] Code blocks have language specified
- [ ] Lists use consistent markers (- for bullets, 1. for numbered)
- [ ] No trailing whitespace
- [ ] Files end with newline

**How to check:**

```bash
# Run markdownlint
markdownlint .

# Or use pre-commit hooks
pre-commit run --all-files
```

### Content Quality

- [ ] No spelling errors
- [ ] Consistent terminology
- [ ] Active voice preferred
- [ ] Present tense for documentation
- [ ] Second person ("you") for procedures
- [ ] Clear, concise language

### Accessibility

- [ ] Link text makes sense out of context
- [ ] Images have alt text
- [ ] Tables have headers
- [ ] Heading hierarchy is logical
- [ ] No color-only indicators

## Automated Checks

### Pre-commit Hooks

- [ ] Pre-commit hooks configured (`.pre-commit-config.yaml`)
- [ ] Markdownlint enabled
- [ ] Link checker enabled
- [ ] Trailing whitespace check enabled
- [ ] YAML validation enabled

**Run checks:**

```bash
pre-commit run --all-files
```

### mdBook Build

- [ ] mdBook builds without errors
- [ ] No broken links reported
- [ ] Search index generates successfully
- [ ] All plugins work correctly

**Run build:**

```bash
mdbook build
mdbook test  # If code examples exist
```

## Review Report Template

After completing checklist, generate report:

```markdown
# Documentation Review Report

**Date:** YYYY-MM-DD

**Reviewer:** [Name]

**Repository:** [Name]

**Commit:** [SHA]

## Summary

- Total files reviewed: X
- Issues found: Y
- Critical issues: Z
- Warnings: W

## Critical Issues (Must Fix)

### Content Ownership Violations

- [ ] File X contains implementation steps in configuration/
- [ ] File Y duplicates specifications from Z

### Duplicate Specifications

- Specification X appears in:
  - configuration/file1.md (lines 10-20) ← Keep this
  - procedures/file2.md (lines 30-40) ← Replace with reference

## Warnings (Should Fix)

### Cross-Reference Issues

- [ ] Missing cross-reference from procedure X to configuration Y
- [ ] Broken link in file Z

### SUMMARY.md Issues

- [ ] File X not listed in SUMMARY.md
- [ ] Dead link to file Y

## Recommendations

### High Priority

1. Fix content ownership violations
2. Remove duplicate specifications
3. Add missing cross-references

### Medium Priority

1. Fix broken links
2. Update SUMMARY.md
3. Add missing README.md files

### Low Priority

1. Improve link text patterns
2. Add section links for specificity
3. Enhance accessibility

## Positive Findings

- Good separation of WHAT/HOW/WHY in [areas]
- Excellent cross-referencing in [files]
- Well-organized [directory]

## Next Steps

1. [Action item 1]
2. [Action item 2]
3. Schedule follow-up review: [Date]
```

## Review Frequency Guidelines

### Quick Review (15-30 minutes)

Run before each release or major merge:

- [ ] Check for new duplicate specifications
- [ ] Verify SUMMARY.md is current
- [ ] Run automated link checker
- [ ] Scan for obvious content ownership violations

### Standard Review (1-2 hours)

Run monthly or quarterly:

- [ ] Content ownership audit (sample files)
- [ ] Duplicate specification detection
- [ ] Cross-reference validation
- [ ] SUMMARY.md accuracy
- [ ] README.md completeness

### Comprehensive Review (2-4 hours)

Run before major releases or refactoring:

- [ ] Full content ownership audit (all files)
- [ ] Thorough duplicate detection
- [ ] Complete cross-reference validation
- [ ] Detailed quality checks
- [ ] Generate comprehensive report

## Common Issues Quick Reference

| Issue                          | Location            | Fix                                           |
| ------------------------------ | ------------------- | --------------------------------------------- |
| Implementation steps in config | configuration/\*.md | Move to procedures/, add reference            |
| Duplicate spec table           | procedures/\*.md    | Remove table, add reference to configuration/ |
| Missing cross-reference        | procedures/\*.md    | Add Prerequisites section with links          |
| Bare URL                       | Any file            | Wrap in descriptive link text                 |
| "Click here" link              | Any file            | Replace with descriptive pattern              |
| File not in SUMMARY.md         | Any file            | Add to SUMMARY.md in correct section          |
| Missing README.md              | Directory           | Create README.md with purpose and ownership   |
| Wrong content type             | Any file            | Move to correct directory                     |
