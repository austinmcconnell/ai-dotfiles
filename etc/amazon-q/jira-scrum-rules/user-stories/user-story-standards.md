# User Story Standards and Best Practices

## User Story Definition

A user story is a short, simple description of a feature told from the perspective of the person
who desires the new capability, usually a user or customer of the system.

## The INVEST Criteria

Every user story should meet the INVEST criteria:

### Independent

- **Definition**: Stories should be independent of each other
- **Why**: Allows for flexible prioritization and reduces dependencies
- **How to Achieve**:
  - Avoid stories that depend on other stories being completed first
  - If dependencies exist, consider combining stories or rewriting them
  - Use techniques like story splitting to reduce dependencies

### Negotiable

- **Definition**: Stories are not detailed contracts; they're placeholders for conversation
- **Why**: Allows for flexibility and collaboration during development
- **How to Achieve**:
  - Keep stories at the right level of detail (not too specific, not too vague)
  - Focus on the "what" and "why," not the "how"
  - Leave room for the development team to determine implementation details

### Valuable

- **Definition**: Each story must deliver value to the user or business
- **Why**: Ensures every piece of work contributes to the product's success
- **How to Achieve**:
  - Clearly articulate the benefit or value in the story
  - Avoid technical stories that don't directly benefit users
  - If technical work is necessary, frame it in terms of user value

### Estimable

- **Definition**: The development team must be able to estimate the story
- **Why**: Enables Sprint Planning and release planning
- **How to Achieve**:
  - Provide enough detail for the team to understand the work
  - Break down large, unclear stories into smaller ones
  - Ensure the team has the necessary domain knowledge

### Small

- **Definition**: Stories should be small enough to complete within a Sprint
- **Why**: Enables faster feedback and reduces risk
- **How to Achieve**:
  - Aim for stories that can be completed in 1-3 days
  - Split large stories using various techniques
  - Consider the team's capacity and Sprint length

### Testable

- **Definition**: Stories must have clear acceptance criteria that can be tested
- **Why**: Ensures the team knows when the story is complete
- **How to Achieve**:
  - Write clear, specific acceptance criteria
  - Include both positive and negative test scenarios
  - Ensure criteria are measurable and verifiable

## User Story Template

### Basic Template

```text
As a [type of user],
I want [some goal]
so that [some reason/benefit].
```text

### Enhanced Template (when appropriate)

```text
As a [type of user],
I want [some goal]
so that [some reason/benefit].

Given [some context/precondition],
When [some action is taken],
Then [some outcome is expected].
```text

## Writing Effective User Stories

### Focus on the User

- **Use personas**: Write stories from the perspective of specific user types
- **Avoid system-centric language**: Focus on user needs, not system features
- **Include the "why"**: Always explain the benefit or value to the user

### Keep It Simple

- **Use plain language**: Avoid technical jargon and complex terminology
- **Be concise**: Keep stories short and focused on a single piece of functionality
- **One story, one feature**: Don't try to pack multiple features into one story

### Make It Conversational

- **Encourage discussion**: Stories should spark conversations between team members
- **Leave room for questions**: Don't over-specify; allow for clarification during development
- **Document assumptions**: Capture important assumptions that come up during discussions

## Acceptance Criteria Best Practices

### Characteristics of Good Acceptance Criteria

- **Specific**: Clearly define what needs to be done
- **Measurable**: Include concrete, testable conditions
- **Achievable**: Realistic given the team's capabilities and constraints
- **Relevant**: Directly related to the user story's goal
- **Time-bound**: Can be completed within the Sprint

### Acceptance Criteria Formats

#### Scenario-Based (Given-When-Then)

```text
Given I am a logged-in user
When I click the "Save" button
Then my changes should be saved
And I should see a confirmation message
```text

#### Rule-Based

```text
- User must be authenticated to access the feature
- Email addresses must be validated before saving
- Error messages must be displayed for invalid inputs
- Success confirmation must be shown after successful submission
```text

#### Checklist Format

```text
- [ ] User can enter their email address
- [ ] System validates email format
- [ ] User receives confirmation email
- [ ] User can click confirmation link to verify account
```text

### Common Acceptance Criteria Patterns

#### Data Validation

- Input field requirements (required, optional, format)
- Data type validation (email, phone, date)
- Length restrictions (minimum, maximum characters)
- Special character handling

#### User Interface Behavior

- Button states (enabled, disabled, loading)
- Form validation and error messaging
- Navigation and page transitions
- Responsive design requirements

#### Business Rules

- Permission and access control
- Workflow states and transitions
- Calculation and processing rules
- Integration with external systems

## Story Splitting Techniques

### When to Split Stories

- Story is too large for one Sprint
- Story has multiple user types or personas
- Story has multiple acceptance criteria that could be independent
- Story has both simple and complex parts

### Splitting Patterns

#### By User Role

Split stories that serve multiple user types:

- Original: "As a user, I want to manage my account settings"
- Split: "As a customer, I want to update my billing information"
- Split: "As an admin, I want to manage user permissions"

#### By Data Variation

Split stories that handle different types of data:

- Original: "As a user, I want to upload files"
- Split: "As a user, I want to upload image files"
- Split: "As a user, I want to upload document files"

#### By Operations (CRUD)

Split stories by Create, Read, Update, Delete operations:

- Original: "As a user, I want to manage my contacts"
- Split: "As a user, I want to add new contacts"
- Split: "As a user, I want to view my contact list"
- Split: "As a user, I want to edit existing contacts"
- Split: "As a user, I want to delete contacts"

#### By Business Rules

Split complex business logic into simpler rules:

- Original: "As a customer, I want to calculate shipping costs"
- Split: "As a customer, I want to see standard shipping costs"
- Split: "As a customer, I want to see expedited shipping costs"
- Split: "As a customer, I want to see international shipping costs"

#### By Interface/Platform

Split stories by different interfaces or platforms:

- Original: "As a user, I want to access my account"
- Split: "As a user, I want to access my account via web browser"
- Split: "As a user, I want to access my account via mobile app"

## Common User Story Anti-Patterns

### Technical Stories

- **Problem**: Stories written from a technical perspective
- **Example**: "As a developer, I want to refactor the database schema"
- **Solution**: Frame in terms of user value or create a technical task

### Too Large (Epics)

- **Problem**: Stories that are too big to complete in one Sprint
- **Example**: "As a user, I want a complete e-commerce system"
- **Solution**: Break down into smaller, more manageable stories

### Too Small (Tasks)

- **Problem**: Stories that are too granular and don't provide user value
- **Example**: "As a user, I want a red submit button"
- **Solution**: Combine with related functionality or make it a task

### Compound Stories

- **Problem**: Stories that try to accomplish multiple things
- **Example**: "As a user, I want to login and reset my password and update my profile"
- **Solution**: Split into separate stories for each distinct piece of functionality

### Implementation-Focused

- **Problem**: Stories that specify how something should be built
- **Example**: "As a user, I want a dropdown menu with AJAX functionality"
- **Solution**: Focus on the user need, not the implementation approach

## Story Estimation Guidelines

### Factors to Consider

- **Complexity**: How difficult is the work?
- **Effort**: How much work is required?
- **Uncertainty**: How much is unknown about the requirements or implementation?
- **Dependencies**: What other work must be completed first?

### Estimation Best Practices

- **Use relative sizing**: Compare stories to each other, not absolute time
- **Include the whole team**: Get input from all team members
- **Re-estimate when needed**: Update estimates as more information becomes available
- **Track velocity**: Use historical data to improve future estimates

### Common Estimation Scales

- **Fibonacci**: 1, 2, 3, 5, 8, 13, 21 (forces meaningful distinctions)
- **T-Shirt Sizes**: XS, S, M, L, XL (good for initial rough sizing)
- **Powers of 2**: 1, 2, 4, 8, 16 (simple doubling progression)

## Definition of Ready

Before a user story can be brought into a Sprint, it should meet the Definition of Ready:

### Common Ready Criteria

- Story follows the standard template format
- Acceptance criteria are clearly defined
- Story has been estimated by the team
- Dependencies have been identified and resolved
- Story is small enough to complete within one Sprint
- Product Owner is available to answer questions
- Any necessary mockups or designs are available

### Benefits of Definition of Ready

- Reduces Sprint Planning time
- Improves Sprint predictability
- Ensures team has necessary information to start work
- Prevents incomplete stories from entering Sprints
