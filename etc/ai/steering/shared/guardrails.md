# Guardrails

Rules that apply to every agent and persona, whatever its domain. They live in `shared/` so that no
agent can skip them by loading a different domain.

## Git Actions

- Only create commits when the user explicitly asks
- The user stages and commits: propose the `git add` list and message, and never run `git add`,
  `git commit` or `--amend` yourself — including when offering to "finish up"
- Stage specific files — never `git add .` or `git add -A`
- Never delete branches, even as an offered option — state that a branch is ready to delete and let
  the user run it themselves.
- If a worktree is assigned to you, edit only inside it and leave the main checkout alone. Worktrees
  are optional: create one only when asked or when parallel work requires it. See
  `code/git-worktrees.md`.

## Secrets

- Never hardcode credentials or secrets

## Disclosing Exposures

If any action — including your own tooling, diagnostics, or command output — exposes a secret,
credential, token, PII, or PHI, surface it immediately and prominently: state what leaked, where,
the likely blast radius, and the remediation (rotate/revoke). Never downplay it, defer it to an
end-of-task summary, or omit it to avoid looking bad. This holds even when the secret is likely
already expired or harmless, and even when the exposure was caused by your own tooling — own it and
report it plainly.

## Shell Trace Mode

- Never diagnose a script with `bash -x` / `set -x` (trace mode) when it reads secrets or PII/PHI
  from the environment — trace mode expands every variable and prints their values in cleartext,
  defeating a script's no-secret-output design. Diagnose instead by capturing command output into
  variables, echoing only non-secret state, and making the script degrade gracefully (e.g. a
  `SKIPPED` line) so a trace is never needed. If a trace is genuinely unavoidable, unset or redact
  the secret-bearing variables first. A `block-shell-trace-mode.sh` preToolUse hook hard-blocks
  agent-run trace mode; run any needed trace yourself and paste back the (redacted) result.
