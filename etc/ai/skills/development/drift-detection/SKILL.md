---
name: drift-detection
description: >-
  Detect stale references in steering docs and skills — broken repo paths, trigger-table skill names
  with no SKILL.md, and commands cited as steps that may not be installed. Use when auditing
  documentation health, after renaming/moving files, or when the validate-steering-references
  pre-commit hook fails.
---

# Drift Detection

## When to Use

- After renaming or moving files referenced by steering docs or skills
- When `validate-steering-references` fails at commit time
- Periodic documentation health checks

## Automated Check

`scripts/validate-steering-references.sh` runs at commit time (pre-commit hook
`validate-steering-references`) and checks:

1. Backticked repo paths under `etc/`, `scripts/`, `install/`, and `bin/` in
   `etc/ai/steering/**/*.md` and `etc/ai/skills/**/SKILL.md` exist in this repo. Tokens containing a
   glob, a `<placeholder>`, or a `~`, `$`, or `{` prefix are skipped, since they name a pattern or a
   location outside this repo. Files under `skills/*/references/` are not scanned.
1. Skill names in the trigger tables (`steering/**/skill-loading-triggers.md`) each have a
   `SKILL.md` under `etc/ai/skills/`.

Run it by hand with `bash scripts/validate-steering-references.sh`. It exits 0 when every reference
resolves and 1 otherwise.

## Fixing a Failure

- If the target was renamed: update the doc
- If the target was removed intentionally: remove the reference
- If the target lives outside this repo: say so in the doc and write the path without backticks or
  with a `~` prefix, instead of linking it

## Manual Checks

The script does not judge these, so check them by hand when auditing:

- Commands cited as steps: confirm each is installed (`command -v <tool>`); if it is not available
  everywhere, make the reference conditional
- Dead cross-references between docs that are not backticked repo paths (for example, a bare "see
  the X doc" with no path)
