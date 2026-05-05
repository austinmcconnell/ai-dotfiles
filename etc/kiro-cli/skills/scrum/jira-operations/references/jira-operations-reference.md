# JIRA Operations Guidance for SCRUM Agent

This document defines how the JIRA SCRUM agent should interact with JIRA, including allowed
operations, safety guardrails, and best practices for managing user stories and other work items.

## Available Tools (v3.x)

The MCP server (`@aashari/mcp-server-atlassian-jira` v3.x) exposes 5 generic HTTP method tools. Each
tool takes a `path` parameter (the Jira REST API endpoint) and optional `queryParams` or `body`.

| Tool          | HTTP Method | Purpose                    | Approval Required |
| ------------- | ----------- | -------------------------- | ----------------- |
| `jira_get`    | GET         | Read any Jira API endpoint | No (allowedTools) |
| `jira_post`   | POST        | Create resources           | Yes               |
| `jira_put`    | PUT         | Replace resources          | Yes               |
| `jira_patch`  | PATCH       | Partial updates            | Yes               |
| `jira_delete` | DELETE      | Remove resources           | **Blocked**       |

### Common API Paths

**Read (jira_get):**

- `/rest/api/3/project/search` — list projects (paginated)
- `/rest/api/3/project/{key}` — get project details
- `/rest/api/3/search/jql` — search issues with JQL (use `jql` query param)
- `/rest/api/3/issue/{key}` — get issue details
- `/rest/api/3/issue/{key}/comment` — list comments
- `/rest/api/3/issue/{key}/worklog` — list worklogs
- `/rest/api/3/issue/{key}/transitions` — list available transitions
- `/rest/api/3/status` — list all statuses
- `/rest/api/3/issuetype` — list issue types
- `/rest/api/3/priority` — list priorities
- `/rest/api/3/issue/createmeta` — get create metadata

**Create (jira_post):**

- `/rest/api/3/issue` — create issue
- `/rest/api/3/issue/{key}/comment` — add comment
- `/rest/api/3/issue/{key}/worklog` — add worklog
- `/rest/api/3/issue/{key}/transitions` — transition issue (body: `{"transition": {"id": "X"}}`)

**Update (jira_put / jira_patch):**

- `/rest/api/3/issue/{key}` — update issue fields
- `/rest/api/3/issue/{key}/worklog/{id}` — update worklog

### Response Format

Responses use TOON (Token-Oriented Object Notation) by default for 30-60% token savings. Set
`outputFormat: "json"` in tool calls to get standard JSON instead.

## Prohibited Operations

The JIRA SCRUM agent must **NEVER** perform the following:

- **Deletion**: `jira_delete` is disabled in the MCP server config — never delete JIRA data
- **Destructive modifications**: Changing issue types in ways that lose data, modifying historical
  data inappropriately, making changes that cannot be easily reversed

## Safety Guardrails

### Pre-Operation Validation

Before performing any JIRA operation, the agent should:

1. **Verify Operation Type**: Confirm the operation is allowed (read, create, or update only)
1. **Validate Context**: Ensure the operation makes sense in the current context
1. **Check Permissions**: Verify the user has appropriate permissions for the operation
1. **Confirm Intent**: For create/update operations, clearly state what will be done

### User Confirmation for Create/Update Operations

For operations that create or significantly modify JIRA data:

1. **Show Preview**: Display what will be created or changed in markdown format
1. **Request Confirmation**: Ask user to confirm before proceeding
1. **Explain Impact**: Describe what the operation will do
1. **Provide Alternatives**: Suggest alternatives if appropriate
1. **Wait for Approval**: Never proceed with creation without explicit user approval

#### Mandatory Preview Process for Issue Creation

When creating new JIRA issues (stories, bugs, tasks, etc.), the agent MUST:

1. **Present Story in Markdown**: Format the complete story (summary, description, acceptance
   criteria) as readable markdown
1. **Ask for Review**: Explicitly ask "Please review this story and let me know if you'd like any
   adjustments before I create the JIRA ticket"
1. **Wait for Feedback**: Do not proceed until user provides feedback or approval
1. **Incorporate Changes**: Make any requested modifications and show updated version if needed
1. **Create Only After Approval**: Only call `jira_post` to `/rest/api/3/issue` after receiving
   explicit user confirmation

##### Example Interaction Flow

```text
User: "Create a story for implementing user authentication"

Agent: [Develops story content]

Agent: "Here's the proposed JIRA story:

## Summary
Implement User Authentication System

## Description
As a system administrator,
I want to implement secure user authentication
so that only authorized users can access the application.

[... full story content ...]

Please review this story and let me know if you'd like any adjustments before I create the JIRA ticket."

User: "Looks good, create it"

Agent: [Creates JIRA ticket] "✅ Issue Created Successfully - PROJ-123"
```

**Important**: There are NO exceptions to this workflow. Always follow the preview-first process for
every new JIRA issue creation, regardless of user experience level or story complexity.

### Error Handling

- Handle authentication errors gracefully
- Provide clear error messages without exposing sensitive information
- Suggest corrective actions when operations fail
- Log operations for troubleshooting purposes

## Best Practices for User Story Management

### Creating User Stories

#### Pre-Creation Checklist

Before creating a user story, ensure:

- [ ] Story follows INVEST criteria
- [ ] Acceptance criteria are well-defined
- [ ] Story is appropriately sized for a Sprint
- [ ] Business value is clear
- [ ] User persona is specific

#### Story Creation Process

1. **Gather Requirements**: Understand the user need and business value
1. **Write Story**: Use standard template format
1. **Define Acceptance Criteria**: Create specific, testable criteria
1. **Set Appropriate Fields**:
   - Issue Type: Story (or appropriate type)
   - Priority: Based on business value
   - Components: If applicable
   - Labels: For categorization
   - Epic Link: If part of an epic
1. **Review Before Creation**: Validate against quality standards
1. **Create and Confirm**: Create the story and verify it was created correctly

#### Required Fields for Stories

- **Summary**: Clear, concise title
- **Description**: Full user story with acceptance criteria
- **Issue Type**: Story, Bug, Task, etc.
- **Priority**: Based on business value and urgency
- **Reporter**: Usually the Product Owner or person requesting the work
- **Project**: Correct project for the work

#### Optional but Recommended Fields

- **Components**: Relevant system components
- **Labels**: For categorization and filtering
- **Epic Link**: If story is part of an epic
- **Story Points**: Estimation (if team uses story points)
- **Sprint**: If assigning to current sprint

### Updating User Stories

#### When to Update Stories

- Clarifying requirements based on team questions
- Adding missing acceptance criteria
- Updating story based on refinement discussions
- Adding comments with additional context
- Logging work time and progress

#### Update Best Practices

1. **Add Comments for Changes**: Explain why updates were made
1. **Preserve History**: Don't remove important historical information
1. **Notify Stakeholders**: Ensure relevant people are aware of changes
1. **Maintain Consistency**: Keep story format and style consistent
1. **Update Related Items**: Update epics, dependencies, etc. as needed

### Story Review and Improvement

#### Review Process

1. **Check INVEST Criteria**: Ensure story meets all criteria
1. **Validate Acceptance Criteria**: Confirm criteria are testable and complete
1. **Assess Business Value**: Verify value proposition is clear
1. **Review Size**: Ensure story is appropriately sized
1. **Check Dependencies**: Identify and document dependencies
1. **Validate Ready State**: Confirm story meets Definition of Ready

#### Common Improvements

- **Split Large Stories**: Break epics into smaller, manageable stories
- **Clarify Vague Requirements**: Add specific details and examples
- **Improve Acceptance Criteria**: Make criteria more specific and testable
- **Add Missing Context**: Include background information and assumptions
- **Update Outdated Information**: Refresh old or obsolete details

## JQL (JIRA Query Language) Best Practices

### Common Queries for SCRUM Teams

#### Sprint-Related Queries

```jql
# Current sprint stories
project = "PROJ" AND sprint in openSprints() AND type = Story

# Completed stories in current sprint
project = "PROJ" AND sprint in openSprints() AND status = Done AND type = Story

# Stories ready for sprint planning
project = "PROJ" AND status = "Ready for Sprint" AND type = Story
```

#### Backlog Management Queries

```jql
# Product backlog stories
project = "PROJ" AND status = "Backlog" AND type = Story ORDER BY priority DESC

# Stories needing refinement
project = "PROJ" AND (status = "Backlog" OR status = "To Do") AND "Story Points" is EMPTY

# High priority bugs
project = "PROJ" AND type = Bug AND priority in (Highest, High) AND status != Done
```

#### Team Performance Queries

```jql
# Stories completed this month
project = "PROJ" AND type = Story AND status = Done AND resolved >= startOfMonth()

# Stories assigned to specific team member
project = "PROJ" AND assignee = "john.doe" AND status in ("In Progress", "In Review")
```

### Query Optimization

- Use specific project keys to limit scope
- Include relevant issue types to filter results
- Use appropriate date ranges for time-based queries
- Order results by priority or other relevant fields
- Limit results when appropriate to improve performance

## Integration with SCRUM Ceremonies

### Sprint Context Lookup

Use when starting a session or when the user asks about the current sprint:

1. Query active sprint issues: `project = {KEY} AND sprint in openSprints()` with fields
   `summary,status,assignee,priority,issuetype,customfield_XXXXX` (story points)
1. Summarize: total issues, breakdown by status (To Do / In Progress / Done), by assignee
1. Note the sprint goal if available (from board/sprint metadata)

**JQL patterns:**

```jql
# All current sprint work
project = "PROJ" AND sprint in openSprints()

# Current sprint filtered by assignee
project = "PROJ" AND sprint in openSprints() AND assignee = currentUser()

# Flagged/blocked items in sprint
project = "PROJ" AND sprint in openSprints() AND flagged = impediment
```

### Standup Summary

Generate a standup-ready update for a user or team:

1. **Done** (since last standup): `status changed to "Done" after -1d AND sprint in openSprints()`
1. **In Progress**: `status = "In Progress" AND sprint in openSprints()`
1. **Blocked**: `flagged = impediment AND sprint in openSprints()` or issues with "Blocked" status

**Output format:**

```text
## Standup — {date}

### Done (since yesterday)
- PROJ-123: Summary text

### In Progress
- PROJ-456: Summary text (assignee)

### Blocked
- PROJ-789: Summary text — [reason if in comments]
```

Include issue keys as clickable links. Filter by assignee when generating a personal update.

### Sprint Planning Workflow

Support sprint planning by providing velocity and candidate data:

1. **Calculate velocity** — sum story points from last 2-3 completed sprints:
   `project = {KEY} AND sprint in closedSprints() AND status = Done AND resolved >= -30d`
1. **Identify candidates** — refined backlog items with estimates:
   `project = {KEY} AND status = "Ready for Sprint" ORDER BY priority DESC, rank ASC`
1. **Present capacity summary**: average velocity, total candidate points, recommended selection
1. **Help select stories** that fit within velocity, respecting priority order

### Daily Scrum Support

- Query stories in progress
- Check for blocked stories
- Review work log entries
- Identify impediments

### Sprint Review Support

- Query completed stories in sprint
- Gather acceptance criteria for demo
- Check for incomplete work
- Prepare stakeholder updates

### Sprint Retrospective Support

- Analyze sprint metrics (completed vs. planned)
- Review story cycle times
- Identify patterns in story completion
- Track improvement action items

## Reporting and Metrics

### Story Quality Metrics

- Stories meeting Definition of Ready
- Stories completed within sprint
- Stories requiring rework or clarification
- Average story cycle time

### Team Performance Metrics

- Sprint velocity (story points or story count)
- Sprint commitment vs. completion
- Defect rates and resolution times
- Team capacity utilization

### Process Improvement Metrics

- Time spent in each status
- Frequency of story updates and changes
- Stakeholder satisfaction with delivered stories
- Retrospective action item completion

## Troubleshooting Common Issues

### Authentication Problems

- Verify JIRA credentials are configured correctly
- Check if user has appropriate project permissions
- Ensure API tokens are valid and not expired

### Permission Issues

- Confirm user has permission to create issues in the project
- Verify user can edit issues they didn't create
- Check project-specific permission schemes

### Data Validation Errors

- Ensure required fields are populated
- Verify field values match allowed options
- Check for proper issue type configurations
- Validate custom field requirements

### Performance Issues

- Use specific JQL queries to limit results
- Avoid overly broad searches
- Consider pagination for large result sets
- Cache frequently accessed data when appropriate

## Bug Ticket Creation Guidelines

### Structure for Bug Tickets

Bug tickets should follow this structure:

1. **Summary**: Clear, non-technical description
1. **Description** with subsections:
   - Background
   - Root Cause
   - Current Impact
   - Evidence
1. **Acceptance Criteria**: Observable outcomes only

### Language Precision for Data Issues

When describing data-related bugs:

- Distinguish between "data loss" (actual deletion) vs "data processing issues" (incorrect derived
  fields)
- Use specific numbers from database queries when available
- Avoid alarming language unless the situation truly warrants it

### Sections to Exclude by Default

Unless specifically requested, don't include:

- Issue Type/Priority (set in JIRA interface)
- Labels
- "What Still Works" sections
- Implementation steps in Acceptance Criteria

## Response Formatting Guidelines

### JIRA URL Formatting

When reporting JIRA issue creation or referencing existing issues, always use the proper issue key
format in URLs:

#### Correct URL Format

- **Browse URL**: `https://uniteus.atlassian.net/browse/{ISSUE-KEY}`
- **Example**: `https://uniteus.atlassian.net/browse/SCRN-936`

#### Incorrect URL Format

- **Avoid**: Using internal issue IDs in URLs
- **Example**: `https://uniteus.atlassian.net/browse/461282` ❌

#### Implementation Guidelines

When the `jira_post` tool returns response data:

1. **Extract the Issue Key**: Use the returned issue key (e.g., "SCRN-936") for user-facing URLs
1. **Format Browse URL**: Construct the browse URL as
   `https://uniteus.atlassian.net/browse/{ISSUE-KEY}`
1. **Present to User**: Always show the issue key-based URL to users for easy reference

#### Example Success Response Format

```text

✅ Issue Created Successfully

- **Issue Key**: SCRN-936
- **Issue ID**: 461282
- **Jira URL**: [View in Browser](https://uniteus.atlassian.net/browse/SCRN-936)

---
*Issue created at: 2025-08-12 20:26:53 UTC*
```

This ensures users receive clickable, bookmarkable URLs that use the human-readable issue key
format.

This guidance ensures the JIRA SCRUM agent operates safely and effectively while supporting SCRUM
teams in managing their work items and following agile best practices.
