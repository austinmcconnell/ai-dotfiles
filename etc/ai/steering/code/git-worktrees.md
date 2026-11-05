# Git Worktrees

How to work on several branches of one repo at the same time without switching the main checkout.
These rules apply to any AI tool and to manual work. Use a worktree when a second branch needs work
in parallel, such as an agent on another task or a background review. A single linear change does
not need one.

## Layout

```text
~/projects/<org>/worktrees/<repo>/<branch-dir>
```

- `<branch-dir>` is the branch name with each `/` replaced by `-`, so `fix/bundle-in-flight-409`
  becomes `fix-bundle-in-flight-409`.
- Keep worktrees outside the repo. Never nest one inside the repo it came from.

## Commands

```bash
# Existing branch
git worktree add ~/projects/<org>/worktrees/<repo>/<branch-dir> <branch>

# New branch from a base such as origin/main
git worktree add -b <branch> ~/projects/<org>/worktrees/<repo>/<branch-dir> origin/main

# Remove when finished
git worktree remove ~/projects/<org>/worktrees/<repo>/<branch-dir>
git worktree prune
```

- Remove with `git worktree remove`, never `rm -rf`. It also clears git's metadata under
  `.git/worktrees/`.
- Never delete the branch as part of cleanup. State that it is ready to delete and let the user run
  the deletion.
- Git will not check out one branch in two worktrees. If that happens, choose a different branch
  rather than forcing the checkout.

## Agent Rules

- Work only in the worktree path given in your instructions. Use the absolute path.
- Before editing, confirm that `git rev-parse --show-toplevel` and `git branch --show-current` match
  the assignment.
- Do not edit the main checkout while a worktree is assigned to you.

## Caveats

- Dependencies and build outputs, such as virtualenvs and `node_modules`, are per worktree. Install
  them in each new worktree.
- Fixed dev-server ports collide across worktrees. Run one at a time or use distinct ports.
- Gitignored files such as `.env` do not come along. Do not copy secret files to set up a worktree;
  ask the user.
