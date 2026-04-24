# Python Project Conventions

## Virtual Environment

Before running any Python tool (pytest, pre-commit, pip, python, flake8, isort), check for and
activate the project's virtual environment:

1. Look for `.venv/`, `venv/`, `.env/`, `env/` in the project root
1. Run `source .venv/bin/activate` (or equivalent) before any Python command
1. Verify with `which python` — it must point to the venv, not a global Python

If no venv exists and a Python command fails, suggest creating one before retrying.

## Formatting

- 4-space indentation (pylint, yapf)
- Max line length: 100 characters (flake8, pylint, yapf, isort)
- PEP 8 base style (yapf `based_on_style = pep8`)
- Single quotes for strings; double quotes only when the string contains a single quote
  (`double-quote-string-fixer` pre-commit hook enforces this)
- No debug statements — `pdb`, `breakpoint()`, etc. (`debug-statements` pre-commit hook)
- Trailing whitespace and missing final newlines are auto-fixed by pre-commit

## Imports

- Sort order: stdlib → third-party → first-party (isort)
- Combine `as` imports on one line (`combine_as_imports = true`)
- No blank lines between `import` and `from` within a section (`force_sort_within_sections = true`)
- Force alphabetical sort within sections (`force_alphabetical_sort_within_sections = true`)
- No wildcard imports (`wildcard-import` enabled in pylint)
- No unused imports (`unused-import` enabled in pylint)
- No duplicate imports (`reimported` enabled in pylint)

## Naming

- `snake_case` for functions, methods, variables, arguments, and modules (pylint)
- `PascalCase` for classes (pylint)
- `UPPER_CASE` for constants (pylint)
- Allowed short names: `i`, `j`, `k`, `ex`, `Run`, `_`, `id`, `db` (pylint `good-names`)

## Type Checking

- All function definitions must have complete type annotations (`mypy disallow_incomplete_defs`)
- Avoid returning `Any` (`mypy warn_return_any`)

## Linting Limits

- Max function/method arguments: 5 (pylint)
- Max class attributes: 7 (pylint)
- Max local variables: 15 (pylint)
- Max statements per function: 50 (pylint)
- Max nested blocks: 5 (pylint)

## Pre-commit

After modifying files, run `pre-commit run --files <changed-files>` to validate. If hooks modify
files, read the modified versions before making further edits. Build on the corrected version.
