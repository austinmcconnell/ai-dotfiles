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

Files are placed in the project's `analysis/` directory (create it if it doesn't exist):

```text
analysis/version-X-X-X.md
```

Version numbers use hyphens, not dots (e.g., `version-0-0-74.md`).

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
