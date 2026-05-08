# JIRA Operations Guidance

Safety guardrails for JIRA interactions. For API paths, JQL patterns, story management workflows,
ceremony integration, and troubleshooting, load the `jira-operations` skill.

## Prohibited Operations

- **Deletion**: `jira_delete` is disabled in the MCP server config — never delete JIRA data
- **Destructive modifications**: Changing issue types in ways that lose data, modifying historical
  data, making irreversible changes

## Safety Guardrails

### User Confirmation for Create/Update Operations

1. **Show Preview** of what will be created/changed in markdown
1. **Request Confirmation** before proceeding
1. **Explain Impact** of the operation
1. **Wait for Approval** — never proceed without explicit user approval

### Mandatory Preview Process for Issue Creation

When creating any JIRA issue, the agent MUST:

1. Present the complete issue (summary, description, acceptance criteria) in markdown
1. Ask: "Please review this story and let me know if you'd like any adjustments before I create the
   JIRA ticket"
1. Wait for feedback — do not proceed until user responds
1. Incorporate any requested changes and show the updated version
1. Only call `jira_post` to `/rest/api/3/issue` after receiving explicit confirmation

**There are NO exceptions to this workflow.** Always preview-first for every new issue, regardless
of user experience level or story complexity.

## Pre-Creation Duplicate Check

Before presenting a new ticket preview, search for potential duplicates:

1. Extract 2-4 keywords from the proposed summary
1. Search: `jira_get` → `/rest/api/3/search/jql` with
   `jql=project = {KEY} AND summary ~ "{keywords}" AND status != Done`
1. If matches found, present them (key, summary, status, assignee) and ask: "Should I proceed with
   creation, or does one of these cover it?"
1. Only proceed to the mandatory preview step if user confirms no duplicate

This check applies to all issue types (stories, bugs, tasks). Skip only if the user explicitly says
they already checked.

## Issue Transitions

Moving issues through workflow states uses a two-step process:

1. **Fetch available transitions**: `jira_get` → `/rest/api/3/issue/{key}/transitions`
1. **Present options** to the user — never guess a transition ID
1. **Execute after confirmation**: `jira_post` → `/rest/api/3/issue/{key}/transitions` with body
   `{"transition": {"id": "{transitionId}"}}`

Never hardcode transition IDs — they vary by project workflow. Always fetch first.

## Issue Creation — Field Formatting

The Jira v3 API has specific formatting requirements that cause silent failures or validation errors
if not followed exactly.

### Description Field (Atlassian Document Format)

Descriptions use ADF (Atlassian Document Format), not markdown. A plain text description:

```json
{
  "description": {
    "type": "doc",
    "version": 1,
    "content": [
      {
        "type": "paragraph",
        "content": [{"type": "text", "text": "First paragraph of description."}]
      },
      {
        "type": "paragraph",
        "content": [{"type": "text", "text": "Second paragraph."}]
      }
    ]
  }
}
```

For headings within the description:

```json
{"type": "heading", "attrs": {"level": 3}, "content": [{"type": "text", "text": "Section Title"}]}
```

For bullet lists:

```json
{
  "type": "bulletList",
  "content": [
    {"type": "listItem", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Item 1"}]}]},
    {"type": "listItem", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Item 2"}]}]}
  ]
}
```

**Common mistake:** Passing a plain string as `description` — the API accepts it but renders
nothing. Always use the ADF structure.

### Priority Field

Priority is set by name, not ID. The name must match exactly (including spaces):

```json
{"priority": {"name": "1 - Must Have"}}
```

Valid values for SCRN: `"0 - Critical"`, `"1 - Must Have"`, `"2 - Should Have"`,
`"3 - Nice to Have"`, `"Not Set"`. Note the trailing space in `"Not Set "` that the API sometimes
returns — when setting priority, use `"Not Set"` without trailing space.

**Do not set priority during issue creation.** Priority is set by the Product Owner or Engineering
Manager during triage/refinement. Only include this field if the user explicitly requests a specific
priority.

### Parent (Epic Link)

To assign an issue to an epic, use the `parent` field with the epic's key:

```json
{"parent": {"key": "SCRN-928"}}
```

**Not** `customfield_10014` or `epicLink` — those are deprecated in v3.

### Labels

Labels is a simple string array:

```json
{"labels": ["tech-debt", "accessibility"]}
```

To add a label to an existing issue without removing others, use `jira_put` with the `update` field:

```json
{
  "update": {
    "labels": [{"add": "maybe-delete"}]
  }
}
```

### Story Points

Story points use `customfield_10004` and accept a number:

```json
{"customfield_10004": 5}
```

Only set this for sprint-ready items. Backlog items should not have story points.

## Issue Link Direction

The Jira API for creating issue links uses `outwardIssue` and `inwardIssue` based on the link type's
directional labels. For the "Blocks" link type:

- `outward` label = "blocks"
- `inward` label = "is blocked by"

To create "A blocks B" (B is blocked by A):

```json
{
  "outwardIssue": {"key": "A"},
  "inwardIssue": {"key": "B"},
  "type": {"name": "Blocks"}
}
```

**Memory aid:** `outwardIssue` is the blocker (the one doing the blocking). `inwardIssue` is the
blocked ticket (the one waiting).

When reading links back from the API on a specific issue:

- If the linked issue appears as `outwardIssue`, the queried issue "is blocked by" it
- If the linked issue appears as `inwardIssue`, the queried issue "blocks" it
