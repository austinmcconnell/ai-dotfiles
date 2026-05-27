---
name: drift-detection
description: >-
  Detect stale references in steering docs — broken file paths, missing skills, unavailable
  commands, and dead cross-references. Use when auditing documentation health or after
  renaming/moving files.
---

# Drift Detection

## When to Use

- After renaming or moving files referenced by steering docs
- Periodic documentation health checks
- Before committing changes to steering docs or skills

## Workflow

1. Run `dotfiles drift-check` via shell
1. Review the report for broken references and warnings
1. For each broken reference:
   - If the target was renamed: update the steering doc
   - If the target was removed intentionally: remove the reference
   - If the target is machine-specific: add to `scripts/drift-check-allowlist.txt`
1. For warnings (missing commands): verify whether the tool should be installed or the reference
   should be conditional

## Integration

The script exits non-zero when broken references exist, making it suitable for:

- Pre-commit hooks (optional, may be slow)
- Periodic agent-driven checks
- Manual runs after refactoring
