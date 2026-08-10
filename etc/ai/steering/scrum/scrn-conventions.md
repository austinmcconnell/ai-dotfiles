# SCRN Project Conventions

Project-specific context for the Screenings (SCRN) Jira project. This supplements the generic
guidance in `jira-operations-guidance.md`.

For statuses, API body examples, sprint entry criteria, and acceptance criteria templates, load the
`jira-operations` skill. For legacy labels, `maybe-delete` workflow, and epic lifecycle rules, load
the `scrn-backlog-triage` skill. For deployment frontier analysis and testing prioritization, load
the `deployment-readiness` skill.

## Status Workflow

| Jira Status               | Board Column         | Meaning                                          |
| ------------------------- | -------------------- | ------------------------------------------------ |
| `Backlog`                 | Backlog              | Not yet committed to a sprint                    |
| `Ready for Refinement`    | Ready for Refinement | Needs grooming before sprint commitment          |
| `In Progress`             | In Progress          | Actively being developed                         |
| `Code Review`             | Code Review          | PR open, awaiting review                         |
| `Ready to Test`           | Ready to Test        | Code merged to main, needs manual testing        |
| `Approved for Production` | Ready for Deployment | Tested and approved, ready for production deploy |
| `Done`                    | Done                 | Deployed to production and verified              |

**Key distinction**: The Jira API status is `Approved for Production` but the Sprint Board column
displays as **Ready for Deployment**. These are the same state — use the API name in queries.

## Priority Values

SCRN uses a numbered priority scheme:

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

## Labels

### Active Labels (use these)

| Label           | Purpose                                                                |
| --------------- | ---------------------------------------------------------------------- |
| `screenings-v1` | Legacy V1 ingestion pipeline work                                      |
| `tech-debt`     | Technical debt items                                                   |
| `maybe-delete`  | Triage marker — item may be obsolete (see `scrn-backlog-triage` skill) |
| `low-context`   | Self-contained work a new engineer can pick up without deep background |
| `schema-change` | Involves database migrations                                           |

### Labels Set by PO/EM Only (do not apply during creation)

| Label              | Purpose                                         |
| ------------------ | ----------------------------------------------- |
| `2026_roadmap`     | Epics/initiatives on the 2026 roadmap           |
| `bi-weekly-report` | Items included in bi-weekly stakeholder reports |
| `accessibility`    | Accessibility/a11y work                         |
| `flex-queue`       | Available for pickup when capacity allows       |

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

| Field               | Notes                                                                     |
| ------------------- | ------------------------------------------------------------------------- |
| `priority`          | Set by PO/EM during triage — do not set during creation                   |
| `customfield_10004` | Story points — never set or suggest; the team estimates during refinement |

### Unused Fields (never set)

| Field         | Why                                      |
| ------------- | ---------------------------------------- |
| `components`  | Not used in SCRN — all values are empty  |
| `fixVersions` | Not used in SCRN — no release versioning |

## Release Tag Format

Tags trigger deployments via GitHub Actions. The tag pattern determines the target environment.

| Tag Format                    | Environment            | Example       |
| ----------------------------- | ---------------------- | ------------- |
| `X.X.Xalpha` or `X.X.Xalpha2` | n-aaa (pre-production) | `0.0.76alpha` |
| `X.X.Xbeta` or `X.X.Xbeta2`   | training               | `0.0.76beta`  |
| `X.X.X` (numeric only)        | production             | `0.0.76`      |

**Production tag regex**: `^[0-9]+\.[0-9]+\.[0-9]+$`

Source of truth: `.github/workflows/build-and-deploy.yaml` — production deploys when tag does NOT
contain `alpha` and does NOT contain `beta`.
