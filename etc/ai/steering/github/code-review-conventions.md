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
- Verify concerns against actual code before raising them — read model definitions, relationship
  configurations, enum values, and call sites. Withdraw concerns that don't hold up under scrutiny.
- Call out what's done well — good patterns, smart tradeoffs, correct design decisions. Reviews that
  only flag problems are incomplete.
- Check for unresolved prior feedback — if previous reviewers left comments, assess whether they
  were addressed before adding new findings.

## Output Format

For each finding, use severity tags with file and line references:

```text
[BLOCKER|SUGGESTION|NIT] file:line — description
```

Group findings by severity tier (blockers first, then suggestions, then nits). End with a summary:
merge-ready, needs changes, or needs discussion.

For full PR reviews using the `pr-review` skill, follow the skill's structured output template
(markdown headings per severity tier, unresolved prior feedback, what's done well, and summary).

## What NOT to Flag

- Formatting issues handled by automated linters/formatters
- Style choices consistent with the existing codebase
- Hypothetical future problems with no current impact
