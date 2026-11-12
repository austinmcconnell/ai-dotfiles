# Zunit Pre-Push Audit

Audit the zunit tests that run before each push in my dotfiles repo (`~/.dotfiles`). This is a
read-only audit: do not edit, stage, or commit anything. Write findings to
`analysis/zunit-pre-push-audit.md` (git-ignored) and summarize them in chat.

## Orient first

1. Run `git branch --show-current` and `git status --short`; note both in the report. Branch-name
   assumptions are one of the things under audit, so record where the run happened. Any branch is
   fine: on a feature branch, also run `git diff --stat main...HEAD -- tests etc/git/hooks` so the
   report separates pre-existing issues from ones the branch introduced, and treat branch-coupled
   test results as expected there rather than as failures.
1. Read `tests/README.md`, every `tests/*.zunit` file, `etc/git/hooks/pre-push`, `bin/dotfiles` (the
   `test` subcommand), `install.sh` (its zunit step), `Makefile` and `Dockerfile` (`docker-test`).
1. Read `~/.ai-dotfiles/etc/ai/steering/code/shell-conventions.md` if it exists, so findings match my
   conventions.
1. Check for the core analyses per `core-analyses.md` (`test -f analysis/<name>-analysis.md`) and
   read `analysis/project-analysis.md` if present. Do not generate any.
1. If `analysis/zunit-pre-push-audit.md` already exists, read it as the previous audit and move it to
   `analysis/zunit-pre-push-audit.prev.md` before writing the new report (this is the one file you
   may write outside the scratchpad, besides the report itself). The new report opens with a "Since the last audit" section
   listing each earlier finding as fixed, still open, or no longer applicable, then any new ones.
1. Run the suite once exactly as the hook does and record whether the gate is green or red before
   investigating anything else. Note that a test looping over items stops at its first failure, so
   later items stay unchecked until it passes.

## Questions to answer

### 1. Hook correctness

The hook is a git config-based hook (`[hook "pre-push-tests"]` in `etc/git/config`) that runs
`~/.config/git/hooks/pre-push`, a symlink to `etc/git/hooks/pre-push`. Confirm that still holds
rather than re-deriving it, and treat any change as a finding.

- Does `git hook list pre-push` still show the hook, and does the symlink resolve to an executable
  `etc/git/hooks/pre-push`? Never perform a real `git push`.
- Does a failing test still abort the push (`set -e` plus `xargs` exit codes)? Verify with a stand-in
  failing command, not by breaking a real test. Does a zunit failure surface a readable message?
- Is the `find tests -name "*.zunit"` discovery consistent with how `dotfiles test` and `install.sh`
  discover tests? Flag any drift.
- Do the docs that describe the hook (`etc/git/README.md`, `tests/README.md`) match what it does?
- Is there an escape hatch (`--no-verify`, an env var) and is it documented?
- The hook is global and also runs pytest and behave stanzas for other repos. Judge changes to it
  against those repos too, not only this one.

### 2. Speed and blocking

- Run the exact command the hook runs: `find tests -name "*.zunit" -print0 | xargs -0 zunit`, from
  the repo root, and time the whole run. Then time each file separately and, if zunit output allows,
  each test.
- Which tests are slow, and why (subprocess spawns, `uv python find` in a loop, `zsh -f` startups,
  network)? Which are fast enough not to matter?
- For each slow or low-value check, recommend where it belongs: keep in pre-push, move to
  `make docker-test` or CI, or run only after `install.sh`. A push gate should be fast and
  deterministic; say what budget you assume and why.

### 3. Flakiness and portability

For each test, record what it depends on beyond the repo: the current branch, `$DOTFILES_DIR`,
`$ZDOTDIR`, `$XDG_*`, installed tools, uv-managed interpreters, the user's home directory, network,
the working directory, time, and test order. Then:

- Run the suite from a different working directory and under `env -i` with a minimal environment (do
  this without touching the real home: use a temporary `HOME` and `XDG_*` under the scratchpad
  directory). Report which tests change result.
- Identify tests that pass or fail depending on the branch (for example, one asserting the trunk
  branch is `main`), on machine state, or on the host OS. Which would fail on a fresh Linux box or in
  the Docker harness, and is that intended? The README says these tests check an _installed_
  environment, so separate "legitimately needs an installed machine" from "accidentally
  environment-coupled".
- Check test hygiene: shared state between tests, temp files not cleaned up, `@teardown`
  correctness, placeholder assertions, and `echo` debugging left in tests.
- Prove every assertion can fail. For each `assert`, state what its operator actually does, then
  show it rejecting a wrong value with a scratch test. zunit's `equals` is arithmetic, not string
  comparison, so a string check with `equals` can pass on anything; string equality needs `same_as`.
  Also check for an empty value satisfying `contains`, a command that always exits 0, and a relative
  path that resolves to nothing from another working directory.
- Check zunit usage against the installed zunit source (`command -v zunit`, then read it) and
  confirm behaviour with scratch tests. The zunit.xyz docs are a secondary source: deep links have
  returned 404, so say when a doc page could not be fetched rather than relying on memory.

### 4. Coverage gaps and test value

- List what is tested today, grouped by what each test protects against.
- List what is not tested but would be cheap and valuable to cover, judged by how often it breaks and
  how costly a break is. Derive candidates from the repo's current layout (`install/`, `bin/`,
  `etc/zsh/`, symlinks the installers create) and from recent fix commits (`git log` with bodies, no
  `--oneline`), which show what actually breaks.
- Name tests that duplicate each other, duplicate a pre-commit hook, or protect against nothing that
  can realistically break. For each, say whether to keep, merge, or delete.
- Don't recommend coverage for its own sake. Each gap needs a concrete failure it would have caught.

## Output format

Group findings by severity, per my code review conventions:

- **Blockers**: the hook doesn't fire or doesn't fail the push; the gate is red on this machine; a
  test gives false confidence (an assertion that cannot fail).
- **Suggestions**: slow or flaky tests, real coverage gaps, drift between the hook and `dotfiles test`.
- **Nits**: naming, stale docs, style.

Use `[BLOCKER|SUGGESTION|NIT] file:line - description` for each finding, with evidence (the command
you ran and its output, or the file and line). Say explicitly when there are no blockers.

Finish the report with:

1. A timing table: file, test count, wall time.
1. A dependency table: test, external dependencies, portable (yes/no).
1. A ranked fix list. For each item: what to change, expected effect, and effort (small, medium,
   large). Put each fix as its own commit-sized unit so I can plan commits afterward.
1. What you verified versus inferred, and anything you could not check.

## Constraints

- Read-only against the repo and my home directory. Put all temporary files in one directory,
  `<scratchpad>/zunit-audit/`, and try to remove it at the end. If removal is denied, do not retry;
  list the leftover paths in the report.
- Run `make docker-test` only if Docker is running; otherwise say it was not checked.
- Never run `git add`, `git commit`, `git push`, or `git checkout`.
- Never read `.env` files, SOPS/age keys, or SSH private keys.
- If a test run needs something I may not have installed, report that instead of installing it.
