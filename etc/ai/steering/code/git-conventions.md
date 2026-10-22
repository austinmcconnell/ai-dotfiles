# Git Conventions

## Branch Naming

- Feature: `feat/<short-description>`
- Fix: `fix/<short-description>`
- Chore: `chore/<short-description>`
- Docs: `docs/<short-description>`
- Use kebab-case: `feat/add-zsh-completions`

## Commit Discipline

- Only create commits when the user explicitly asks
- The user stages and commits: propose the `git add` list and message, and never run `git add`,
  `git commit` or `--amend` yourself — including when offering to "finish up"
- Stage specific files — never `git add .` or `git add -A`
- Run pre-commit hooks before committing (see `pre-commit-validation` skill)
- If pre-commit modifies files, re-read them before proceeding
- For work you intend to commit, follow the `commit-workflow` skill cadence (plan → verify → pause →
  confirm it landed); for multi-commit work, add working one commit at a time
- When a commit needs correcting, check push status first
  (`git rev-parse --abbrev-ref --symbolic-full-name @{u}`) — for a commit with no upstream that
  serves the same logical goal, mention `git commit --amend`/fixup as an option rather than
  defaulting straight to recommending a new commit. Still requires the user's explicit go-ahead,
  like any commit action.

## Push Workflow

- Push to a feature branch, not directly to main
- Never delete branches, even as an offered option — state that a branch is ready to delete and let
  the user run it themselves.

## Reading History

- Never use `git log --oneline` — it strips the commit body where the WHY context lives. Use the
  default `git log` format (or a `--format` that keeps subject + body) so multi-line messages are
  visible.
- When investigating *why* code is the way it is — before changing or debugging a file whose
  rationale isn't obvious from the code itself — search history for the commit that introduced or
  last touched it, and read the **full multi-line body**, not just the subject. The
  `commit-message-writing` skill puts the motivation (WHY) in the body, so the context you need is
  usually already recorded there rather than needing to be reverse-engineered or asked for.
  - `git log -G'<regex>'` / `git log -S'<string>'` — find the commit where a line or string entered
    or left (pickaxe); the most direct way to reach the change that created the behavior.
  - `git log --grep='<keyword>'` — find commits whose message mentions a feature, bug, or concept.
  - `git log -- <path>` — history scoped to one file; add `-p` to see each change with its message.
  - `git blame <path>` then `git show <sha>` — go from a specific line to the commit that set it and
    read that commit's full message.
- **When NOT to dig:** skip commit archaeology when the code is self-explanatory, the change is
  trivial (typo, rename, formatting), or the rationale is already in context (a doc, an ADR, the
  current task). Reserve it for the case where the WHY is load-bearing for what you're about to do
  and not obvious — don't reflexively `git log` every file you read.
