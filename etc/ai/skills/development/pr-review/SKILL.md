---
name: pr-review
description: Review GitHub pull requests with full context, verified findings, and structured feedback. Use when reviewing a PR, doing code review, analyzing a pull request diff, or asked to review changes on a branch.
---

# PR Review

## Overview

Conduct thorough PR reviews by checking out the branch for full context, investigating changes
against the actual codebase, and verifying concerns before raising them. Produces structured
feedback following the severity tiers in `code-review-conventions` steering.

## Workflow

### Step 1: Fetch PR details

1. Get PR metadata:
   `gh pr view <number> --json title,body,baseRefName,headRefName,additions,deletions,changedFiles,labels,milestone`
1. Get the full diff: `gh pr diff <number>`
1. Note the scope — number of files changed, lines added/removed — to calibrate review depth

### Step 2: Check out the PR branch

1. Verify the working tree is clean: `git status --porcelain`
1. **If clean:**
   - Record the current branch: `git rev-parse --abbrev-ref HEAD`
   - Check out the PR branch: `gh pr checkout <number>`
1. **If dirty:**
   - Show the user the dirty files
   - Inform them that a branch checkout enables a more thorough review and offer two paths: clean up
     the working tree first (for full-context review) or proceed with diff-only (reduced accuracy)
   - If user cleans up → re-check `git status --porcelain` and proceed with checkout
   - If user declines → proceed with diff-only review; add a note at the top of the review output:
     "Reviewed from diff only — surrounding context reflects the base branch, not the PR branch.
     Some findings may be less accurate."

### Step 3: Check for existing review feedback

1. Fetch top-level comments: `gh pr view <number> --comments`
1. Fetch review threads (inline comments): `gh api repos/{owner}/{repo}/pulls/<number>/reviews` and
   `gh api repos/{owner}/{repo}/pulls/<number>/comments`
1. For each existing comment thread:
   - Check if it was addressed by a subsequent commit (compare comment timestamp to later commit
     timestamps, read the relevant code to see if the feedback was incorporated)
   - Check if the author replied explaining why they disagree or won't change it
   - Classify as: resolved, unresolved, or acknowledged-but-declined
1. Note any unresolved feedback for inclusion in the review output

### Step 4: Read changed files in full

For each file in the diff:

1. Read the entire current file (not just the diff hunks) to understand surrounding context
1. Pay attention to:
   - Functions/methods that contain the changed lines — read the full function
   - Imports and dependencies added or removed
   - Class/module structure the change fits into
   - Tests that cover the changed code (find and read them)

### Step 5: Investigate correctness

For each substantive change, verify the approach against the codebase:

1. **Models and schemas** — read model definitions, relationship configurations, column types,
   constraints. Confirm the PR's usage matches the actual schema.
1. **Existing patterns** — search for similar patterns in the codebase. Is the PR following
   established conventions or diverging? If diverging, is it intentional and better?
1. **Call sites** — find where modified functions/methods are called. Will the change break callers?
   Are there callers the PR missed?
1. **Enum values and constants** — verify that referenced values actually exist in the enum/constant
   definitions
1. **Type contracts** — check that function signatures, return types, and parameter types are
   consistent across the change

### Step 6: Evaluate performance and data access

For changes that introduce or modify queries/data fetches:

1. Is the new query justified, or could it piggyback on data already loaded by an existing query?
1. Are there N+1 risks in loops or list endpoints?
1. Does the change add indexes or will it need them at scale?
1. For list vs detail endpoints — do both paths produce equivalent results for shared fields?
1. Check the project's analysis docs (`analysis/*.md`) for recent performance work or architectural
   direction that informs whether this change fits the established trajectory

### Step 7: Check for consistency and completeness

1. **Behavioral consistency** — does the same logic in different code paths (Python vs SQL, list
   endpoint vs detail endpoint, serializer vs service) produce equivalent results?
1. **Type annotations** — are new/modified functions fully annotated? Do annotations match actual
   return values?
1. **Test coverage** — are there tests for the new behavior? Do tests cover edge cases (empty
   inputs, null values, error conditions)?
1. **Error handling** — are failure modes handled? Do errors propagate correctly?
1. **Documentation** — do docstrings/comments need updating for changed behavior?

### Step 8: Verify findings before reporting

**Critical step — do not skip.**

Before including any finding in the review:

1. Re-read the relevant code to confirm the issue actually exists
1. Check that you're not misreading the diff (e.g., a concern about missing code that the PR
   actually adds in a different file)
1. For multi-file changes, verify that file A's concern isn't resolved by file B's change
1. Withdraw concerns that don't hold up under scrutiny — never report unverified speculation

### Step 9: Structure the review output

Use this template for the full review. Findings within each severity section use the
`[TAG] file:line — description` format from `code-review-conventions` steering.

```markdown
## Unresolved Prior Feedback

(Include only if Step 3 found unresolved items. Omit this section if all prior feedback is resolved
or if there are no prior reviews.)

- [comment author]: [summary of unresolved point] — [status: not addressed / partially addressed]

## Blockers

(State explicitly if there are none: "No blockers identified.")

[BLOCKER] file:line — description

## Suggestions

[SUGGESTION] file:line — description

## Nits

[NIT] file:line — description

## What's Done Well

(Call out good patterns, smart tradeoffs, correct design decisions, or improvements over prior code.)

- description of positive aspect

## Summary

[merge-ready | needs changes | needs discussion] — [1-2 sentence summary of overall assessment]
```

### Step 10: Restore original branch

If the PR branch was checked out in Step 2:

1. Return to the original branch: `git switch <original-branch>`
1. If switch fails (e.g., user made changes during review), note: "Could not restore original branch
   — you are still on `<pr-branch>`. Run `git switch <original-branch>` when ready."

## Guidance

### Calibrating review depth

- **Small PRs (1-3 files, < 100 lines):** Full workflow, every step. These are quick and benefit
  from thoroughness.
- **Medium PRs (4-10 files, 100-500 lines):** Full workflow. Focus Step 5 investigation on the most
  complex or risky changes.
- **Large PRs (10+ files, 500+ lines):** Full workflow, but note in the review if the PR should be
  split. Focus investigation on architectural changes and public API surfaces.

### When to search analysis docs

Search `analysis/*.md` or project documentation when:

- The PR touches performance-sensitive code (queries, caching, serialization)
- The PR introduces a new pattern or architectural approach
- The PR modifies code that was recently refactored (check git log for the files)
- You need to understand why existing code is structured a certain way

### Diff-only mode limitations

When proceeding without branch checkout, be explicit about reduced confidence:

- Prefix uncertain findings with "Based on the diff alone..."
- Don't raise concerns about surrounding context you couldn't verify
- Focus on what's visible in the diff: logic errors, missing error handling, test gaps
- Skip Step 5 investigations that require reading non-changed files (or note you couldn't verify)
