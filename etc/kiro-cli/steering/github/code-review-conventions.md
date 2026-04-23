# Code Review Conventions

## Review Structure

When reviewing code (PRs, diffs, or files), organize feedback by severity:

1. **Blockers** — Must fix before merge. Security vulnerabilities, data loss risks, broken
   functionality, missing error handling for critical paths.
1. **Suggestions** — Should fix. Performance issues, maintainability concerns, missing tests for new
   logic, error handling gaps for non-critical paths.
1. **Nits** — Optional. Style preferences, naming alternatives, minor readability improvements.

Present blockers first. If there are no blockers, say so explicitly.

## Review Principles

- Review the change, not the author
- Focus on behavior changes, not style (unless style hides bugs)
- Check error handling paths, not just happy paths
- Flag missing tests for new branches/conditions
- Identify security implications: auth checks, input validation, data exposure
- Note when a change is too large and should be split

## Output Format

For each finding:

```text
[BLOCKER|SUGGESTION|NIT] file:line — description
```

Group by file when reviewing multi-file changes. End with a summary: merge-ready, needs changes, or
needs discussion.

## What NOT to Flag

- Formatting issues handled by automated linters/formatters
- Style choices consistent with the existing codebase
- Hypothetical future problems with no current impact
