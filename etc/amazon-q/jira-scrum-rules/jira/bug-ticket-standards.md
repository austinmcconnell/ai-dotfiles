# Bug Ticket Standards and Best Practices

## Bug Ticket Structure

### Required Sections

#### Summary

- Clear, concise description of the bug
- Include the main impact or affected functionality
- Avoid technical jargon in the summary

#### Description

Structure the description with these subsections:

##### Background

- Context about the system and expected behavior
- Brief explanation of what should be happening

##### Root Cause

- Specific file, line number, or component causing the issue
- Technical details about the actual problem
- Code snippets showing the issue when relevant

##### Current Impact

- Organize into logical categories:
  - **Data Consistency Issues**: Problems with data integrity or storage
  - **Affected Functionality**: Features or processes that don't work correctly
- Use bullet points with specific, measurable impacts
- Include actual numbers when available (database counts, affected records, etc.)

##### Evidence

- Database queries and their results
- Log entries or error messages
- Screenshots or other supporting materials
- Actual data showing the problem

#### Acceptance Criteria

- Focus on observable outcomes, not implementation steps
- What should work correctly after the fix
- How to verify the fix is working
- Keep criteria testable and measurable

### Sections to Avoid Unless Specifically Requested

- **Issue Type** and **Priority** (these are set in JIRA interface)
- **Labels** (unless user specifically asks for them)
- **What Still Works** (usually not relevant for bug reports)
- **Implementation steps** in Acceptance Criteria
- **Generic sections** like "Logging and Observability"

## Language Guidelines

### Be Precise About Data Issues

❌ **Avoid alarming language:**

- "data loss"
- "potential data loss"
- "data corruption"

✅ **Use precise language:**

- "data processing issues"
- "derived field not populated"
- "data consistency issues"
- "incomplete data aggregation"

### Distinguish Between Data Loss vs Processing Issues

**Actual Data Loss**: Original data is deleted or corrupted and cannot be recovered
**Data Processing Issues**: Original data exists but derived/computed fields are incorrect

Most bugs are processing issues, not actual data loss.

### Use Specific Numbers

❌ **Vague**: "Many assessment screens are affected"
✅ **Specific**: "28,067 assessment screens in production database have empty identified_needs arrays"

## Evidence Best Practices

### Database Queries

- Show the actual SQL query used
- Include the results/output
- Explain what the results mean
- Use production data when possible (with appropriate permissions)

### Code References

- Include specific file paths and line numbers
- Show the problematic code
- Show what the code should be (when obvious)
- Use code blocks for formatting

## Common Bug Ticket Anti-Patterns

### Over-Engineering

- Adding unnecessary sections that don't apply to bugs
- Including implementation details in Acceptance Criteria
- Adding generic requirements that apply to all tickets

### Under-Specification

- Vague impact descriptions
- Missing evidence or supporting data
- Unclear acceptance criteria

### Alarming Language

- Using "data loss" when no data is actually lost
- Overstating the severity or impact
- Using technical jargon that confuses stakeholders

## Bug Ticket Review Checklist

- [ ] Summary is clear and non-technical
- [ ] Background explains the expected vs actual behavior
- [ ] Root cause is specific with file/line references
- [ ] Impact is organized into logical categories
- [ ] Numbers and evidence are specific and accurate
- [ ] Language is precise (not alarming when unnecessary)
- [ ] Acceptance criteria focus on outcomes, not implementation
- [ ] No unnecessary sections included
- [ ] Evidence includes actual queries/data when available

## Example Bug Ticket Structure

```markdown
## Summary
Fix typo preventing user data from being processed correctly

## Description

### Background
The system should process all user preferences and store them in the derived preferences table for quick lookup.

### Root Cause
**File**: `app/users/service.py`
**Line**: 245
**Issue**: Typo in condition check

    # Current (incorrect)
    if user.type == 'premum':  # ← Missing 'i' in 'premium'

### Current Impact

**Data Consistency Issues**
• 15,432 premium users have empty preferences arrays
• Individual preference answers stored correctly in raw answers table
• Derived preferences field remains unpopulated

**Affected Functionality**
• User dashboard shows default preferences instead of saved ones
• Recommendation engine uses fallback logic
• Premium feature toggles not working correctly

### Evidence

Production database query:

    SELECT COUNT(*) as total_premium,
           COUNT(CASE WHEN preferences IS NOT NULL THEN 1 END) as with_preferences
    FROM users WHERE type = 'premium';
    -- Result: 15,432 total premium users, 0 with populated preferences

## Acceptance Criteria

• New premium users have preferences populated correctly
• User dashboard displays saved preferences
• Recommendation engine uses actual user preferences
• Premium feature toggles work based on user settings
```
