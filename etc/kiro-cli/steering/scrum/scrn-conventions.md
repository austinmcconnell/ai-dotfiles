# SCRN Project Conventions

Project-specific context for the Screenings (SCRN) Jira project. This supplements the generic
guidance in `jira-operations-guidance.md`.

## Priority Values

SCRN uses a numbered priority scheme. When creating issues, set priority based on:

| Priority           | When to Use                                                       |
| ------------------ | ----------------------------------------------------------------- |
| `0 - Critical`     | Production incidents, data integrity issues, blocking other teams |
| `1 - Must Have`    | Current sprint/quarter commitments, compliance requirements       |
| `2 - Should Have`  | Important but not blocking, next-sprint candidates                |
| `3 - Nice to Have` | Enhancements, low-urgency improvements                            |
| `Not Set`          | Default — acceptable for backlog items awaiting triage            |

**Do not set priority during issue creation.** Priority is set by the Product Owner or Engineering
Manager during triage/refinement. Leave it as `Not Set` unless the user explicitly asks for a
specific priority.

## Statuses

### Active Workflow Statuses (for stories/tasks/bugs)

| Status                  | Meaning                                                 |
| ----------------------- | ------------------------------------------------------- |
| Backlog                 | Unrefined or not yet sprint-ready                       |
| In Progress             | Actively being worked                                   |
| Code Review             | PR submitted, awaiting review                           |
| Ready to Test           | Code merged, awaiting QA verification                   |
| Approved for Production | Verified, awaiting deploy                               |
| Done                    | Deployed and verified                                   |
| Closed                  | Resolved without completion (won't do, duplicate, etc.) |
| Blocked                 | Cannot proceed — requires external action               |

### Epic-Only Statuses

| Status                | Meaning                                   |
| --------------------- | ----------------------------------------- |
| Discovery             | Research/requirements phase               |
| Requirements          | Detailed requirements being gathered      |
| Development & Testing | Active development (children in progress) |

**Important:** `Development & Testing` is only meaningful for epics. Never use it for stories,
tasks, or bugs. Many legacy epics are stuck in this status — it does not mean active work is
happening.

### Statuses to Avoid in Queries

- `To Do` — legacy status, equivalent to Backlog. A few old issues use it.
- `Reopened` — not used in SCRN.

## Labels

### Active Labels (use these)

| Label           | Purpose                                                                |
| --------------- | ---------------------------------------------------------------------- |
| `screenings-v1` | Legacy V1 ingestion pipeline work                                      |
| `tech-debt`     | Technical debt items                                                   |
| `maybe-delete`  | Triage marker — item may be obsolete (see workflow below)              |
| `low-context`   | Self-contained work a new engineer can pick up without deep background |
| `schema-change` | Involves database migrations                                           |

### Labels Set by PO/EM Only (do not apply during creation)

| Label              | Purpose                                         |
| ------------------ | ----------------------------------------------- |
| `2026_roadmap`     | Epics/initiatives on the 2026 roadmap           |
| `bi-weekly-report` | Items included in bi-weekly stakeholder reports |
| `accessibility`    | Accessibility/a11y work                         |
| `flex-queue`       | Available for pickup when capacity allows       |

### Legacy Labels (do not use on new issues)

These exist on old issues but should not be applied to new work:

- `NY1115`, `NY1115-PO-Workflow1`, `NY1115-Go-Live`, `NY1115-Phase2`, `NY1115-Test-Case-Bug`,
  `NY1115-E2ETesting` — use epic parent relationships instead
- `roadmap` — superseded by `2026_roadmap`
- `Customer:NY1115`, `Domain:Screenings/Coordination` — cross-project taxonomy, not useful in SCRN
- `CC-UAT`, `Product_Reviewed`, `V5_EA`, `frontend`, `forms` — single-use or too generic

### When Creating Issues

- Only apply labels from the "Active Labels" list above
- Do not invent new labels without user confirmation
- Most issues need zero labels — labels are for cross-cutting concerns, not categorization that
  epics already provide

## Fields

### Required for Issue Creation

| Field       | Notes                     |
| ----------- | ------------------------- |
| `summary`   | Clear, concise title      |
| `issuetype` | Story, Bug, Task, or Epic |
| `project`   | Always `{"key": "SCRN"}`  |

### Recommended (set when available)

| Field         | Notes                                    |
| ------------- | ---------------------------------------- |
| `description` | Full story/bug description in ADF format |
| `parent`      | Epic link — use `{"key": "SCRN-XXX"}`    |
| `labels`      | Only from active list                    |
| `assignee`    | Only if user specifies                   |

### Set Only When Explicitly Asked

| Field               | Notes                                                         |
| ------------------- | ------------------------------------------------------------- |
| `priority`          | Set by PO/EM during triage — do not set during creation       |
| `customfield_10004` | Story points — set by team during refinement, not at creation |

### Unused Fields (never set)

| Field         | Why                                      |
| ------------- | ---------------------------------------- |
| `components`  | Not used in SCRN — all values are empty  |
| `fixVersions` | Not used in SCRN — no release versioning |

## Issue Creation API Body

Minimal valid body for creating a story:

```json
{
  "fields": {
    "project": {"key": "SCRN"},
    "issuetype": {"name": "Story"},
    "summary": "Clear summary here",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [...]
    }
  }
}
```

With optional fields:

```json
{
  "fields": {
    "project": {"key": "SCRN"},
    "issuetype": {"name": "Story"},
    "summary": "Clear summary here",
    "description": {"type": "doc", "version": 1, "content": [...]},
    "parent": {"key": "SCRN-1200"},
    "labels": ["tech-debt"]
  }
}
```

**Do not include** `components`, `fixVersions`, `priority`, or `customfield_10004` (story points)
unless the user explicitly asks.

## The `maybe-delete` Workflow

For issues suspected to be obsolete:

1. Add the `maybe-delete` label
1. Add a comment explaining why it may be obsolete
1. If the issue belongs to another team, ask in the comment whether they want it transferred
1. After 2 weeks with no response, close the issue

## Epic Lifecycle

- Epics should be closed when all child work is Done or the initiative is abandoned
- An epic with no children and no updates in 60+ days should be reviewed for closure
- "Development & Testing" epics that haven't been updated in 90+ days are likely stale — flag them

## Sprint Entry Criteria

Before an issue enters a sprint, it should have:

- Story points estimated
- Acceptance criteria defined (for stories/bugs)
- Assignee identified
- Priority set (not "Not Set")
- No unresolved blockers or open questions
- Fits within a single sprint (if not, split it)

Backlog items are NOT expected to have story points or assignees.

### Acceptance Criteria by Issue Type

- **Stories**: 3–8 testable criteria describing observable user behavior. Use Given/When/Then for
  workflows, bullet points for rules/constraints. Never include implementation details.
- **Bugs**: Describe the corrected behavior (what should happen after the fix), include regression
  guard, specify the environment where the bug occurred.
- **Tasks**: Completion conditions and verification steps (e.g., "CI passes", "health check returns
  200 for 24h").
- **Spikes**: Define the deliverable (document, POC, decision), questions to answer, and timebox. Do
  not estimate spikes with story points — timebox only.
