# README Pointer Audit

**IMPORTANT: Branch Validation Required** Before proceeding, verify the current git branch:

```bash
git branch --show-current
```

This audit should ONLY be performed on `main` or `master` branches. If currently on a different
branch, abort and inform the user that the README pointer audit should be done from the main branch.

**Read the convention first:** This audit APPLIES the `readme-pointer` skill at repo scale — it does
not restate the rules. Read `~/.kiro/skills/shared/readme-pointer/SKILL.md` (or
`~/.dotfiles/etc/ai/skills/shared/readme-pointer/SKILL.md`) before proposing any map, and obey its
hard constraints when authoring: **one-hop** (a pointer names the actual target doc, never another
README), **flat, not deep** (one level of indexing — do NOT create nested index trees), and
**high-signal only** (name the docs a reader would actually need, not every file).

**README Pointer Audit:** Survey how well this repository's documentation is reachable via the
README-as-pointer scheme, then populate missing pointers under a chosen cadence. The goal is that a
reader (human or agent) can find any important doc by reading the nearest README as a map — without
eager-loading a `docs/` tree.

## Phase 1 — Inventory & Gap Report (always; read-only)

This phase is non-destructive and is the discovery mechanism that defuses the chicken-and-egg
problem of opportunistic population: it finds EVERY orphaned doc up front so later population works
from a known, ranked worklist instead of waiting to stumble onto a gap.

1. **Enumerate docs.** Find every `.md` (and `.rst`/`.adoc` if present), excluding vendored/build
   paths (`node_modules`, `.git`, `dist`, `build`, `.venv`, `target`).
1. **Enumerate READMEs.** Find every `README.md` and note its directory level.
1. **Map coverage.** For each README, parse its pointer lines and record which sibling/child docs it
   names. For each non-README doc, determine whether the nearest README points at it.
1. **Rank the gaps.** Produce a table of orphaned docs (docs no README points at), ranked by
   importance. Approximate importance with:
   - proximity to root (root and top-level dirs rank highest),
   - change frequency (`git log` touch count — frequently-edited docs are high-traffic),
   - whether the doc sits in a recognized docs location (`docs/`, `doc/`, subsystem dirs).
1. **Flag violations of the scheme**, not just absences:
   - README → README pointers (breaks the one-hop rule),
   - nested index trees (breaks the flat rule),
   - README pointers to docs that no longer exist (dangling),
   - over-listing (a README that indexes low-signal noise).

**Output (Phase 1):** Write the gap report to `analysis/readme-pointer-audit.md` with the metadata
header below. This file is git-ignored; it is a worklist, not a committed artifact.

```markdown
# README Pointer Audit

**Generated:** [YYYY-MM-DD HH:MM:SS UTC]
**Branch:** [current branch name]
**HEAD Commit:** [full commit hash]
**Repository:** [repository name/path]

---
```

The report body must contain: the ranked orphaned-doc table, the scheme-violation list, and a short
"recommended cadence" call based on how many gaps exist and how concentrated they are.

## Phase 2 — Populate (choose a cadence; proposes diffs only)

Populating means creating or editing README maps. This is bulk file authoring: **propose it as a
reviewable diff and let the user commit.** Never auto-commit generated maps (per `commit-workflow`
steering). Every map written must obey the skill's one-hop / flat / high-signal constraints.

Pick the cadence with the user — do not assume:

### Bounded hybrid (recommended default)

Do Phase 1 completely (cheap, gives the whole picture), then quick-populate ONLY:

- the root `README.md`, and
- one level of high-traffic subdirectories from the top of the ranked list.

Leave the long tail to the opportunistic path below. This deliberately honors the **flat, not deep**
constraint — it does not carpet every nested directory with index files. Present the batch as a
single diff.

### Opportunistic / just-in-time (highest quality, slowest coverage)

Do not bulk-generate. Instead, the ranked gap list from Phase 1 becomes a standing worklist:
whenever normal work touches a directory whose needed doc is on that list, add that one pointer then
(and remove it from the worklist). Pointers get written exactly for the docs that proved worth
finding, self-prioritized by real usage. Coverage grows where you actually work.

> **Why Phase 1 is mandatory even for this cadence:** a purely passive opportunistic path
> systematically misses the hardest-to-discover docs — if a doc isn't mapped, the agent may never
> navigate to it, so the gap is never recorded. The Phase-1 inventory surfaces those docs up front
> so they can be promoted deliberately rather than never found.

### Quick sweep (fastest coverage, use with care)

Generate/patch all README maps in one ordered pass. Appropriate only for a repo with zero existing
maps that needs baseline coverage fast. Higher risk of listing low-signal docs — enforce the
high-signal cap hard, and present as one large reviewable diff for the user to prune.

## Commands to gather metadata & inventory

```bash
# Metadata
git branch --show-current
git rev-parse HEAD
basename "$(git rev-parse --show-toplevel)"
date -u +"%Y-%m-%d %H:%M:%S UTC"

# All docs (exclude vendored/build)
find . -type f \( -name "*.md" -o -name "*.rst" -o -name "*.adoc" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/dist/*" \
  -not -path "*/build/*" -not -path "*/.venv/*" -not -path "*/target/*"

# All READMEs and their levels
find . -type f -name "README.md" -not -path "*/node_modules/*" -not -path "*/.git/*"

# Change frequency for a doc (high count = high traffic, higher rank)
git rev-list --count HEAD -- <path/to/doc.md>
```

## Update strategy

If `analysis/readme-pointer-audit.md` already exists:

1. Read it and its `**HEAD Commit:**` line.
1. If the commit matches current HEAD, the audit is current — ask whether to force a refresh.
1. Otherwise re-run Phase 1, preserving any "opportunistic worklist" entries not yet populated, and
   refresh the metadata header.

## Notes

- Phase 1 is always safe (read-only). Phase 2 authors files — propose diffs, user commits.
- The authoring rules live in the `readme-pointer` skill; this prompt does not duplicate them.
- Chainable: run standalone via `ai-use readme-pointer-audit`, or as a follow-on to
  `documentation-analysis`.
