---
name: pre-commit-validation
description:
  Validate code and documentation using pre-commit hooks. Use when working with
  .pre-commit-config.yaml files, checking code formatting, running linters, or validating changes
  before committing.
---

# Pre-commit Validation

Run pre-commit hooks to validate code quality, formatting, and style before finalizing changes.

## How to validate

### Check specific files

```bash
pre-commit run --files path/to/file1 --files path/to/file2
```

### Check all files

```bash
pre-commit run --all-files
```

### Run specific hook

```bash
pre-commit run <hook-name> --files path/to/file
```

## Workflow

1. Generate or modify files
2. Run pre-commit on changed files
3. If hooks modify files, read them back to see what changed
4. Make additional edits on top of hook-modified versions
5. Run pre-commit again until all checks pass

## When hooks modify files

Pre-commit hooks often auto-fix issues like:

- Formatting (spacing, indentation)
- Import ordering
- Trailing whitespace
- Quote style

**Important:** Always read hook-modified files before making further changes. Build on the corrected
version, not the original.

## Common failures and fixes

See [references/common-checks.md](references/common-checks.md) for detailed formatting rules by
language.

## Best practices

- Run validation before presenting final code
- If a check fails repeatedly, explain the issue and ask for guidance
- Validate incrementally as you generate code, not just at the end
