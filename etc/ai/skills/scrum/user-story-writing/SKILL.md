---
name: user-story-writing
description: Write effective user stories following INVEST principles with acceptance criteria, story points, and technical considerations. Use when writing user stories, creating stories, refining backlog items, documenting feature requirements, or during sprint planning and backlog refinement.
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

A Story covers both user-facing features and system-behavior/technical work. Both use the one
template below. See the `ticket-writing` skill for the cross-cutting rules (acceptance-criteria
count, sensitive data, what to omit) that apply to every ticket.

### Story Template

```text
As a [real domain persona], I want [goal] so that [benefit].

Background Information
[2–5 sentences: why this matters, the current behavior, and where it shows up]

Acceptance Criteria
- [Observable, testable criterion]
- [Observable, testable criterion]

Technical Implementation   (optional — for system-behavior stories)
- [Specific technical task]

Out of scope   (optional — one tightly-bounded line)
```

**The persona line is value-gated, not mandatory.** Include "As a… I want… so that…" only when the
role and benefit add real scoping information. Omit it when it would be performative (e.g. "As a
developer, I want cleaner code"). When used, the role must be a real domain persona — e.g.
"screenings developer" or a real end-user role like "care coordinator" — never a generic "developer"
or an invented title.

Add the **Technical Implementation** section only for stories that change system behavior and need
to sketch the how. Keep it to high-level tasks, not a step-by-step plan.

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

## Acceptance Criteria Guidelines

### Count

- **2–4 criteria per story** (an optional 5th when the case genuinely needs it) — fewer means
  under-specified, more means split the story
- Each criterion covers one condition — no compound "and" statements

### Format

- **Given/When/Then** for user workflows with preconditions or multiple paths
- **Bullet points** for validation rules, constraints, and non-functional requirements
- **Hybrid** (recommended): Given/When/Then for the primary flow, bullets for rules/edge cases

### Rules

- Every criterion must be binary pass/fail — no subjective language ("fast", "user-friendly")
- Describe observable behavior, not implementation ("user sees error" not "system throws exception")
- Use specific numbers over adjectives ("under 2 seconds" not "fast")
- Never include implementation details (no "use Redis", "add a LEFT JOIN")
- Never duplicate Definition of Done items (no "tests written", "code reviewed")
- Always cover the unhappy path — errors, empty states, permission denied, invalid input

### Anti-Patterns to Avoid

- Restating the user story as a criterion
- Mixing development tasks with acceptance criteria
- Overly prescriptive UI specs (pixel values, exact colors)
- Missing edge cases (only happy path covered)
- Vague language: "should work correctly", "handles errors gracefully"

### By Issue Type

- **Stories**: Observable user behavior and outcomes (2–4 criteria, optional 5th)
- **Bugs**: Corrected behavior + regression guard + environment context
- **Tasks**: Completion conditions and verification steps
- **Spikes**: Deliverable definition + questions to answer + timebox (no story points)

**System-behavior stories (technical work):**

A Story that changes internal system behavior uses the same Story template, adding the optional
Technical Implementation section. See `references/story-guidance.md` for depth.

- Use a real technical persona in the (value-gated) role line — e.g. "screenings developer", never
  "developer"
- Focus on the system behavior change and its business impact
- Provide background context; keep acceptance criteria clean (no over-engineering)

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

- Read `references/user-story-standards.md` when evaluating story quality or coaching on INVEST
  criteria
- Read `references/story-guidance.md` when writing stories for system behavior changes, API
  integrations, or infrastructure work
- Read `references/story-templates-examples.md` when the user asks for examples or you need a model
  for an unfamiliar domain
- Read `references/story-review-checklist.md` when reviewing or refining existing stories
