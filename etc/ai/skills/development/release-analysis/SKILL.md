---
name: release-analysis
description: Create structured release analysis files documenting code changes between version tags. Use when creating version analysis, documenting a release, analyzing commits between tags, or writing release notes.
---

# Release Analysis

Create a structured analysis document for a software release by examining the git history between
two version tags.

## When to Use

- User asks to create a release analysis or version analysis file
- User asks to document what changed in a release
- User asks to analyze commits between version tags

## Research Procedure

Follow these steps in order. Each step builds on the previous one.

### Step 1: Identify the Tag Range

```bash
git --no-pager tag --sort=-v:refname | head -20
```

Determine the previous production tag and the target tag. Identify the project's tag convention
first — projects may use bare semver (`0.0.74`), v-prefixed (`v1.2.3`), or other patterns. Look at
existing tags to determine which represent production releases vs pre-release variants (alpha, beta,
rc, etc.).

### Step 2: Full Commit Log (with Bodies)

```bash
git --no-pager log <prev_tag>..<new_tag> --format='%H%n%s%n%b%n---COMMIT_SEPARATOR---'
```

**Critical:** Never use `--oneline`. Commit bodies contain essential context — rationale, impact
descriptions, design decisions, benchmarks, and migration notes. The summary line alone is
insufficient for analysis.

### Step 3: Identify Merge Commits (PR Numbers)

```bash
git --no-pager log <prev_tag>..<new_tag> --merges --format='%H %s'
```

Extract PR numbers from merge commit messages (e.g., "Merge pull request #669 from ...").

### Step 4: PR Details from GitHub

For each PR identified:

```bash
gh pr view <number> --json title,body,author,mergedAt,labels,comments,reviews
```

The PR body often contains background information, implementation details, and testing notes not
present in commit messages. Review comments may contain important context about design decisions or
risks identified during review.

### Step 5: Code Diff

```bash
git --no-pager diff --stat <prev_tag>..<new_tag>    # File-level summary
git --no-pager diff <prev_tag>..<new_tag>           # Full diff for detailed analysis
```

Read the actual code changes to verify claims in commit messages and PR descriptions. The diff is
the ground truth.

### Step 6: Release Metadata

```bash
gh release view <tag> --json tagName,publishedAt,body,name
```

Get the published date and any auto-generated release notes.

## Writing the Analysis

Read `references/output-template.md` for the document structure.

### Key Principles

- **Ground claims in the diff** — if a commit message says "eliminates N+1 queries," verify by
  reading the actual code change
- **Quantify impact** — "~40 queries eliminated" is better than "performance improved"
- **Explain the why** — connect each change to the problem it solves or the feature it enables
- **Assess risk** — note global vs scoped changes, model-level vs query-level, etc.
- **Connect to prior releases** — if changes build on previous fixes, include a cumulative impact
  table showing progression across releases

### Naming Convention

Files are placed in the project's `releases/` directory (create it if it doesn't exist):

```text
releases/version-X-X-X.md
```

Version numbers use hyphens, not dots (e.g., `version-0-0-74.md`).

**`releases/` is git-ignored** — these reports are local-only working artifacts for developer and
agent use. The durable, shared record of what shipped in a release is the **GitHub Releases**
feature, not these files. Do not commit them and do not reference them by path in commit messages.

### Categorizing Changes

Assign each PR a category:

- **Incident Fix** — incident response or production hotfix
- **Feature** — new functionality
- **Performance** — optimization without functional change
- **Revert** — reverting a previous change
- **Dependency** — dependency version bumps
- **Refactoring** — structural improvement without behavior change
- **Infrastructure** — Helm, Terraform, CI/CD changes

### Risk Levels

Assign risk per component:

- **LOW** — isolated change, no global side effects, easily reversible
- **LOW-MEDIUM** — broader scope but well-understood impact
- **MEDIUM** — changes shared code paths or configuration
- **HIGH** — affects production data, auth, or critical hot paths
- **CRITICAL** — architectural change with cascading effects

## Delegating to Subagents

### Runner

Run this skill with an agent that has `gh` and unrestricted file operations (a **code** agent).
Issue-tracker agents may have read-only git (`git log`/`diff`/`show`) but typically lack `gh` —
needed for PR bodies and release metadata in Steps 4 and 6 — and deny `mv`/`cp`/`rm`, which breaks
report relocation. Ticket IDs in reports are just PR labels; the procedure never calls a tracker
API, so an issue-tracker agent is the wrong runner even though the tickets are its topic. Delegate
per-release drafting to code sub-agents.

### When to delegate

- **Backfill of multiple releases** (several unanalyzed tags at once): delegate. Each report is
  context-heavy (full commit logs, PR bodies, diffs) and offloading keeps the orchestrator's context
  clean.
- **Single new release at deploy time**: do it inline. Delegation overhead is not worth it for one
  report.

### Hybrid model: fan out, then stitch

Release reports have a **one-directional** dependency — a report may reference *earlier* releases
(e.g. "continues the cache-storm series from 0.0.79", cumulative-impact tables) but never later
ones. Exploit this:

1. **Phase 1 — parallel drafts.** The expensive, independent part (per-release commit log, PR
   details, diff, file changes, per-PR risk) parallelizes cleanly. Fan out one subagent per release
   tag; each **writes its draft to disk** at `releases/version-X-X-X-draft.md` and returns only a
   short status plus its ground-truth notes inline — never the full report as a return value. A
   context-heavy report passed back through the tool-result channel can be silently truncated or
   summarized by the subagent; a file on disk survives regardless of what the final message says.
   The orchestrator reads the draft files in Phase 2.
1. **Phase 2 — verify, then stitch.** Once all draft files exist, the orchestrator reads each one,
   diff-checks it (see "Orchestrator verifies ground truth"), then adds cross-release linkage
   (relationship-to-prior-releases prose, cumulative tables) in ascending version order — this is
   the step that needs the global view. Finally, rename each verified `version-X-X-X-draft.md` to
   `version-X-X-X.md`. The `-draft` suffix marks a report as not-yet-verified; only a checked,
   stitched report earns the final name.

Do **not** run pure-serial (wastes time re-deriving independent data) or pure-parallel (drafts can't
reference each other, producing duplicated or contradictory prior-release framing).

### Orchestrator verifies ground truth

Subagents draft; the orchestrator (or a dedicated verifier subagent) **must diff-check
decision-critical claims** against the actual code before accepting a draft. Commit messages and PR
bodies contain placeholders and errors — e.g. a commit referencing migration `a1b2c3d4e5f6` when the
committed file is `139d6d86dd94`. Verify migration ids, index/column names, config keys, and any
quantified impact claim against the diff and the real files. Never accept a draft wholesale.

Scope the check to those decision-critical categories, not every sentence — re-diffing an entire
report defeats the point of delegating. When two *authored* sources disagree with each other (e.g. a
code docstring claiming "5-8x faster" while the PR's own benchmark table measures 4.4–5.5x), prefer
the measured figure and flag the discrepancy in the report rather than repeating the rounder claim.

### Parallel git safety

Keep subagent git/`gh` operations **strictly read-only** (`log`, `diff`, `show`, `pr view`). Do not
let parallel subagents check out tags or mutate the working tree in a shared checkout — they will
collide. If git state changes are unavoidable, give each subagent its own worktree. This constraint
is about **git/worktree state**, not file output: each subagent writing its own distinct
`releases/version-X-X-X-draft.md` is safe and expected — separate per-release files never contend.
