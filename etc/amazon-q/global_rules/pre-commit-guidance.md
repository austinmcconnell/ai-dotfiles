# Pre-commit Validation Guidelines

When generating content, if there is a `.pre-commit-config.yaml` file in the root of the project,
ensure all code and documentation passes pre-commit checks before finalizing.

## Validation Process

1. Generate the initial content based on requirements
1. Run pre-commit checks against the generated files
1. Fix any issues identified by the checks
1. Verify the fixed content passes all checks

## Handling Files Modified by Hooks

When pre-commit output shows "files were modified by this hook":

1. Read the modified files to understand changes made by the hooks

   ```bash
   fs_read mode=Line path=path/to/modified/file
   ```

2. Incorporate those hook-made changes into your understanding of the current file state
3. Make any additional modifications on top of the hook-modified version
4. Run pre-commit checks again to ensure all issues are resolved

This is important because pre-commit hooks often automatically fix formatting issues, import ordering,
trailing whitespace, and other style violations. Working with the post-hook version ensures you're
building on the corrected files rather than the original ones with style issues.

## Example Validation Commands

```bash
# Validate all files
pre-commit run --all-files

# Validate specific files
pre-commit run --files path/to/file

# Run specific hooks
pre-commit run markdownlint --files path/to/markdown/file.md
```

## Common Checks

### Markdown

- Line length limited to 100 characters (except tables)
  - Words should not begin before the 100-character limit and extend beyond it
- Headers must be surrounded by blank lines
- Lists must be surrounded by blank lines
- Ordered lists should use consistent item prefixes (all 1.)
- Code blocks must specify a language and be surrounded by blank lines

### Python

- Imports are sorted using isort
- Code is formatted according to autopep8 and yapf standards
- Line length typically limited to 100 characters
- Double quotes are converted to single quotes where appropriate
- Trailing whitespace is removed
- Unused imports are removed

### YAML/Docker Compose

- Docker Compose files must be sorted according to the custom sorter
- YAML files must be valid

### JSON

- JSON files must be valid and properly formatted with 4-space indentation

## Documentation Updates

If during validation of generated content (steps 2 and 3 of `Validation Process`) other common
checks are found which are not listed in this document, add them to the `Common Checks`
section of this document. This will help improve the initially generated content of future chat
sessions and reduce the need for multiple cycles of generate, validate, fix, etc.
