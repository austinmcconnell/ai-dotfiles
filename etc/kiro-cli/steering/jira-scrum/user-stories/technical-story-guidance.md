# Technical Story Creation Guidance

## Key Principles for Technical Stories

### 1. Focus on System Behavior Changes

Technical stories should describe **what the system should do differently**, not just what code to
write.

**Good**: "System identifies which organization is referenced in the Observation resources"
**Poor**: "Add a function to extract performer references"

### 2. Provide Context with Background

Always include a "Background" section that explains:

- Current system behavior
- Why it's problematic
- Evidence or analysis supporting the change

### 3. Structure Current Issues Clearly

Use bullet points to list:

- Specific problems with current implementation
- Observable consequences
- Business impact

### 4. Organize Acceptance Criteria Simply

- Use simple bullet points for Acceptance Criteria (not checklists or subsections)
- Add a separate "Technical Implementation" section with bullet points (not checklists) for
  implementation details

### 5. Avoid Over-Engineering

Don't include generic sections unless specifically needed:

- ❌ Logging and Observability
- ❌ Error Handling
- ❌ Performance Requirements
- ❌ Priority Justification
- ❌ Backward Compatibility (unless required by specifications)

### 6. Use Technical Personas

For system-level changes, use specific technical roles:

- "healthcare data integration specialist"
- "system administrator"
- "API integration developer"
- "data processing engineer"

## Template for Technical Stories

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

## Examples of Good Technical Stories

### Data Processing Story

```text
As a healthcare data integration specialist,
I want FHIR bundle processing to use the organization referenced in the observations (primary care provider)
so that screenings are correctly attributed to the appropriate healthcare provider instead of the first organization found.

Background
Analysis of real-world SHIN-NY bundles reveals that the current provider lookup logic treats all organizations equally and returns the first match found. However, the observations in these bundles reference a specific performing organization that should be used as the primary care provider.

Current Issue
• Provider lookup processes organizations sequentially and returns the first match found
• Ignores the fact that observations reference a specific performing organization
• Can result in screenings being attributed to technology platforms or payers instead of the actual care provider

Acceptance Criteria
• **Observation-Referenced Organization**: System identifies which organization is referenced in the Observation resources as the performing organization
• **Primary Provider Selection**: Use the organization referenced in observations as the primary care provider for screening attribution

Technical Implementation
• Organization Reference Extraction: Extract performer references from Observation resources
• Provider Matching: Match the observation-performing organization against the provider database
```

### API Integration Story

```text
As an API integration developer,
I want the authentication service to return structured error responses with specific error codes
so that client applications can handle authentication failures appropriately instead of receiving generic error messages.

Background
Current authentication API returns generic HTTP 401 responses without specific error details, making it difficult for client applications to distinguish between expired tokens, invalid credentials, and account lockouts.

Current Issue
• All authentication failures return the same generic 401 response
• Client applications cannot differentiate between different failure types
• Users receive unhelpful error messages that don't guide them toward resolution

Acceptance Criteria
• **Structured Error Responses**: API returns JSON error responses with specific error codes and messages
• **Error Type Differentiation**: System distinguishes between expired tokens, invalid credentials, and account lockouts

Technical Implementation
• Error Response Schema: Define standardized error response format with code, message, and details fields
• Error Code Mapping: Map internal authentication failures to specific client-facing error codes
```

## Common Mistakes to Avoid

### ❌ Over-Engineering with Unnecessary Sections

```text
Acceptance Criteria

Core Functionality
• [ ] System does X

Technical Implementation
• [ ] Implement Y

Logging and Observability
• [ ] Log all operations
• [ ] Add metrics for monitoring

Error Handling
• [ ] Handle all edge cases
• [ ] Provide graceful degradation

Performance Requirements
• [ ] Response time under 100ms
• [ ] Handle 1000 concurrent requests

Priority Justification
• [ ] HIGH PRIORITY because...
```

### ✅ Focused and Clean

```text
Acceptance Criteria
• System does X with specific behavior change
• System handles Y scenario appropriately

Technical Implementation
• Implement specific technical task 1
• Implement specific technical task 2
```

### ❌ Implementation-Focused User Role

```text
As a developer,
I want to refactor the database schema
so that the code is cleaner.
```

### ✅ Business-Focused Technical Role

```text
As a data processing engineer,
I want the system to use normalized database tables for user preferences
so that preference updates are consistent across all user interfaces instead of requiring updates in multiple places.
```

## When to Use Technical Stories vs User Stories

### Use Technical Stories When

- Changing internal system behavior that affects business outcomes
- Fixing technical debt that impacts user experience
- Improving system reliability, performance, or maintainability
- Integrating with external systems or APIs
- Implementing infrastructure changes that enable new features

### Use Regular User Stories When

- Adding new user-facing features
- Changing user interface or user experience
- Implementing business rules that directly affect user workflows
- Adding user-requested functionality

## Review Checklist for Technical Stories

- [ ] **Technical Role**: Uses specific technical persona, not generic "developer"
- [ ] **System Behavior**: Focuses on what the system should do differently
- [ ] **Business Impact**: Clearly explains why the change matters
- [ ] **Background**: Provides context about current problematic behavior
- [ ] **Current Issues**: Lists specific, observable problems
- [ ] **Clean Acceptance Criteria**: Uses simple bullet points for Acceptance Criteria and separate
      Technical Implementation section
- [ ] **No Over-Engineering**: Avoids unnecessary generic sections
- [ ] **Testable**: Criteria can be verified and demonstrated
- [ ] **Focused**: Single system behavior change, not multiple unrelated changes
