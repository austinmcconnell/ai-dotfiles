# JIRA Operations Guidance

Safety guardrails and allowed operations for JIRA interactions. For story management, JQL queries,
ceremony integration, and troubleshooting, see the `jira-operations` skill.

## Available Tools (v3.x)

The MCP server exposes generic HTTP method tools — not operation-specific tools:

| Tool          | HTTP Method | Purpose                    | Approval Required |
| ------------- | ----------- | -------------------------- | ----------------- |
| `jira_get`    | GET         | Read any Jira API endpoint | No (allowedTools) |
| `jira_post`   | POST        | Create resources           | Yes               |
| `jira_put`    | PUT         | Replace resources          | Yes               |
| `jira_patch`  | PATCH       | Partial updates            | Yes               |
| `jira_delete` | DELETE      | Remove resources           | **Blocked**       |

### Common API Paths

**Read (jira_get):**

- `/rest/api/3/project/search` — list projects
- `/rest/api/3/search/jql` — search issues with JQL (use `jql` query param)
- `/rest/api/3/issue/{key}` — get issue details
- `/rest/api/3/issue/{key}/comment` — list comments
- `/rest/api/3/issue/{key}/worklog` — list worklogs
- `/rest/api/3/issue/{key}/transitions` — list available transitions
- `/rest/api/3/status` — list all statuses
- `/rest/api/3/issue/createmeta` — get create metadata

**Create (jira_post):**

- `/rest/api/3/issue` — create issue
- `/rest/api/3/issue/{key}/comment` — add comment
- `/rest/api/3/issue/{key}/worklog` — add worklog
- `/rest/api/3/issue/{key}/transitions` — transition issue

**Update (jira_put / jira_patch):**

- `/rest/api/3/issue/{key}` — update issue fields
- `/rest/api/3/issue/{key}/worklog/{id}` — update worklog

## Prohibited Operations

- **Deletion**: `jira_delete` is disabled in the MCP server config — never delete JIRA data
- **Destructive modifications**: Changing issue types in ways that lose data, modifying historical
  data, making irreversible changes

## Safety Guardrails

### Pre-Operation Validation

Before any JIRA operation: verify it's an allowed operation type, validate context, check
permissions, and for create/update operations clearly state what will be done.

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

### Error Handling

Handle authentication errors gracefully. Provide clear error messages without exposing sensitive
information. Suggest corrective actions when operations fail.

## Bug Ticket Creation Guidelines

### Structure

1. **Summary**: Clear, non-technical description
1. **Description**: Background, Root Cause, Current Impact, Evidence
1. **Acceptance Criteria**: Observable outcomes only

### Language Precision

- Distinguish "data loss" (actual deletion) vs "data processing issues" (incorrect derived fields)
- Use specific numbers from database queries when available
- Avoid alarming language unless truly warranted

### Exclude by Default

Don't include unless requested: Issue Type/Priority, Labels, "What Still Works" sections,
implementation steps in Acceptance Criteria.

## Response Formatting

Always use issue key format in URLs, never internal IDs:

- **Correct**: `https://uniteus.atlassian.net/browse/SCRN-936` ✅
- **Incorrect**: `https://uniteus.atlassian.net/browse/461282` ❌

Extract the issue key from the `jira_post` response and construct the browse URL as
`https://uniteus.atlassian.net/browse/{ISSUE-KEY}`.
