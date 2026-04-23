# Python Project Conventions

## Virtual Environment

Before running any Python tool (pytest, pre-commit, pip, python, flake8, black, isort), check for
and activate the project's virtual environment:

1. Look for `.venv/`, `venv/`, `.env/`, `env/` in the project root
1. Run `source .venv/bin/activate` (or equivalent) before any Python command
1. Verify with `which python` — it must point to the venv, not a global Python

If no venv exists and a Python command fails, suggest creating one before retrying.

## String Quoting

Use single quotes for Python strings. Only use double quotes when the string contains a single quote
(e.g., `"it's a test"`). The `double-quote-string-fixer` pre-commit hook enforces this across all
repositories.

## Pre-commit

After modifying files, run `pre-commit run --files <changed-files>` to validate. If hooks modify
files, read the modified versions before making further edits. Build on the corrected version.
