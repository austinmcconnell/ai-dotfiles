# Python Project Conventions

## Virtual Environment

Before running any Python tool (pytest, pre-commit, pip, python, ruff), check for and activate the
project's virtual environment:

1. Look for `.venv/`, `venv/`, `.env/`, `env/` in the project root
1. Run `source .venv/bin/activate` (or equivalent) before any Python command
1. Verify with `which python` — it must point to the venv, not a global Python

If no venv exists and a Python command fails, suggest creating one before retrying.

## Formatting

- 4-space indentation (ruff formatter)
- Max line length: 100 characters (ruff)
- Single quotes for strings; double quotes only when the string contains a single quote
  (`double-quote-string-fixer` pre-commit hook enforces this)
- No debug statements — `pdb`, `breakpoint()`, etc. (`debug-statements` pre-commit hook)
- Trailing whitespace and missing final newlines are auto-fixed by pre-commit
- Code examples in docstrings are auto-formatted (`docstring-code-format = true`)

## Imports

- Sort order: stdlib → third-party → first-party (ruff isort rules)
- Combine `as` imports on one line (`combine-as-imports = true`)
- No blank lines between `import` and `from` within a section (`force-sort-within-sections = true`)
- Alphabetical sort within sections approximated via `order-by-type = false` and
  `case-sensitive = false` (ruff lacks `force_alphabetical_sort_within_sections`;
  see <https://github.com/astral-sh/ruff/issues/4670>)
- No wildcard imports (F403)
- No unused imports (F401)
- No duplicate imports (E811)

## Naming

- `snake_case` for functions, methods, variables, arguments, and modules (N802, N803, N806)
- `PascalCase` for classes (N801)
- `UPPER_CASE` for constants (N816)

## Type Checking

- All function definitions must have complete type annotations (`mypy disallow_incomplete_defs`)
- Avoid returning `Any` (`mypy warn_return_any`)

## Linting Limits

- Max function/method arguments: 5 (PLR0913)
- Max class attributes: 7 (PLR0902)
- Max local variables: 15 (PLR0914)
- Max statements per function: 50 (PLR0915)
- Max nested blocks: 5 (PLR1702)
- Max cyclomatic complexity: 10 (C901)

## Pre-commit

After modifying files, run `pre-commit run --files <changed-files>` to validate. If hooks modify
files, read the modified versions before making further edits. Build on the corrected version.
