# Branch Inventory

Analyze all local branches in this repository and provide a comprehensive inventory with
actionable recommendations for each branch.

## Data Collection

Run the following commands to gather branch data:

```bash
# List all local branches
git branch

# For each non-main branch, collect:
# - Commits ahead/behind main
# - Last commit date
# - Commit log since divergence
# - Diff stats (files changed, insertions, deletions)
# - Merge conflict check
for branch in $(git branch --format='%(refname:short)' | grep -v '^main$' | grep -v '^master$'); do
    echo "=== $branch ==="
    ahead=$(git rev-list --count main.."$branch")
    behind=$(git rev-list --count "$branch"..main)
    last_date=$(git log -1 --format="%ai" "$branch")
    echo "Ahead: $ahead | Behind: $behind | Last activity: $last_date"
    git log main.."$branch" --format="%h %s"
    git diff main..."$branch" --stat | tail -5
    echo ""
done
```

Also check for related remote branches that don't have local counterparts:

```bash
# Remote-only branches (no local tracking)
git branch -r --no-merged main | grep -v HEAD
```

## Per-Branch Analysis

For each branch, determine:

1. **Purpose** — What was this branch trying to accomplish? Infer from branch name, commit
   messages, and diff content.
1. **Maturity** — Classify as one of:
   - **Just started** — 1-2 exploratory commits, no clear direction yet
   - **In progress** — Active development with a clear goal, but incomplete
   - **Feature complete** — Work appears done, ready for review/rebase/merge
   - **Stale experiment** — Old branch that was exploring an idea, unclear if still relevant
   - **Abandoned** — Very old, superseded by other work, or no longer applicable
1. **Staleness** — How long since the last commit? How far behind main?
1. **Merge complexity** — Check for textual conflicts. Note if files touched by the branch have
   been heavily modified on main (semantic conflicts even without textual ones).
1. **Value assessment** — Is the work on this branch still useful? Are there individual commits
   worth cherry-picking even if the branch as a whole is abandoned?

## Output Format

### Summary Table

Provide a table with columns: Branch, Commits Ahead, Behind Main, Last Activity, Maturity, Action.

### Detailed Assessment

For each branch, provide a short paragraph covering purpose, current state, and recommendation.

### Prioritized Recommendations

Group branches into:

1. **Merge now** — Feature complete, low risk, minimal rebase effort
1. **Finish and merge** — Close to done, worth completing
1. **Cherry-pick and delete** — Branch is stale but contains useful individual commits
1. **Needs decision** — Requires user input on whether the feature is still wanted
1. **Delete** — Abandoned, superseded, or no longer relevant

For "merge now" and "finish and merge" branches, note the specific steps needed (rebase, resolve
conflicts, update tests, etc.).

### Related Remote Branches

Note any remote-only branches that might be relevant to the inventory.

**Important:** Do not make any changes to branches. This is an analysis-only prompt. Wait for
explicit instructions before rebasing, merging, cherry-picking, or deleting any branches.
