# Virtual Environment Guidance

When working with Python projects or executing project-specific tools, always check for the
presence of a virtual environment and ensure it's activated before running commands.

## Detection and Activation

1. Check for the presence of a virtual environment directory:
   - Common locations: `.venv/`, `venv/`, `.env/`, `env/`

2. If a virtual environment exists, activate it before running any project-specific commands:

   ```bash
   source .venv/bin/activate  # For .venv directory
   source venv/bin/activate   # For venv directory
   ```

3. After activation, verify the correct environment is being used:

   ```bash
   which python  # Should point to the virtual environment's Python
   which pre-commit  # Should point to the virtual environment's pre-commit
   ```

## Common Issues Without Activation

Without activating the virtual environment, you may encounter:

- Wrong tool versions being used (global instead of project-specific)
- Missing dependencies that are only installed in the virtual environment
- Inconsistent behavior between local development and CI/CD environments
- Permission errors when tools try to modify global packages

## When to Activate

Always activate the virtual environment before running:

- Package management tools (pip, poetry, pipenv)
- Testing frameworks (pytest, unittest)
- Linters and formatters (flake8, black, isort)
- Pre-commit hooks
- Any project-specific scripts or commands

## Example Workflow

```bash
# Check if virtual environment exists
if [ -d ".venv" ]; then
    # Activate the virtual environment
    source .venv/bin/activate
    echo "Virtual environment activated"
fi

# Now run the command with the correct environment
pre-commit run --all-files
```

This guidance helps ensure that all commands run in the correct environment context, preventing
version mismatches and dependency issues.
