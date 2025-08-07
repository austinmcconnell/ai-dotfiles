# JIRA Operations Guidance for SCRUM Agent

This document defines how the JIRA SCRUM agent should interact with JIRA, including allowed
operations, safety guardrails, and best practices for managing user stories and other work items.

## Allowed Operations

The JIRA SCRUM agent is authorized to perform the following operations:

### Read Operations

- `jira_ls_projects` - List available projects
- `jira_get_project` - Get detailed project information
- `jira_ls_issues` - Search and list issues using JQL
- `jira_get_issue` - Get detailed issue information
- `jira_ls_comments` - List comments on issues
- `jira_ls_worklogs` - List work logs on issues
- `jira_ls_statuses` - List available statuses
- `jira_get_create_meta` - Get metadata for creating issues

### Create Operations

- `jira_create_issue` - Create new issues (stories, bugs, tasks, etc.)
- `jira_add_comment` - Add comments to existing issues
- `jira_add_worklog` - Add work log entries to issues

### Update Operations

- `jira_add_comment` - Add comments (which can include updates/clarifications)
- `jira_add_worklog` - Log work time
- `jira_update_worklog` - Update existing work log entries

## Prohibited Operations

The JIRA SCRUM agent must **NEVER** perform the following operations:

### Deletion Operations

- `jira_delete_worklog` - Delete work log entries
- Any other deletion operations (even if they become available)
- Permanently removing or destroying any JIRA data

### Destructive Modifications

- Changing issue types in ways that lose data
- Modifying historical data inappropriately
- Making changes that cannot be easily reversed

## Safety Guardrails

### Pre-Operation Validation

Before performing any JIRA operation, the agent should:

1. **Verify Operation Type**: Confirm the operation is allowed (read, create, or update only)
2. **Validate Context**: Ensure the operation makes sense in the current context
3. **Check Permissions**: Verify the user has appropriate permissions for the operation
4. **Confirm Intent**: For create/update operations, clearly state what will be done

### User Confirmation for Destructive Actions

For operations that create or significantly modify JIRA data:

1. **Show Preview**: Display what will be created or changed
2. **Request Confirmation**: Ask user to confirm before proceeding
3. **Explain Impact**: Describe what the operation will do
4. **Provide Alternatives**: Suggest alternatives if appropriate

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
2. **Write Story**: Use standard template format
3. **Define Acceptance Criteria**: Create specific, testable criteria
4. **Set Appropriate Fields**:
   - Issue Type: Story (or appropriate type)
   - Priority: Based on business value
   - Components: If applicable
   - Labels: For categorization
   - Epic Link: If part of an epic
5. **Review Before Creation**: Validate against quality standards
6. **Create and Confirm**: Create the story and verify it was created correctly

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
2. **Preserve History**: Don't remove important historical information
3. **Notify Stakeholders**: Ensure relevant people are aware of changes
4. **Maintain Consistency**: Keep story format and style consistent
5. **Update Related Items**: Update epics, dependencies, etc. as needed

### Story Review and Improvement

#### Review Process

1. **Check INVEST Criteria**: Ensure story meets all criteria
2. **Validate Acceptance Criteria**: Confirm criteria are testable and complete
3. **Assess Business Value**: Verify value proposition is clear
4. **Review Size**: Ensure story is appropriately sized
5. **Check Dependencies**: Identify and document dependencies
6. **Validate Ready State**: Confirm story meets Definition of Ready

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

### Sprint Planning Support

- Query stories ready for sprint planning
- Retrieve story details and acceptance criteria
- Check story estimates and dependencies
- Validate Definition of Ready compliance

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

This guidance ensures the JIRA SCRUM agent operates safely and effectively while supporting SCRUM
teams in managing their work items and following agile best practices.
