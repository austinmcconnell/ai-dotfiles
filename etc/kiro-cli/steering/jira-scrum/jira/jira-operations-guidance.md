# JIRA Operations Guidance

Safety guardrails and allowed operations for JIRA interactions. For story management, JQL queries,
ceremony integration, and troubleshooting, see the `jira-operations` skill.

## Allowed Operations

### Read

`jira_ls_projects`, `jira_get_project`, `jira_ls_issues`, `jira_get_issue`, `jira_ls_comments`,
`jira_ls_worklogs`, `jira_ls_statuses`, `jira_get_create_meta`

### Create

`jira_create_issue`, `jira_add_comment`, `jira_add_worklog`

### Update

`jira_add_comment`, `jira_add_worklog`, `jira_update_worklog`

## Prohibited Operations

- **Deletion**: `jira_delete_worklog` and any other deletion operations — never delete JIRA data
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
1. Only call `jira_create_issue` after receiving explicit confirmation

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

Extract the issue key from `jira_create_issue` response and construct the browse URL as
`https://uniteus.atlassian.net/browse/{ISSUE-KEY}`.
