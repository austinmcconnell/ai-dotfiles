# System-Behavior Story Guidance

Guidance for writing a Story whose change is to internal system behavior (data processing, API
integrations, infrastructure, reliability) rather than a visible UI feature. It is an ordinary Story
using the one Story template — this file covers the judgment specific to system-behavior work.

## Key Principles

### 1. Focus on System Behavior Changes

A system-behavior story should describe **what the system should do differently**, not just what
code to write.

**Good**: "System identifies which organization is referenced in the Observation resources"
**Poor**: "Add a function to extract performer references"

### 2. Provide Context in Background Information

The Background Information section carries the context for a system-behavior story:

- Current system behavior and why it's problematic
- Observable consequences and business impact
- Evidence or analysis supporting the change (kept brief — link out rather than dump)

### 3. Organize Acceptance Criteria Simply

- Use simple bullet points for Acceptance Criteria (not checklists or subsections)
- Add a separate "Technical Implementation" section with bullet points (not checklists) for
  implementation details

### 4. Avoid Over-Engineering

Don't include generic sections unless specifically needed:

- ❌ Logging and Observability
- ❌ Error Handling
- ❌ Performance Requirements
- ❌ Priority Justification
- ❌ Backward Compatibility (unless required by specifications)

### 5. Transform Source Analysis — Don't Mirror It

Follow the "Source material" rule in the `ticket-writing` skill. Only the Story template's sections
belong in the description; everything else from the source is relocated or dropped.

### 6. Use Technical Personas

When the (value-gated) role line is used for system-level changes, use a specific technical role:

- "healthcare data integration specialist"
- "system administrator"
- "API integration developer"
- "data processing engineer"

## Template for System-Behavior Stories

```text
As a [real domain technical persona], I want [system behavior change] so that [business outcome]
instead of [current problematic behavior].
(persona line is value-gated — omit if it adds no scoping information)

Background Information
[Current system behavior, why it's problematic, observable consequences, and business impact]

Acceptance Criteria
• [Primary system behavior change]
• [Secondary system behavior change]

Technical Implementation
• [Specific technical task 1]
• [Specific technical task 2]
```

## Examples of Good System-Behavior Stories

### Data Processing Story

```text
As a healthcare data integration specialist,
I want FHIR bundle processing to use the organization referenced in the observations (primary care provider)
so that screenings are correctly attributed to the appropriate healthcare provider instead of the first organization found.

Background Information
Analysis of real-world SHIN-NY bundles reveals that the current provider lookup logic treats all organizations equally and returns the first match found. The observations in these bundles reference a specific performing organization that should be used as the primary care provider, so attributing to the first match can assign screenings to technology platforms or payers instead of the actual care provider.

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

Background Information
The current authentication API returns generic HTTP 401 responses without specific error details, so client applications cannot distinguish expired tokens, invalid credentials, and account lockouts, and users receive unhelpful errors that don't guide them toward resolution.

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

## When a Story Needs the System-Behavior Treatment

Apply this guidance (technical persona, Technical Implementation section) when the Story is:

- Changing internal system behavior that affects business outcomes
- Fixing technical debt that impacts user experience
- Improving system reliability, performance, or maintainability
- Integrating with external systems or APIs
- Implementing infrastructure changes that enable new features

A Story that adds a user-facing feature, changes the UI/UX, or implements a user-workflow business
rule uses the plain Story template without the Technical Implementation section.

## Review Checklist for System-Behavior Stories

- [ ] **Technical Role**: If the role line is used, it names a specific technical persona, not
  generic "developer"
- [ ] **System Behavior**: Focuses on what the system should do differently
- [ ] **Business Impact**: Clearly explains why the change matters
- [ ] **Background**: Provides context about current problematic behavior
- [ ] **Background Information**: Lists specific, observable problems and their business impact
- [ ] **Clean Acceptance Criteria**: Uses simple bullet points for Acceptance Criteria and separate
  Technical Implementation section
- [ ] **No Over-Engineering**: Avoids unnecessary generic sections
- [ ] **Testable**: Criteria can be verified and demonstrated
- [ ] **Focused**: Single system behavior change, not multiple unrelated changes
