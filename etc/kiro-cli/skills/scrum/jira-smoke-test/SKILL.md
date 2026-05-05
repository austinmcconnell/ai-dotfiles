---
name: jira-smoke-test
description: Validate Jira API connectivity, discover instance-specific values (statuses, fields, link types), and verify JQL patterns work. Use when setting up jira agent, after MCP server upgrades, when starting a new project, or when queries return unexpected results.
---

# Jira Smoke Test

Validate that the jira agent's documented API paths and JQL patterns work against the actual Jira
instance. Produces a summary of discovered instance-specific values.

## When to Run

- First time using the jira agent in a project
- After upgrading `@aashari/mcp-server-atlassian-jira`
- When JQL queries return empty or unexpected results
- When starting work in a new Jira project
- When workflow states or custom fields may have changed

## Smoke Test Procedure

Run each step in order. Stop and report if any step fails with an auth or permission error.

### Step 1 — Connectivity

Verify basic API access:

```text
jira_get → /rest/api/3/myself
```

Confirm: response includes the authenticated user's email and display name.

### Step 2 — Discover Projects

```text
jira_get → /rest/api/3/project/search
```

Record: project keys and names. Ask the user which project to validate against if multiple exist.

### Step 3 — Discover Statuses

```text
jira_get → /rest/api/3/status
```

Record: all status names and their categories (To Do, In Progress, Done). Flag any statuses
referenced in `jira-operations-reference.md` JQL patterns that don't exist in this instance.

### Step 4 — Discover Issue Types

```text
jira_get → /rest/api/3/issuetype
```

Record: available issue types (Story, Bug, Task, Epic, etc.).

### Step 5 — Discover Priorities

```text
jira_get → /rest/api/3/priority
```

Record: priority names and IDs.

### Step 6 — Discover Link Types

```text
jira_get → /rest/api/3/issueLinkType
```

Record: available link type names (Blocks, Relates, Duplicate, etc.).

### Step 7 — Discover Custom Fields (Story Points)

```text
jira_get → /rest/api/3/field
```

Search for fields with names containing "story point", "story_point", or "estimation". Record the
custom field ID (e.g., `customfield_10016`).

### Step 8 — Validate Sprint JQL

Run against the target project:

```text
jira_get → /rest/api/3/search/jql
  queryParams: {"jql": "project = {KEY} AND sprint in openSprints()", "maxResults": "5"}
```

Confirm: returns issues (or empty if no active sprint — note this). If it errors, the project may
not use a Scrum board.

### Step 9 — Validate Transition Fetch

Pick any issue from Step 8 (or search for one):

```text
jira_get → /rest/api/3/issue/{key}/transitions
```

Confirm: returns a list of available transitions with IDs and names.

### Step 10 — Validate Backlog Query

```text
jira_get → /rest/api/3/search/jql
  queryParams: {"jql": "project = {KEY} AND status = \"Backlog\" AND type = Story", "maxResults": "5"}
```

If "Backlog" status doesn't exist (from Step 3), substitute the actual To Do/backlog status name.

## Output Format

Present results as a summary the user can review:

```text
## Jira Instance Validation — {date}

### Connection
- User: {displayName} ({email})
- Site: {site}.atlassian.net

### Project: {KEY} — {name}

### Statuses
| Name | Category |
| ---- | -------- |
| ...  | ...      |

### Issue Types
{list}

### Priorities
{list}

### Link Types
{list}

### Custom Fields
- Story Points: {customfield_XXXXX}

### JQL Validation
| Pattern | Result |
| ------- | ------ |
| Sprint in openSprints() | ✅ {n} issues / ⚠️ empty / ❌ error |
| Backlog query | ✅ / ❌ |
| Transitions fetch | ✅ / ❌ |

### Recommendations
- {any status name mismatches to fix in reference docs}
- {any missing custom field IDs to document}
```

## After Validation

If the smoke test reveals instance-specific values that differ from the reference doc placeholders
(e.g., story points field is `customfield_10016`, backlog status is "To Do" not "Backlog"), inform
the user and suggest updating the `jira-operations-reference.md` JQL patterns accordingly.
