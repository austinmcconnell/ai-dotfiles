---
name: deployment-readiness
description: Analyze deployment readiness by cross-referencing git commits since the last production tag with JIRA ticket statuses. Use when asking what can be deployed, checking release readiness, prioritizing manual testing, or preparing for a production release.
---

# Deployment Readiness Analysis

## When to Use

- "What can we deploy to production?"
- "Which tickets need testing before we can release?"
- "What's blocking deployment?"
- Preparing for a production release
- Prioritizing manual testing work

## Project Configuration

These values are project-specific. Update this section when using for a different project.

## Current project: SCRN (screenings-ingestion)

| Parameter                   | Value                                                              |
| --------------------------- | ------------------------------------------------------------------ |
| Repository                  | `~/projects/unite-us/screenings-ingestion`                         |
| Jira project key            | `SCRN`                                                             |
| Ticket ID pattern           | `SCRN-[0-9]+`                                                      |
| Production tag regex        | `^[0-9]+\.[0-9]+\.[0-9]+$`                                         |
| Tag convention              | `X.X.X` = production, `X.X.Xalpha` = n-aaa, `X.X.Xbeta` = training |
| Deploy workflow file        | `.github/workflows/build-and-deploy.yaml`                          |
| Production deploy condition | Tag does NOT contain `alpha` and does NOT contain `beta`           |
| Default branch              | `main`                                                             |
| "Tested/ready" status       | `Approved for Production`                                          |
| "Needs testing" status      | `Ready to Test`                                                    |
| "Not ready" statuses        | `Code Review`, `In Progress`, `Backlog`, `Ready for Refinement`    |
| "Complete" status           | `Done`                                                             |

## Prerequisites

- Working directory must be the project git repository
- Git tags follow the project's release tagging convention
- JIRA tickets are referenced in branch names, PR titles, or commit messages

## Workflow

### Phase 1: Identify Baseline Tag

Determine the most recent production deployment tag using the production tag regex from the project
configuration above.

```bash
git tag --sort=-creatordate | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -1
```

Record this as `$BASELINE_TAG` and note its date:

```bash
git log -1 --format="%ai" $BASELINE_TAG
```

### Phase 2: Extract Commit Chain

Get all merge commits on the default branch since the baseline, oldest first:

```bash
git log $BASELINE_TAG..main --format="%H|%ai|%s" --first-parent --reverse
```

For each commit, extract ticket IDs using the ticket ID pattern from project configuration:

```bash
grep -ioE 'SCRN-[0-9]+'
```

Build an ordered list:

| Position | Date | PR   | Ticket    | Notes      |
| -------- | ---- | ---- | --------- | ---------- |
| 1        | ...  | #NNN | SCRN-XXXX |            |
| 2        | ...  | #NNN | —         | dependabot |

**Rules:**

- One ticket may have multiple commits (note all positions)
- Commits without ticket IDs (dependabot, tooling) are marked "always deployable"
- Deduplicate ticket IDs for the JIRA query but track every commit position

### Phase 3: Map Tickets to Statuses

Query JIRA for all unique tickets in a single call:

```text
jira_get → /rest/api/3/search/jql
  jql: key in (SCRN-1234, SCRN-1235, ...)
  fields: summary,status,assignee
  jq: issues[*].{key: key, summary: fields.summary, status: fields.status.name, assignee: fields.assignee.displayName}
```

Classify each ticket into a deployability tier using the status mappings from project configuration:

| Jira Status               | Deployability   | Meaning                           |
| ------------------------- | --------------- | --------------------------------- |
| `Approved for Production` | ✅ DEPLOYABLE   | Tested, ready for production      |
| `Done`                    | ✅ DEPLOYABLE   | Already deployed/completed        |
| No ticket (dependabot)    | ✅ DEPLOYABLE   | No testing required               |
| `Ready to Test`           | 🟡 BLOCKER      | Code merged, needs manual testing |
| `Code Review`             | 🔴 HARD BLOCKER | Not through development pipeline  |
| `In Progress`             | 🔴 HARD BLOCKER | Still being developed             |
| `Backlog`                 | 🔴 HARD BLOCKER | Not started                       |

### Phase 4: Walk the Chain — Find Deployment Frontier

The **deployment frontier** is the furthest contiguous point from the baseline where ALL commits up
to that point have DEPLOYABLE tickets.

Algorithm:

```text
frontier = 0  (position of last safely-deployable commit)

for each commit i (1..N) in chronological order:
    if ticket_status[i] == DEPLOYABLE:
        if all commits 1..i are DEPLOYABLE:
            frontier = i
    else:
        record commit i as "first blocker"
        break
```

**Key principle**: You cannot skip commits in a linear git history. A single non-deployable commit
blocks everything after it, regardless of those later commits' own statuses.

Present the chain as a table:

| #   | Ticket    | Status                  | Deployable? | Frontier?   |
| --- | --------- | ----------------------- | ----------- | ----------- |
| 1   | SCRN-1411 | Approved for Production | ✅          | ✅ frontier |
| 2   | SCRN-1553 | Ready to Test           | 🟡          | ❌ BLOCKS   |
| 3   | SCRN-1409 | Approved for Production | ✅          | ❌ blocked  |

### Phase 5: Calculate Testing Priority

For each BLOCKER ticket, calculate its **deployment unlock power** — how many additional commits
become deployable if this ticket (and all blockers before it) are approved.

Walk the chain from the first blocker forward:

```text
for each blocker B in chain order:
    assume B is now DEPLOYABLE
    count how many consecutive commits after B are DEPLOYABLE
      (until hitting the next remaining blocker)
    unlock_power[B] = count of commits unlocked (including B itself)
```

Present as a prioritized testing queue:

| Priority | Ticket    | Summary | Unlocks                     | Cumulative Frontier |
| -------- | --------- | ------- | --------------------------- | ------------------- |
| 1        | SCRN-1553 | ...     | +0 (next is also a blocker) | commit #2           |
| 2        | SCRN-1549 | ...     | +0 (next is also a blocker) | commit #3           |
| 3        | SCRN-1554 | ...     | +6 (dependabot + approved)  | commit #10          |

**Identify HARD BLOCKERS separately** — these cannot be resolved by testing alone (need code review,
development, etc.). They represent an absolute wall in the chain.

### Phase 6: Present Summary

Output a final summary with:

1. **Current state**: "X of Y commits are deployable. Frontier is at commit #N ($TICKET)."
1. **Highest-ROI testing batch**: The minimum set of Ready to Test tickets that, if approved,
   maximizes the deployable frontier
1. **Hard blockers**: Any tickets in Code Review or earlier that prevent full-tip deployment
1. **Recommendation**: Whether a partial release is advisable and what it would include

## Output Format

```markdown
## Deployment Readiness: [project] — [date]

**Baseline**: Tag `X.X.X` (deployed YYYY-MM-DD)
**Commits since baseline**: N merge commits (M unique tickets + P dependabot)
**Current frontier**: Commit #X / N (tag `X.X.X` + 1 commit)

### Deployment Frontier

[table from Phase 4]

### Testing Priority Queue

[table from Phase 5]

### Hard Blockers

[list of tickets in Code Review or worse, with explanation of what they block]

### Recommendation

[actionable summary]
```

## Constraints

- This is a **read-only analysis** — do not transition tickets or create tags
- Always use `--first-parent` with git log to follow the merge commit chain on main
- If a ticket has multiple commits, use the **earliest** position for frontier calculation (the
  ticket blocks from its first appearance)
- If no tickets are found in commits (e.g., all dependabot), the entire chain is deployable
