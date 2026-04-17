# Commit Analysis

Analyze the commits on my current branch and identify which ones
should be removed, split into smaller units, have improved commit
messages, or (rarely) consolidated through interactive rebase.

**Guiding Principle**: Optimize for reviewability and git bisect,
not commit count. Granular commits (20-30) are better than
consolidated commits (5-10) if each commit represents a logical,
atomic unit of work. Each commit should be independently reviewable
and revertable.

## Step 1: Initial Analysis

Run these commands to understand the commit structure:

```bash
# Get all commits on this branch

git log --oneline main..HEAD

# Show detailed diff for each commit

for commit in $(git log --oneline main..HEAD | awk '{print $1}'); do
echo "=== $commit ==="
git show --stat $commit
echo ""
done
```

## Step 2: Analyze Each Commit

For each commit, examine:

1. **Commit message quality**: Is it descriptive? Does it explain WHY, not just WHAT?
1. **Scope**: Does it change multiple unrelated things that should be separate commits?
1. **Atomic nature**: Is it a single logical unit of work?
1. **Diff content**: Read the actual code changes to understand what the commit does

## Step 3: Identify All Opportunities

Look for (in priority order):

**A. Commits to Remove** (highest priority):

- **Marked for removal**: Commits with "fixup", "DROP", "WIP", "TEMP", or debug/temporary language
- **Accidental commits**: Debug logging, commented code, temporary testing changes

**B. Split Candidates** (commits to break apart):

- **Multiple concerns**: Commit changes unrelated files/features (e.g., "Add feature X and fix bug Y")
- **Mixed refactoring**: Combines refactoring with new functionality
- **Scope creep**: Commit message says one thing but diff shows additional unrelated changes
- **Large commits**: Changes >300 lines or >8 files in ways that could be separate logical steps
- **Feature + infrastructure**: Mixes feature code with deployment/config changes
- **Security changes bundled together**: Multiple distinct security improvements in one commit

**C. Message Improvement Candidates**:

- **Vague messages**: "Fix bug", "Update code", "Changes", "WIP"
- **Missing context**: Doesn't explain WHY the change was made
- **Inaccurate**: Message doesn't match what the diff actually does
- **Missing details**: For complex changes, should list key changes in bullet points
- **First line too long**: Exceeds 50 characters

**D. Consolidation Candidates** (lowest priority - use sparingly):

- **Bug fixes for bugs introduced in the branch**: Commits that fix
  issues introduced earlier in the same branch (not pre-existing bugs)
- **Accidental splits**: Commits that were accidentally split (e.g., forgot to stage a file)
- **True fixup commits**: Commits explicitly marked as "fixup!" or "squash!"

**Do NOT consolidate:**

- **Security changes**: Keep each security improvement separate for independent review
- **Different concerns**: Even if touching the same files, keep separate if addressing different problems
- **Would create large commits**: If consolidation would create a
  commit >300 lines of changes, keep separate
- **Iterative fixes**: Configuration refinements discovered during deployment/testing should stay separate
- **Feature + infrastructure**: Keep feature code separate from deployment/config changes
- **Same file, different purposes**: Multiple commits touching the same file for different reasons

## Step 4: Present Complete Analysis

First, present a complete overview organized by action type:

### Commits to Remove

List all commits marked for removal with:

- Commit hash and message
- Reason for removal
- Impact on commit count

### Split Recommendations

List all commits that should be split with:

- Current commit message
- Size metrics (lines changed, files affected)
- Proposed split (e.g., "Split into: 1) Refactor X, 2) Add feature Y")
- Rationale for split

### Message Improvements

List all commits needing better messages with:

- Current message
- Analysis of what the diff actually does
- Proposed improved message
- Rationale for improvement

### Consolidation Opportunities (if any)

List any groups with:

- Group title (e.g., "Set 1: Fixup commits (2 commits)")
- Brief rationale
- Warning if consolidation would create a large commit
- Total impact on commit count

### Summary

- Total commits: X
- Commits to remove: N (→ X-N commits)
- Commits to split: Z (→ +W commits)
- Messages to improve: M
- Commits to consolidate: C (→ -C commits)
- **Final count**: Y commits
- **Ask for approval**: "Do you want to proceed with these changes?"
- **Wait for user confirmation** before starting

## Step 5: Work Through Changes Interactively

After receiving approval, work through each change one at a time:

1. **Show the specific change** (consolidation/split/message improvement)
1. **Provide rebase/amend instructions**
1. **Explain the rationale**
1. **Ask for confirmation**: "Ready to proceed with this change?"
1. **Wait for user response** before moving to the next change

## Step 6: Verify Each Change

After each modification:

1. Show the resulting commit(s)
1. Verify the diff matches expectations
1. Check for any unintended side effects

**Important Guidelines:**

- Work through ONE change at a time
- Don't move to the next change until user confirms
- For splits, check which files/lines are changed and if other commits touch the same code
- For consolidations, verify the resulting commit won't exceed 300 lines of changes
- Consider ALL commits on the branch, not just recent ones
- **Prioritize clarity and atomic commits over reducing commit count**
- **Granular commits are better than large consolidated commits**
- Read the actual diff content, not just file names and stats
- Ensure commit messages accurately describe what the code changes do
- Keep security changes separate for independent review
- Keep feature code separate from infrastructure/deployment changes

**Commit Message Best Practices:**

- First line: Imperative mood, \<50 chars, no period (e.g., "Add user authentication")
- Body: Explain WHY, not just WHAT. Include context, trade-offs, alternatives considered
- Reference issues/tickets if applicable
- For complex changes, use bullet points to list key changes

**Split Decision Criteria:**
A commit should be split if:

- It mixes refactoring with new features
- It touches multiple unrelated subsystems
- The commit message uses "and" to describe multiple distinct changes
- It exceeds 300 lines of changes or affects more than 8 files
- It combines feature code with infrastructure/deployment changes
- It bundles multiple security improvements together
- Half the changes could be merged with a different commit
- The diff shows changes that aren't mentioned in the commit message

**Consolidation Decision Criteria:**
Only consolidate commits if:

- They are true fixup/squash commits for the same logical change
- They fix bugs introduced in the same branch (not pre-existing bugs)
- They were accidentally split (e.g., forgot to stage files)
- The resulting commit would be \<300 lines of changes
- They address the exact same concern (not just the same file)
- Consolidation improves clarity (rare)

**Output Format:**
Present each change clearly with:

- Change type (Consolidate/Split/Improve Message)
- Current state
- Proposed state
- Rebase/amend instructions
- Rationale
- Confirmation prompt

Work systematically through all opportunities before moving to execution.
