# Output Template

Use this structure for release analysis documents. Adapt sections to fit the release — omit sections
that don't apply (e.g., skip "Performance Improvement Summary" for a pure feature release).

---

## Required Sections

### Header

```markdown
# Release X.X.X — Code Change Analysis

**Previous production release:** X.X.X
**Release date:** YYYY-MM-DD (published time with timezone)
**Commits in range:** N (M merged PRs)
```

### Summary

2-4 sentences describing the release's purpose and significance. Mention if it's part of a series
(e.g., "fourth fix release for HSI-83").

### Merged PRs Table

```markdown
## Merged PRs

| PR | Ticket | Title | Merged | Category |
|----|--------|-------|--------|----------|
| #NNN | TICKET-ID | PR title | YYYY-MM-DD | Category |
```

Include author and reviewers inline below the table for each PR.

### Detailed Change Analysis

One subsection per PR (or per logical commit group within a PR). For each:

1. **What changed** — describe the code modification specifically
1. **Why** — the problem it solves or the context driving the change
1. **Impact** — quantify where possible (queries eliminated, latency reduced, etc.)
1. **Risk** — note side effects, global vs scoped changes

Use tables for relationship/configuration changes:

```markdown
| Relationship | Before | After | Rationale |
|-------------|--------|-------|-----------|
```

Include relevant code snippets (before/after) only when they clarify the change.

### Files Changed

```markdown
## Files Changed

| File | Lines Changed | Purpose |
|------|--------------|---------|
```

### Risk Assessment

```markdown
## Risk Assessment

| Component | Risk Level | Notes |
|-----------|-----------|-------|
```

## Conditional Sections

Include these when relevant to the release:

### Performance Improvement Summary

Use when the release contains performance work:

```markdown
## Performance Improvement Summary

| Problem | Before | After | Method |
|---------|--------|-------|--------|
```

### Cumulative Impact Table

Use when the release is part of a series addressing the same issue:

```markdown
## Cumulative Impact

| Release | What Was Fixed | Effect |
|---------|---------------|--------|
```

### Configuration Changes

Use when environment variables, Helm values, or feature flags change:

```markdown
## Configuration Changes

| Setting | Before | After |
|---------|--------|-------|
```

### State After Release

Use for incident-related releases to track what's resolved and what remains:

```markdown
## State After X.X.X

| Concern | Status |
|---------|--------|
```

### Remaining Concerns

Bullet list of known issues, follow-up work, or monitoring needed post-deploy.

---

## Style Notes

- Use **bold** for emphasis on key findings, not for decoration
- Use code formatting for file paths, function names, config values, and SQL
- Use ⚠️ or ✅ sparingly in status tables for scannability
- Keep analysis factual — distinguish confirmed facts from hypotheses
- Reference specific commit messages or PR descriptions when quoting claims
