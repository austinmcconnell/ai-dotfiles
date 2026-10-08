# README Coverage Audit

**Read the convention first:** Read the `readme-pointer` skill before proposing anything.

**README Coverage Audit:** Find (1) directories that deserve a README and lack one, and (2) existing
READMEs whose content has drifted from the files they describe. This is distinct from
`readme-pointer-audit`, which checks that docs are _reachable_ from README maps. Nested READMEs here
are for humans and for agents that are pointed at them; the skill's one-hop and flat rules govern
the root _map_, not whether a directory may have its own README. Do not refuse to propose a nested
README on those grounds.

## Phase 1 — Survey (read-only; do this yourself)

The survey is cheap and needs the whole picture, so do not delegate it.

1. **Inventory.** Count tracked files per directory (depth <= 3) with `git ls-files`, and list every
   existing `README.md`.
1. **Missing.** Recommend a README when a directory has ~8+ files of mixed purpose, non-obvious
   names, overlapping or legacy files (which is canonical?), or a script collection with unclear
   status. Skip single-file or self-explanatory directories; cover many small ones with one index
   table in the parent (tool -> contents -> the script that installs it).
1. **Stale.** For each README, diff its claims against disk:
   - file trees vs `git ls-files`
   - command and flag lists vs the tool's real `--help` output
   - registered hooks and entry points vs config
   - links and paths vs existence
   - path naming (`~/.dotfiles` vs `~/dotfiles`)

   Last-touched dates (README vs its directory) are a hint only, never proof.

1. **Report.** Write the ranked report to `analysis/readme-coverage-audit.md` (git-ignored) with the
   metadata header below. Separate **verified drift** (you diffed it) from **suspected** (not
   checked).

```markdown
# README Coverage Audit

**Generated:** [YYYY-MM-DD HH:MM:SS UTC]
**Branch:** [current branch name]
**HEAD Commit:** [full commit hash]
**Repository:** [repository name/path]

---
```

## Phase 2 — Author (propose; the user stages and commits)

Do small directories and edits to existing READMEs yourself. Delegate only where reading is heavy (a
directory with ~15+ files). Subagents may write the README in place (git makes it reversible), and
you review the result.

### Subagent brief template

Every subagent brief must contain all of the following:

- **Target:** the directory, plus the exact `git ls-files <dir>` output (so it cannot invent or omit
  files).
- **Style reference:** an existing README to match in length and density.
- **Callers checklist:** grep for references in `install.sh`, `install/*.sh`, `bin/`,
  `.pre-commit-config.yaml`, shell config, and the `Makefile`. An "unused" or "no references" claim
  must cite the grep command and its hits; otherwise write "no caller found in <places searched>".
- **No invented rationale:** describe what exists, never why it exists. If a "why" is needed, write
  "reason not recorded".
- **Counts for generalizations:** any claim about "all", "most" or "the scripts" must carry `N of M`
  from a command; otherwise name the specific files.
- **Quote, don't recall:** signatures, flags and names are copied from the file, each with a source
  line.
- **Tracked links only:** run `git check-ignore -v <path>` before linking any path; never cite
  git-ignored or personal-tooling files.
- **Fixed table columns:** name, what it does, how it is run. No date columns or other values that
  go stale.
- **Stop-and-report:** if something looks broken or contradictory, document the current behavior in
  one factual line and flag it. Do not work around it, fix it, or guess.
- **Scope:** do not edit any file other than the README.
- **Return format:** the README path, a **claims ledger** (table: claim | supporting command or
  file:line | `verified` or `inferred`), and a list of "things I could not verify". A self-reported
  "all claims verified" is not accepted.

### Review every subagent README as unverified

Before presenting, spot-check the `inferred` rows and a sample of the `verified` rows against disk,
and check each filename, command and behavior claim. Failure patterns seen in practice:

- an invented rationale ("migration was completed to centralize...")
- a false "no references found" (grep the callers yourself, including `bin/`)
- an over-generalization ("scripts use utils.sh" when 5 of 22 do)
- a wrong function signature
- citations of git-ignored files

### README content rules

- State only what you verified; say "no caller found" instead of "unused".
- Bugs or oddities found while documenting are **not fixed here**. Record them as unrefined items in
  `ideas.md` (see the `idea-refinement` skill) and, if a README must mention one, state the current
  behavior factually.
- Format with the repo's formatter and re-read the file before further edits, since it rewraps.

## Commit plan (follow `commit-workflow`)

Present the plan and wait for approval before editing. Order:

1. Fixes to existing READMEs, one commit per directory.
1. New READMEs, one per commit.
1. The index and the root "Directory map" last (one-hop pointers to real READMEs, no chains).

Per commit: present the `git add` list and message, wait for the user to commit, then verify with
`git log -1`. Never commit yourself.

## Update strategy

If `analysis/readme-coverage-audit.md` already exists, read its `**HEAD Commit:**` line. If it
matches current HEAD, the audit is current: ask whether to force a refresh. Otherwise re-run Phase 1
and refresh the metadata header.

## Commands to gather metadata & inventory

```bash
# Metadata
git branch --show-current
git rev-parse HEAD
basename "$(git rev-parse --show-toplevel)"
date -u +"%Y-%m-%d %H:%M:%S UTC"

# Tracked file count per directory (depth <= 3)
git ls-files | awk -F/ 'NF>1 {d=$1; for(i=2;i<NF&&i<=3;i++) d=d"/"$i; print d}' | sort | uniq -c | sort -rn

# Existing READMEs
git ls-files | grep -i 'readme.md$'

# Is a path git-ignored (do not link it from a committed doc)?
git check-ignore -v <path>
```

## Notes

- Phase 1 is read-only. Phase 2 authors files; propose, and the user commits.
- Chainable: run standalone via `ai-use readme-coverage-audit`, or after `readme-pointer-audit`.
