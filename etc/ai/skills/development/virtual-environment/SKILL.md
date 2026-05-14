---
name: virtual-environment
description: Detect and activate Python virtual environments before running project commands. Use when working with Python projects, running pip/pytest/pre-commit, or when commands fail due to wrong Python version.
---

# Virtual Environment

## When to Use

- Working with Python projects or executing project-specific tools
- Running package management tools (pip, poetry, pipenv)
- Running testing frameworks (pytest, unittest)
- Running linters and formatters (flake8, black, isort)
- Running pre-commit hooks
- Running any project-specific scripts or commands
- Debugging issues with wrong tool versions, missing dependencies, or permission errors

## Workflow

### 1. Detect virtual environment

Check for a virtual environment directory in the project root:

- Common locations: `.venv/`, `venv/`, `.env/`, `env/`

### 2. Activate before running commands

```bash
source .venv/bin/activate  # For .venv directory
source venv/bin/activate   # For venv directory
```

### 3. Verify activation

```bash
which python      # Should point to the virtual environment's Python
which pre-commit  # Should point to the virtual environment's pre-commit
```

### Example

```bash
if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

pre-commit run --all-files
```

## Validation

- `which python` points to the virtual environment, not a global Python
- Project-specific tools (pytest, pre-commit, etc.) resolve to the virtual environment's bin
  directory
- Commands do not produce missing dependency or permission errors

## Common Issues Without Activation

- Wrong tool versions being used (global instead of project-specific)
- Missing dependencies that are only installed in the virtual environment
- Inconsistent behavior between local development and CI/CD environments
- Permission errors when tools try to modify global packages
