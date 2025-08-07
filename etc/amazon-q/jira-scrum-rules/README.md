# JIRA Agent Documentation

This directory contains specialized rules and guidance for the JIRA agent, designed to help with
creating, reviewing, and updating JIRA user stories according to SCRUM best practices.

## Agent Overview

The JIRA agent (`jira`) is a specialized Amazon Q agent that:

- **Reads, Creates, and Updates** JIRA issues (but never deletes)
- Has deep knowledge of SCRUM framework and Agile methodologies
- Understands user story best practices and the INVEST criteria
- Can review and improve existing user stories
- Provides guidance on Sprint ceremonies and backlog management

## Capabilities

### JIRA Operations

- ✅ **Read**: List projects, search issues, get issue details, view comments and worklogs
- ✅ **Create**: Create new user stories, bugs, tasks, and other issue types
- ✅ **Update**: Add comments, log work time, update work logs
- ❌ **Delete**: Cannot delete any JIRA data (safety guardrail)

### SCRUM Knowledge

- Complete understanding of SCRUM framework, roles, and artifacts
- Deep knowledge of Sprint ceremonies (Planning, Daily, Review, Retrospective)
- Expertise in backlog refinement and story estimation
- Understanding of Definition of Ready and Definition of Done

### User Story Expertise

- INVEST criteria validation and improvement
- Story template guidance and examples
- Acceptance criteria best practices
- Story splitting techniques
- Quality review checklists

## How to Use the Agent

### Activating the Agent

```bash
# Use the JIRA agent specifically
q --agent jira "Help me create a user story for user authentication"
```

### Common Use Cases

#### Creating New User Stories

```bash
q --agent jira "Create a user story for allowing customers to reset their passwords"
```

#### Reviewing Existing Stories

```bash
q --agent jira "Review PROJ-123 and suggest improvements based on INVEST criteria"
```

#### Sprint Planning Support

```bash
q --agent jira "Show me all stories ready for sprint planning in project TEAM"
```

#### Backlog Management

```bash
q --agent jira "Help me refine the backlog for the upcoming sprint"
```

## Knowledge Base Structure

### `/scrum/`

- **scrum-framework.md**: Complete SCRUM framework knowledge including roles, artifacts, and
  principles
- **sprint-ceremonies.md**: Detailed guidance on all Sprint ceremonies and best practices

### `/user-stories/`

- **user-story-standards.md**: Comprehensive guide to writing quality user stories using INVEST
  criteria
- **story-review-checklist.md**: Detailed checklist for reviewing and improving user stories
- **story-templates-examples.md**: Templates and real-world examples across different domains

### `/jira/`

- **jira-operations-guidance.md**: Specific guidance for JIRA operations, safety guardrails, and
  best practices

## Key Features

### Safety Guardrails

- **No Deletion**: Agent cannot delete any JIRA data
- **User Confirmation**: Requests confirmation before creating or significantly modifying issues
- **Clear Previews**: Shows what will be created or changed before proceeding
- **Error Handling**: Graceful handling of authentication and permission errors

### Quality Assurance

- **INVEST Validation**: Automatically checks stories against INVEST criteria
- **Template Compliance**: Ensures stories follow proper format and structure
- **Acceptance Criteria Review**: Validates that acceptance criteria are specific and testable
- **Business Value Assessment**: Helps ensure stories deliver clear user value

### SCRUM Integration

- **Ceremony Support**: Provides guidance for all SCRUM ceremonies
- **Backlog Management**: Helps with story prioritization and refinement
- **Sprint Planning**: Assists with story selection and capacity planning
- **Metrics and Reporting**: Can help analyze sprint performance and story quality

## Best Practices

### When Creating Stories

1. **Start with User Need**: Always begin with understanding the user problem
2. **Define Clear Value**: Articulate the business value and user benefit
3. **Write Specific Acceptance Criteria**: Make criteria testable and measurable
4. **Keep Stories Small**: Ensure stories can be completed within one Sprint
5. **Include Edge Cases**: Consider error conditions and boundary scenarios

### When Reviewing Stories

1. **Check INVEST Criteria**: Validate against all six criteria
2. **Review Acceptance Criteria**: Ensure they're complete and testable
3. **Assess Business Value**: Confirm the story delivers meaningful value
4. **Validate Size**: Ensure the story is appropriately sized for the Sprint
5. **Check Dependencies**: Identify and document any dependencies

### When Using JIRA Operations

1. **Verify Context**: Ensure you're working in the correct project
2. **Check Permissions**: Confirm you have appropriate access rights
3. **Preview Changes**: Review what will be created or modified
4. **Document Decisions**: Add comments explaining important changes
5. **Follow Team Conventions**: Use consistent labels, components, and formats

## Integration with Other Tools

### With Default Agent

The JIRA agent inherits global rules from the default agent while adding specialized JIRA and
SCRUM knowledge.

### With Development Workflow

- Integrates with Git operations for linking commits to stories
- Supports time tracking for development work
- Helps maintain traceability between code and requirements

### With Project Management

- Supports sprint planning and backlog management
- Provides metrics and reporting capabilities
- Helps with stakeholder communication through clear story documentation

## Troubleshooting

### Common Issues

- **Authentication Errors**: Ensure JIRA credentials are properly configured
- **Permission Denied**: Verify user has appropriate project permissions
- **Story Creation Failures**: Check required fields and project configuration
- **Search Issues**: Validate JQL syntax and project access

### Getting Help

- Use the agent's sequential thinking capability for complex problems
- Reference the knowledge base documents for detailed guidance
- Check JIRA project settings for field requirements and workflows
- Consult with your Scrum Master or Product Owner for process questions

## Continuous Improvement

The agent's knowledge base can be updated and improved over time:

1. **Add New Templates**: Include domain-specific story templates
2. **Update Best Practices**: Incorporate team-specific conventions
3. **Expand Examples**: Add more real-world story examples
4. **Refine Guidance**: Update based on team feedback and experience

Remember to verify any SCRUM or Agile information against official sources like the Scrum Guide
(scrumguides.org) and adapt the guidance to your team's specific context and needs.
