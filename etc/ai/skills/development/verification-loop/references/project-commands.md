# Project-Specific Verification Commands

## Python Projects

**Detection:** `pyproject.toml` or `setup.py` exists

### Build

Most Python projects don't have a build step. Skip unless:

- `pyproject.toml` has a `[build-system]` section with compiled extensions
- A `Makefile` with a `build` target exists

### Test

```bash
# Activate venv first (see virtual-environment skill)
source .venv/bin/activate

# Standard pytest
pytest

# With coverage
pytest --cov=app --cov-report=term-missing

# Specific test file
pytest tests/test_specific.py

# Verbose on failure
pytest -v --tb=short
```

**Config locations:** `pyproject.toml [tool.pytest.ini_options]`, `pytest.ini`, `setup.cfg`

### Lint

Delegate to `pre-commit-validation` skill. Common Python hooks:

- ruff (format + lint)
- mypy (type checking, sometimes in pre-commit)
- bandit (security)

### Typecheck

```bash
# mypy with project config
mypy .

# Or target specific packages
mypy app/

# With strict mode (if configured)
mypy --strict app/
```

**Config locations:** `pyproject.toml [tool.mypy]`, `mypy.ini`, `.mypy.ini`

## Node.js Projects

**Detection:** `package.json` exists

### Build

```bash
# Check package.json scripts for build command
npm run build
# or
yarn build
```

Skip if no `build` script in `package.json`.

### Test

```bash
npm test
# or specific runner
npx jest
npx vitest
```

### Lint

```bash
# If eslint configured
npx eslint .

# Or delegate to pre-commit if .pre-commit-config.yaml exists
pre-commit run --all-files
```

### Typecheck

```bash
# TypeScript projects
npx tsc --noEmit
```

**Detection:** `tsconfig.json` exists

## Shell Projects

**Detection:** Only `.sh`/`.bash` files, no `pyproject.toml`/`package.json`

### Build

N/A for shell projects.

### Test

```bash
# If using zunit (dotfiles pattern)
zunit

# If using bats
bats tests/
```

### Lint

```bash
# Delegate to pre-commit
pre-commit run --all-files

# Or manually
shellcheck scripts/*.sh
shfmt -d scripts/*.sh
```

### Typecheck

N/A for shell projects.

## Make-Based Projects

**Detection:** `Makefile` exists

### Build

```bash
make build
# or
make all
```

### Test

```bash
make test
```

### Lint

```bash
make lint
# or delegate to pre-commit
```

Check `Makefile` for available targets before running.

## Rust Projects

**Detection:** `Cargo.toml` exists

### Build

```bash
cargo build
```

### Test

```bash
cargo test
```

### Lint

```bash
cargo clippy -- -D warnings
```

### Typecheck

Handled by `cargo build` (Rust's type system is checked at compile time).

## Go Projects

**Detection:** `go.mod` exists

### Build

```bash
go build ./...
```

### Test

```bash
go test ./...
```

### Lint

```bash
golangci-lint run
# or
go vet ./...
```

### Typecheck

Handled by `go build` (Go's type system is checked at compile time).

## Mixed Projects

When multiple detection files exist, run all applicable checks:

1. Determine primary language from project structure
1. Run build/test for the primary language
1. Run pre-commit for linting (covers all languages)
1. Run typecheck for the primary language

Example: Python project with shell scripts

```text
Build: skip (Python)
Test: pytest
Lint: pre-commit run --all-files (covers Python + shell)
Typecheck: mypy .
```
