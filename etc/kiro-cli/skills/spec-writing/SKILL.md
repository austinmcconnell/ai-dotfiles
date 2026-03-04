---
name: spec-writing
description: >
  Write clear, testable technical specifications for feature planning and implementation.
  Use when planning features, documenting requirements, creating design docs, or writing RFCs.
---

# Spec Writing

## When to Write Specs

Write specs for:
- Complex features requiring coordination
- Features with unclear requirements
- Cross-team dependencies
- High-risk or high-impact changes
- Architectural decisions needing documentation

Skip specs for:
- Simple bug fixes
- Trivial UI tweaks
- Well-understood patterns
- Urgent hotfixes

## Spec Structure

Single `spec.md` file with these sections:

### 1. Header
```markdown
# Feature Name

**Status:** Draft | In Progress | Complete
**Created:** YYYY-MM-DD
**Owner:** @username
```

### 2. Overview
1-2 paragraphs explaining what and why. Should give anyone context without reading further.

### 3. Requirements
User-facing behavior as testable checkboxes:
```markdown
- [ ] User can perform action X
- [ ] System responds with Y when Z
- [ ] Feature handles edge case A
```

**Edge cases:** Compact "scenario → outcome" format at the end.

### 4. Architecture
- Components and their roles
- Data contracts (API, database schemas)
- Key decisions with rationale

### 5. Implementation Plan
Flat task list ordered by dependency. Each task completable in single PR.

### 6. Verification
Table mapping requirements to test methods and pass criteria.

### 7. Open Questions (optional)
Unresolved decisions that need answers.

## Writing Guidelines

**Requirements:**
- Write as testable statements
- Use checkboxes for tracking
- Define success and failure paths
- Keep edge cases compact

**Architecture:**
- Explain WHAT and WHY, not HOW
- Show data contracts and interfaces
- Document key decisions with rationale
- Reference existing patterns

**Tasks:**
- Single-level list (no nested subtasks)
- Ordered by dependency
- Each completable in single PR
- Clear, actionable descriptions

**Keep it concise:**
- Explain concepts once
- Reference instead of repeating
- Target under 1000 lines (up to 1200 is fine)
- Focus on decisions, not details

## Example Patterns

See [the spec template](references/spec-template.md) for full template. Delete sections that don't apply to your feature.

**Edge cases format:**
```markdown
**Edge cases:** No data → empty state. Timeout → cached data with staleness warning. No permissions → redirect to access request.
```

**Key decisions format:**
```markdown
**Decision:** Use Redis cache with 5-minute TTL
**Why:** Reduces load, acceptable staleness for monitoring
**Trade-off:** Slightly outdated data during high-change periods
```

**Verification table:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Load < 2s | Performance test | p95 < 2000ms |
| Highlighting | Unit test | Red when > 80% |
```

## Best Practices

1. **Start with overview** - Give context first
2. **Requirements are testable** - Can verify each one
3. **Explain decisions** - Document the why
4. **Order tasks by dependency** - Top items unblock bottom
5. **Keep it concise** - Target under 1000 lines
6. **Reference existing patterns** - Don't reinvent
7. **Update as you learn** - Specs evolve with implementation
8. **Version control** - Commit specs with code

## Reference Documentation

- [references/spec-template.md](references/spec-template.md) - Complete template with examples
- [references/adr-format.md](references/adr-format.md) - Architecture Decision Record format
- [references/verification-patterns.md](references/verification-patterns.md) - Testing strategies
