---
name: user-story-writing
description: >
  Write effective user stories following INVEST principles with acceptance criteria, story points,
  and technical considerations. Use when writing user stories, creating stories, refining backlog
  items, documenting feature requirements, or during sprint planning and backlog refinement.
---

# User Story Writing

## When to Use This Skill

Write user stories for:

- New user-facing features
- User interface or experience changes
- Business rules affecting user workflows
- User-requested functionality
- Backlog refinement and Sprint Planning

Use implementation guides for:

- Security fixes with detailed remediation
- Complex refactoring across many files
- Step-by-step migration procedures

Use specs for:

- Complex features requiring coordination
- Architectural decisions needing documentation
- High-risk or high-impact changes

## Story Structure

### Standard Template

```text
As a [type of user],
I want [some goal]
so that [some reason/benefit].

Acceptance Criteria:
- [Specific, testable criterion 1]
- [Specific, testable criterion 2]
- [Specific, testable criterion 3]
```

### Technical Story Template

```text
As a [specific technical role],
I want [system behavior change]
so that [business outcome] instead of [current problematic behavior].

Background
[Context about current system and why change is needed]

Current Issue
• [Specific problem 1]
• [Specific problem 2]
• [Business impact]

Acceptance Criteria
• [Primary system behavior change]
• [Secondary system behavior change]

Technical Implementation
• [Specific technical task 1]
• [Specific technical task 2]
```

## INVEST Principles

Every story should be:

- **Independent**: Can be developed without dependencies
- **Negotiable**: Leaves room for implementation decisions
- **Valuable**: Delivers clear value to users or business
- **Estimable**: Team can estimate the effort required
- **Small**: Can be completed within one Sprint (1-3 days)
- **Testable**: Has clear, verifiable acceptance criteria

## Writing Guidelines

**Focus on the user:**

- Use specific personas, not generic "user"
- Explain the benefit or value
- Avoid system-centric language

**Keep it simple:**

- Use plain language
- Be concise and focused
- One story, one feature

**Make it testable:**

- Write specific, measurable acceptance criteria
- Include positive and negative scenarios
- Cover edge cases and error conditions

**Technical stories:**

- Use specific technical roles (not "developer")
- Focus on system behavior changes
- Provide background context
- List current issues with business impact
- Keep acceptance criteria clean (no over-engineering)

## Common Patterns

**CRUD Operations:**

- Create: User can add new entities
- Read: User can view entity details
- Update: User can edit entity information
- Delete: User can remove entities

**User workflows:**

- Registration and authentication
- Search and filtering
- Data entry and validation
- Reporting and analytics

**Technical implementations:**

- API integrations
- Data processing improvements
- System behavior changes
- Performance optimizations

## Story Splitting

Split stories when:

- Too large for one Sprint
- Multiple user types involved
- Multiple acceptance criteria that could be independent
- Mix of simple and complex parts

**Splitting techniques:**

- By user role
- By data variation
- By operations (CRUD)
- By business rules
- By interface/platform

## Quality Checklist

Before marking a story ready:

- [ ] Follows standard template format
- [ ] Identifies specific user type/persona
- [ ] States clear goal and benefit
- [ ] Includes specific, testable acceptance criteria
- [ ] Meets all INVEST criteria
- [ ] Can be completed within one Sprint
- [ ] Has been estimated by the team
- [ ] Dependencies identified and resolved

## Reference Documentation

- [references/user-story-standards.md](references/user-story-standards.md) - Complete INVEST criteria and best practices
- [references/technical-story-guidance.md](references/technical-story-guidance.md) - Writing technical implementation stories
- [references/story-templates-examples.md](references/story-templates-examples.md) - Real-world examples across domains
- [references/story-review-checklist.md](references/story-review-checklist.md) - Comprehensive review checklist
