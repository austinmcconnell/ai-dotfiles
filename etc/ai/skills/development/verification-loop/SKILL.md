---
name: verification-loop
description: Run a complete verification sequence (build, test, lint, typecheck) as a quality gate before declaring work complete. Use after implementing changes, fixing bugs, or before committing to verify all checks pass.
---

# Verification Loop

Run all available verification steps in dependency order as a final quality gate.

## When to Use

- After implementing a feature or fix — before declaring work complete
- Before committing changes — as a pre-commit gate
- After refactoring — to verify nothing broke
- When asked to "verify" or "check everything"

## Workflow

### 1. Detect Project Type

Check for these files in the project root to determine available tools:

| File                           | Project Type  | Tools Available                       |
| ------------------------------ | ------------- | ------------------------------------- |
| `pyproject.toml` or `setup.py` | Python        | pytest, mypy, pre-commit              |
| `package.json`                 | Node.js       | npm test, tsc, eslint                 |
| `Makefile`                     | Make-based    | make build, make test                 |
| `Cargo.toml`                   | Rust          | cargo build, cargo test, cargo clippy |
| `go.mod`                       | Go            | go build, go test, go vet             |
| `.pre-commit-config.yaml`      | Any (linting) | pre-commit                            |

A project may match multiple types (e.g., Python + pre-commit). Run all applicable checks.

### 2. Run Verification Sequence

Execute in this order (each step depends on the previous):

```text
┌─────────┐     ┌──────┐     ┌──────┐     ┌───────────┐
│  Build  │ ──▶ │ Test │ ──▶ │ Lint │ ──▶ │ Typecheck │
└─────────┘     └──────┘     └──────┘     └───────────┘
     │               │            │              │
     ▼               ▼            ▼              ▼
  (if fails,      (if fails,  (if fails,    (if fails,
   stop here)      fix first)  fix & re-run)  fix & re-run)
```

**Order rationale:**

- **Build first** — no point testing code that doesn't compile
- **Tests second** — verify behavior before worrying about style
- **Lint third** — formatting/style fixes shouldn't break tests
- **Typecheck last** — type errors are often caught by tests too, but mypy/tsc catch more

### 3. Handle Failures

For each failing step:

1. Read the error output carefully
1. Fix the issue
1. Re-run from the failing step (not from the beginning)
1. If a lint fix modifies files, re-read them before proceeding
1. Continue to the next step only when the current step passes

### 4. Report Results

After all steps complete, summarize:

```text
Verification Results:
  ✓ Build    — passed (or N/A)
  ✓ Tests    — 42 passed, 0 failed
  ✓ Lint     — pre-commit passed (3 files checked)
  ✓ Typecheck — mypy passed (no errors)

All checks passed. Work is ready for commit.
```

Or if something failed:

```text
Verification Results:
  ✓ Build    — passed
  ✗ Tests    — 1 failed (test_user_login_invalid_credentials)
  ○ Lint     — skipped (tests must pass first)
  ○ Typecheck — skipped

Fix the failing test before proceeding.
```

## Verification Modes

### Full Verification (default)

Run all checks against the entire project:

```bash
# Build
make build  # or: npm run build, cargo build, etc.

# Test
pytest  # or: npm test, cargo test, go test ./...

# Lint (delegates to pre-commit-validation skill)
pre-commit run --all-files

# Typecheck
mypy .  # or: tsc --noEmit, cargo clippy
```

### Changed Files Only

When verifying only modified files (faster, for incremental work):

```bash
# Test — run tests related to changed files
pytest tests/test_<module>.py  # targeted test files

# Lint — only changed files
pre-commit run --files <changed-files>

# Typecheck — full project (type errors can cascade)
mypy .
```

## Integration with pre-commit-validation

The **lint** step delegates to the existing `pre-commit-validation` skill:

1. Load `pre-commit-validation` skill for the lint step
1. Follow its workflow (run → read modified files → re-run until clean)
1. Return to this skill's sequence after lint passes

Do NOT duplicate pre-commit logic — use the existing skill.

## Project-Specific Commands

See [references/project-commands.md](references/project-commands.md) for detailed commands by
project type.

## Skipping Unavailable Tools

If a tool is not available (not installed, no config file):

- **Skip it** with a note: "Typecheck: skipped (mypy not installed)"
- Do NOT fail the verification loop for missing optional tools
- Do NOT suggest installing tools unless the user asks

Required vs optional:

- **Required:** At least one of build/test/lint must be available
- **Optional:** Typecheck, security scanning
