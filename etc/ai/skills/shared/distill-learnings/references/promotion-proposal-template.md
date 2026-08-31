# Promotion Proposal Template

Use this format to present promotion candidates for user review. Present all candidates together in
one message so the user can approve, reject, or redirect each in a single pass.

## Format

For each promotable correction:

```markdown
### Proposal N: <short title of the correction>

- **Source** (engram): "<memory title>" — <the rule, one line>
- **Destination**: `etc/ai/steering/<domain>/<file>.md` → section "<heading>"
- **Rationale**: <one line — why this doc/section is the right home>

**Exact edit:**

<show the concrete lines to add or change, in enough surrounding context that the user can see
where it lands — e.g. the bullet added under an existing heading>
```

For candidates you are **not** promoting, list them briefly:

```markdown
### Not promoting

- "<memory title>" — leave in engram: <reason (too situational / duplicates existing rule / etc.)>
```

## Example

### Proposal 1: Use single quotes for Python strings

- **Source** (engram): "Use single quotes for Python strings" — prefer `'x'` over `"x"` unless the
  string contains a single quote.
- **Destination**: `etc/ai/steering/code/python-project-conventions.md` → section "Formatting"
- **Rationale**: This is an always-on style convention; the Formatting section already lists quote
  handling, so it belongs there, not in a skill.

**Exact edit** — add under the "Formatting" bullet list:

```markdown
- Single quotes for strings; double quotes only when the string contains a single quote
  (`double-quote-string-fixer` pre-commit hook enforces this)
```

### Not promoting

- "Skip the staging server for this one deploy" — leave in engram: one-off situational instruction,
  not a durable rule.

## Notes

- Keep each edit to a sentence or a bullet. Do not restate what the doc already says.
- Match the destination file's existing heading structure and formatting.
- If no existing doc fits, propose the path for a new focused doc and justify why a new file is
  warranted rather than extending an existing one.
