---
name: implementation-guide
description: >-
  Create detailed implementation guides with step-by-step instructions, complete code examples,
  testing procedures, and verification steps. Use for security vulnerabilities, complex refactoring,
  database migrations, API upgrades, bug fixes, or any work requiring precise execution by
  developers or AI agents.
---

# Implementation Guide

## How to Use This Skill

This skill helps you create comprehensive implementation guides for complex technical work. Use the
blank template in `references/template.md` to start, or review `references/security-fix-example.md`
for a detailed real-world example. Follow the structure below to ensure completeness.

## When to Write Implementation Guides

Write implementation guides for:

- Security vulnerability fixes requiring detailed remediation
- Complex refactoring across multiple files
- Database migrations or schema changes
- API version upgrades or breaking changes
- Step-by-step migration procedures
- Bug fixes with non-obvious solutions
- Work that will be executed by others (developers or AI agents)

Skip implementation guides for:

- Simple one-line fixes
- Standard CRUD operations
- Well-documented library usage
- Trivial configuration changes

## Guide Structure

Every implementation guide should include these sections:

### 1. Header & Context

```markdown

**Type:** Security Fix | Refactor | Migration | Bug Fix

**Priority:** Critical | High | Medium | Low

**Estimated Effort:** [hours/days]

**Prerequisites:** [Required knowledge, tools, or setup]
```

### 2. Problem Statement

- What is broken, vulnerable, or needs changing?
- Why does this need to be fixed/implemented?
- What is the impact if not addressed?

### 3. Feasibility Analysis

- **Complexity:** Low | Medium | High
- **Breaking Changes:** None | Minimal | Significant
- **Dependencies:** What needs to be installed/configured
- **Challenges:** What makes this difficult
- **Solutions Available:** Options with trade-offs
- **Recommended Approach:** Which solution and why

### 4. Current State (Before)

- Show the problematic code, architecture, or behavior
- Explain specific issues
- **Root Cause:** Why does this problem exist?

### 5. Desired State (After)

- Show the fixed code, architecture, or behavior
- Explain improvements

### 6. Implementation Steps

Ordered list of exact changes:

- File paths and line numbers
- Complete code blocks (not fragments)
- Rationale for each change

### 7. Testing Instructions

- Unit tests to write
- Integration tests to run
- Manual testing steps
- Expected outcomes

### 8. Files to Modify

Explicit list of all files that need changes

### 9. Verification Steps

- How to confirm the fix works
- What success looks like
- Checklist of verification tasks

### 10. Rollback Plan

How to undo changes if something goes wrong

### 11. References

Standards, documentation, tools, and resources

## Key Sections Explained

### Feasibility Analysis

Analyze the implementation before starting:

**Example:**

```markdown

**Complexity:** Medium

**Breaking Changes:** None (adds validation, doesn't change behavior)

**Dependencies:** Standard library only (re.escape())

**Challenges:**

1. Need to escape regex special characters while preserving search functionality
2. Must maintain case-insensitive partial matching behavior

**Solutions Available:**

- Option A: Use re.escape() to sanitize regex patterns (recommended)
- Option B: Switch to simpler JSONB operators (@>, ?)
- Option C: Use SQLAlchemy text() with bind parameters

**Recommended Approach:** Option A - simplest, no behavior change
```

### Attack Vectors (For Security Issues)

Show concrete exploitation examples:

**Example:**

Example 1: SQL Injection

```text
?param='; DROP TABLE users--
```

Example 2: DoS via Large Input

```text
?param=AAAA... (10MB payload)
```

Example 3: Regex Injection

```text
?pattern=(a+)+$ # Catastrophic backtracking
```

### Root Cause Analysis

Explain WHY the problem exists, not just WHAT is wrong:

**Example:**

```markdown

**Root Cause:** User input is directly interpolated into the jsonb_path string
using f-string interpolation. PostgreSQL's jsonb_path language supports complex
expressions, and unescaped user input can break out of the regex context.
```

### Verification Steps

Specific steps to confirm the fix works:

**Example:**

```markdown
1. Run unit tests: `pytest tests/test_validators.py`
2. Run integration tests: `pytest tests/test_search_security.py`
3. Manual testing:
   - Search with special characters: `test@example.com`
   - Search with regex patterns: `.*`, `(a+)+`
   - Verify no SQL errors in logs
4. Security scan: `bandit -r app/`

**Success Criteria:**

- [ ] All tests pass
- [ ] No SQL injection detected
- [ ] Search functionality works for legitimate queries
```

## Implementation Workflow

Copy this checklist and track progress:

```markdown
Implementation Progress:

- [ ] Step 1: Analyze problem and document feasibility
- [ ] Step 2: Document current state with code examples
- [ ] Step 3: Design solution and document desired state
- [ ] Step 4: Break down into implementation steps
- [ ] Step 5: Write testing instructions
- [ ] Step 6: Create verification checklist
- [ ] Step 7: Document rollback plan
- [ ] Step 8: List all files to modify
- [ ] Step 9: Add references and standards
```

## Writing Guidelines

**Be Specific:**

- Show exact file paths and line numbers
- Include complete code snippets, not fragments
- Specify imports and dependencies
- Show before/after for modified code

**Be Complete:**

- Include all files that need changes
- Don't assume knowledge of the codebase
- Explain non-obvious decisions
- Provide context for why changes are made

**Be Actionable:**

- Each step should be clear and executable
- Order steps by dependency
- Include commands to run (tests, migrations, etc.)
- Specify what success looks like

**Code Examples:**

- Show complete functions/classes, not just snippets
- Include necessary imports
- Add comments explaining key changes
- Use syntax highlighting with language tags

## Common Patterns

### Security Fix Pattern

```markdown
## Problem Statement

[Vulnerability description with OWASP/CWE references]

## Feasibility Analysis

[Complexity, dependencies, challenges, solutions]

## Attack Vectors

[Concrete exploitation examples]

## Current State

[Vulnerable code with explanation]

## Desired State

[Fixed code with security improvements]

## Implementation Steps

[Step-by-step with complete code]

## Testing Instructions

[Security-specific tests]

## Verification Steps

[Security scanning, penetration testing]
```

### Refactoring Pattern

```markdown
## Problem Statement

[Code smell, technical debt, or maintainability issue]

## Feasibility Analysis

[Impact on existing code, test coverage needed]

## Current State

[Complex/duplicated/unclear code]

## Desired State

[Clean, maintainable, well-structured code]

## Implementation Steps

[Incremental refactoring steps]

## Testing Instructions

[Regression tests to ensure behavior unchanged]
```

### Migration Pattern

```markdown
## Problem Statement

[Why migration is needed, what's changing]

## Feasibility Analysis

[Downtime required, data volume, rollback complexity]

## Current State

[Old schema/API/system]

## Desired State

[New schema/API/system]

## Implementation Steps

[Migration scripts, data transformation, deployment]

## Testing Instructions

[Test with production-like data]

## Rollback Plan

[Critical for migrations - how to revert]
```

## Best Practices

1. **Show, don't tell** - Provide complete code, not descriptions
1. **Test everything** - Include tests for each change
1. **Explain the why** - Context helps implementers understand
1. **Be precise** - Exact file paths, line numbers, commands
1. **Think about rollback** - How to undo if needed
1. **Consider edge cases** - What could go wrong?
1. **Verify completeness** - Could someone follow this blindly?

## Reference Documentation

- [references/template.md](references/template.md) - Blank implementation guide template
- [references/security-fix-example.md](references/security-fix-example.md) - Comprehensive security
  vulnerability fix example (8 issues, 50+ pages)
