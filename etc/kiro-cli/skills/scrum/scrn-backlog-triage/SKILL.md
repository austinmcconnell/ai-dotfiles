---
name: scrn-backlog-triage
description: Triage the SCRN Jira backlog by identifying stale items, duplicates, completed work, and misplaced tickets. Use when reviewing the backlog, triaging issues, cleaning up stale tickets, or preparing for refinement.
---

# SCRN Backlog Triage

## When to Use

- Periodic backlog hygiene reviews
- Preparing for refinement or sprint planning
- Identifying items to close, merge, or transfer
- Verifying whether old tickets have already been completed

## Workflow

### 1. Load Context

Read `reports/scrn-backlog-analysis.md` if it exists — it contains the most recent triage findings
and baseline data.

### 2. Gather Data

Query SCRN issues using these JQL patterns (always include `fields` parameter):

```text
# All open issues
project = SCRN AND status not in (Done, Closed) — fields: summary,status,issuetype,labels,updated,created,assignee,priority,customfield_10004

# Stale issues (no update in 90+ days)
project = SCRN AND status not in (Done, Closed) AND updated <= -90d

# Open epics
project = SCRN AND issuetype = Epic AND status not in (Done, Closed)

# Blocked items
project = SCRN AND status = Blocked

# Items stuck in terminal states
project = SCRN AND status = "Approved for Production"
```

### 3. Triage Categories

Work through each category in order:

#### A. Stale Epics

Epics in "Development & Testing" or "Backlog" not updated in 90+ days:

- Check for open children with recent activity
- If no active children → recommend **close**
- If active children exist → recommend **keep** but note the epic status is misleading
- Bucket/umbrella epics ("Tech Debt", "Bug Tracking") → recommend **close** (use labels instead)

#### B. Stale Issues (6+ months no meaningful update)

For each stale issue, apply the four questions:

1. Has anyone asked about this recently? No → recommend `maybe-delete`
1. Does it still align with current product direction? No → recommend `maybe-delete`
1. If we never build this, what happens? Nothing → recommend `maybe-delete`
1. Would we add this today if it weren't already here? No → recommend `maybe-delete`

If the answer to any question is "yes" → recommend **keep** with justification.

#### C. Potentially Completed Work

Issues where the work may have been done under a different ticket or as part of a larger change:

- Look for clues: related epics completed, similar summaries in Done issues, code references
- When suspicious, spawn a `default` subagent to search the codebase (see Code Verification below)
- If evidence confirms completion → recommend **close** with evidence

#### D. Duplicates

Issues with very similar summaries or identical goals:

- Search for near-matches: `project = SCRN AND summary ~ "{keywords}" AND status != Done`
- If duplicate confirmed → recommend closing the newer one, linking to the original

#### E. Blocked Items

Issues in Blocked status:

- Check if the blocker is documented (comments, links)
- If blocker is resolved → recommend **unblock** (transition to Backlog or In Progress)
- If blocker is stale (no update in 60+ days) → recommend `maybe-delete` or close

#### F. Misplaced Items

Issues that belong to another team (ARL → Resources, etc.):

- Recommend adding `maybe-delete` label + comment asking the other team if they want it transferred
- Do NOT transfer or close without human approval

#### G. Items Stuck in Terminal States

Issues in "Approved for Production" or "Ready to Test" for 30+ days:

- If likely deployed → recommend transition to Done
- If unclear → flag for human verification

### 4. Code Verification (Subagent Strategy)

When you suspect a ticket's work has been completed, spawn a `default` subagent to verify:

```text
Prompt: "Search the codebase at ~/projects/unite-us/screenings-ingestion for evidence that
the following work has been completed: [ticket summary + key details]. Look for:
- Related commits (git log --grep)
- Relevant code changes (function names, file patterns)
- Related PR titles or branch names
Check if this work was done as part of a different ticket or initiative.
Report what you find — evidence for or against completion."
```

**When to use code verification:**

- Ticket describes a specific code change (add/remove dependency, refactor, migration)
- Ticket is 6+ months old and the area has been actively developed
- Similar work appears in Done issues under a different name

**When NOT to use:**

- Ticket is about external coordination (reaching out to another team, documentation)
- Ticket is a spike or research task
- Ticket is clearly still relevant (recent comments, active epic)

**Batch subagents** when multiple tickets need verification — group 3-5 related tickets per subagent
to reduce overhead.

### 5. Present Recommendations

Format findings as a structured table grouped by recommended action:

```markdown
## Recommendations

### Close (N items)

| Key | Summary | Reason |
|-----|---------|--------|

### Add `maybe-delete` (N items)

| Key | Summary | Reason |
|-----|---------|--------|

### Transfer to Another Team (N items)

| Key | Summary | Target Team | Reason |
|-----|---------|-------------|--------|

### Keep (N items reviewed, no action needed)

| Key | Summary | Why Keep |
|-----|---------|----------|

### Needs Human Decision (N items)

| Key | Summary | Question |
|-----|---------|----------|
```

### 6. Update Report

`reports/scrn-backlog-analysis.md` is a **living document** reflecting current backlog state — not a
historical log. When updating:

- **Replace** section data with current findings (don't append dated entries)
- **Remove** items that have been resolved since the last triage (closed, merged, transferred)
- **Keep** the executive summary, updating totals and key metrics
- **Add** a `Last triaged: YYYY-MM-DD` line at the top
- **Preserve** the "Skill/Steering Change Proposals" section if it has unactioned items

Jira is the source of truth for history — the report's job is to surface what needs attention now.

## Decision Authority

The agent **can recommend** but **cannot decide**:

- Closing issues
- Setting priority
- Applying PO/EM labels (`2026_roadmap`, `bi-weekly-report`, `accessibility`, `flex-queue`)
- Transferring issues to other teams
- Setting story points

The agent **can apply** (after user approval):

- `maybe-delete` label
- `screenings-v1` label (if clearly V1 work)
- `tech-debt` label (if clearly tech debt)
- `low-context` label (if clearly self-contained)
- `schema-change` label (if involves migrations)
- Comments explaining why an item may be obsolete

## Constraints

- All write operations require user approval (preview → confirm → execute)
- Follow `jira-operations-guidance.md` for API patterns
- Use `scrn-conventions.md` as source of truth for labels, statuses, and fields
- Default project is SCRN unless user specifies otherwise
