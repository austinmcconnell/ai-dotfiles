# User Story Review Checklist

Use this checklist when reviewing user stories to ensure they meet quality standards and SCRUM best
practices.

## Story Structure Review

### Basic Template Compliance

- [ ] **User Role**: Story clearly identifies the type of user (persona)
- [ ] **Goal/Want**: Story clearly states what the user wants to accomplish
- [ ] **Benefit/Value**: Story explains why the user wants this (the value/benefit)
- [ ] **Language**: Story uses plain, non-technical language that stakeholders can understand

### Template Quality

- [ ] **Specific User Type**: Uses specific personas rather than generic "user"
- [ ] **Single Focus**: Story focuses on one specific goal or need
- [ ] **User-Centric**: Written from user's perspective, not system's perspective
- [ ] **Conversational**: Reads naturally and encourages discussion

## INVEST Criteria Compliance

### Independent

- [ ] **No Dependencies**: Story can be developed without waiting for other stories
- [ ] **Flexible Ordering**: Story can be prioritized independently of other stories
- [ ] **Self-Contained**: Story includes all necessary context and information

### Negotiable

- [ ] **Right Level of Detail**: Not too specific (leaves room for implementation decisions)
- [ ] **Not a Contract**: Serves as a conversation starter, not a detailed specification
- [ ] **Implementation Flexible**: Doesn't dictate how the solution should be built

### Valuable

- [ ] **Clear Business Value**: Obvious benefit to user or business
- [ ] **User-Focused**: Delivers value to end users, not just internal stakeholders
- [ ] **Measurable Impact**: Value can be measured or observed

### Estimable

- [ ] **Sufficient Detail**: Team has enough information to estimate effort
- [ ] **Clear Scope**: Boundaries of the work are well-defined
- [ ] **Known Technology**: Team understands the technical approach needed
- [ ] **Available Expertise**: Team has necessary skills or can acquire them

### Small

- [ ] **Sprint-Sized**: Can be completed within one Sprint
- [ ] **1-3 Days Work**: Typically represents 1-3 days of development effort
- [ ] **Not an Epic**: Doesn't require breaking down into smaller stories
- [ ] **Focused Scope**: Addresses a single piece of functionality

### Testable

- [ ] **Clear Acceptance Criteria**: Specific, measurable criteria for completion
- [ ] **Verifiable**: Can be tested to confirm completion
- [ ] **Observable**: Results can be seen and validated by Product Owner

## Acceptance Criteria Review

### Completeness

- [ ] **All Scenarios Covered**: Includes happy path, edge cases, and error conditions
- [ ] **Positive and Negative Cases**: Covers both what should happen and what shouldn't
- [ ] **Data Validation**: Includes input validation and error handling requirements
- [ ] **User Interface**: Covers UI behavior, messages, and interactions

### Quality

- [ ] **Specific and Measurable**: Criteria are concrete and testable
- [ ] **Unambiguous**: Clear meaning with no room for misinterpretation
- [ ] **Achievable**: Realistic given technical constraints and timeline
- [ ] **Relevant**: Directly related to the story's goal

### Format

- [ ] **Consistent Format**: Uses team's standard format (Given-When-Then, checklist, etc.)
- [ ] **Proper Grammar**: Well-written and professional
- [ ] **Logical Order**: Criteria are organized in a logical sequence

## Business Value Assessment

### User Value

- [ ] **Real User Need**: Addresses an actual user problem or desire
- [ ] **User Research**: Based on user feedback, research, or data
- [ ] **Persona Alignment**: Matches the needs of the specified user type
- [ ] **Value Proposition**: Clear statement of what value is delivered

### Business Alignment

- [ ] **Strategic Alignment**: Supports business objectives and strategy
- [ ] **Priority Justification**: Priority level is appropriate for the value delivered
- [ ] **ROI Consideration**: Return on investment is reasonable
- [ ] **Market Relevance**: Addresses current market needs or opportunities

## Technical Considerations

### Feasibility

- [ ] **Technical Feasibility**: Can be implemented with current technology stack
- [ ] **Resource Availability**: Team has necessary skills and tools
- [ ] **Time Constraints**: Can be completed within Sprint timeline
- [ ] **External Dependencies**: Any external dependencies are identified and manageable

### Quality Attributes

- [ ] **Performance**: Performance requirements are specified if relevant
- [ ] **Security**: Security considerations are addressed if applicable
- [ ] **Scalability**: Scalability requirements are considered if needed
- [ ] **Maintainability**: Solution approach supports long-term maintenance

## Definition of Ready Check

### Information Completeness

- [ ] **All Details Available**: No critical information is missing
- [ ] **Questions Answered**: Major questions have been resolved
- [ ] **Assumptions Documented**: Important assumptions are captured
- [ ] **Constraints Identified**: Technical or business constraints are noted

### Team Readiness

- [ ] **Team Understanding**: Development team understands the requirements
- [ ] **Estimation Complete**: Story has been estimated by the team
- [ ] **Capacity Available**: Team has capacity to take on the story
- [ ] **Skills Available**: Team has necessary skills or can acquire them quickly

### Product Owner Readiness

- [ ] **PO Availability**: Product Owner is available to answer questions
- [ ] **Decision Authority**: PO has authority to make necessary decisions
- [ ] **Acceptance Criteria Approved**: PO has approved the acceptance criteria
- [ ] **Priority Confirmed**: Story priority is confirmed and appropriate

## Common Issues to Flag

### Story Problems

- [ ] **Too Large**: Story is too big for one Sprint (epic)
- [ ] **Too Small**: Story doesn't provide meaningful user value (task)
- [ ] **Technical Focus**: Story is written from technical perspective
- [ ] **Multiple Goals**: Story tries to accomplish multiple things
- [ ] **Vague Language**: Story uses unclear or ambiguous language

### Acceptance Criteria Problems

- [ ] **Missing Criteria**: No acceptance criteria provided
- [ ] **Vague Criteria**: Criteria are unclear or unmeasurable
- [ ] **Too Detailed**: Criteria specify implementation details
- [ ] **Incomplete Coverage**: Important scenarios are missing
- [ ] **Conflicting Criteria**: Criteria contradict each other

### Process Problems

- [ ] **Skipped Refinement**: Story hasn't been through backlog refinement
- [ ] **No Estimation**: Story hasn't been estimated by the team
- [ ] **Missing Dependencies**: Dependencies haven't been identified
- [ ] **Outdated Information**: Story contains outdated requirements or assumptions

## Review Actions

### When Story Passes Review

- [ ] **Mark as Ready**: Add to Sprint Backlog or mark as ready for Sprint Planning
- [ ] **Communicate Approval**: Inform team that story is ready for development
- [ ] **Update Status**: Move story to appropriate status in JIRA

### When Story Needs Work

- [ ] **Document Issues**: List specific problems found during review
- [ ] **Assign for Rework**: Return to Product Owner or appropriate team member
- [ ] **Set Expectations**: Communicate timeline for addressing issues
- [ ] **Schedule Follow-up**: Plan when to re-review the story

### When Story Should Be Split

- [ ] **Identify Split Points**: Suggest how the story could be broken down
- [ ] **Maintain Value**: Ensure each split story delivers user value
- [ ] **Preserve Dependencies**: Consider dependencies when splitting
- [ ] **Update Estimates**: Re-estimate split stories

## Quality Metrics

Track these metrics to improve story quality over time:

### Story Quality Metrics

- **Ready Rate**: Percentage of stories that pass Definition of Ready on first review
- **Rework Rate**: Percentage of stories that require significant changes during Sprint
- **Completion Rate**: Percentage of stories completed within Sprint
- **Acceptance Rate**: Percentage of stories accepted by Product Owner without rework

### Process Metrics

- **Review Time**: Average time spent reviewing stories
- **Cycle Time**: Time from story creation to completion
- **Defect Rate**: Number of defects found in completed stories
- **Stakeholder Satisfaction**: Feedback from users and stakeholders on delivered features
