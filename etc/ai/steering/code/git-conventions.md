# Git Conventions

## Branch Naming

- Feature: `feat/<short-description>`
- Fix: `fix/<short-description>`
- Chore: `chore/<short-description>`
- Docs: `docs/<short-description>`
- Use kebab-case: `feat/add-zsh-completions`

## Commit Discipline

- Only create commits when the user explicitly asks
- Stage specific files — never `git add .` or `git add -A`
- Run pre-commit hooks before committing (see `pre-commit-validation` skill)
- If pre-commit modifies files, re-read them before proceeding
- For multi-commit work, follow the `commit-workflow` steering cadence (plan → one commit at a time
  → pause → verify)

## Push Workflow

- Push to a feature branch, not directly to main
