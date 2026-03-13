# [Feature/Fix Name]

**Type:** Security Fix | Refactor | Migration | Bug Fix
**Priority:** Critical | High | Medium | Low
**Estimated Effort:** [X hours/days]
**Prerequisites:** [Required knowledge, tools, or setup]

## Problem Statement

[What is broken, vulnerable, or needs changing? Why does this matter? What happens if not fixed?]

**Impact:** [Severity and scope]
**References:** [OWASP, CWE, tickets, docs]

## Feasibility Analysis

**Complexity:** Low | Medium | High
**Breaking Changes:** None | Minimal | Significant
**Dependencies:** [What needs to be installed/configured]

**Challenges:**
1. [Challenge 1]
2. [Challenge 2]

**Solutions Available:**
- Option A: [Description with trade-offs]
- Option B: [Description with trade-offs]

**Recommended Approach:** [Which option and why]

## Current State (Before)

[Describe the current problematic behavior or code]

```python
# Show current code that needs fixing
def problematic_function(user_input):
    # Problematic implementation
    pass
```

**Issues:**
- [Specific problem 1]
- [Specific problem 2]

**Root Cause:** [Why does this problem exist?]

## Desired State (After)

[Describe the fixed behavior or code]

```python
# Show fixed code
def fixed_function(user_input):
    # Secure/improved implementation
    pass
```

**Improvements:**
- [Specific fix 1]
- [Specific fix 2]

## Implementation Steps

### Step 1: [Action Description]

**File:** `path/to/file.py`
**Lines:** [line numbers if modifying]
**Action:** [Create | Modify | Delete]

```python
# Complete code to add or modify
# Include all necessary imports
# Add comments explaining key changes
```

**Why:** [Rationale for this change]

### Step 2: [Action Description]

**File:** `path/to/another_file.py`
**Action:** [Create | Modify | Delete]

```python
# Code changes
```

**Why:** [Rationale]

### Step 3: [Action Description]

**Command:** `command to run`
**Purpose:** [What this accomplishes]

```bash
# Example commands
pip install new-dependency
python manage.py migrate
```

## Testing Instructions

### Unit Tests

**File:** `tests/test_feature.py`

```python
# Complete test code
import pytest

def test_fix_works():
    """Verify the fix resolves the issue."""
    # Test implementation
    assert expected_behavior
```

### Integration Tests

**File:** `tests/integration/test_feature_integration.py`

```python
# Integration test code
def test_end_to_end_flow(client):
    # Test the complete flow
    pass
```

### Manual Testing Steps

1. [Step 1 with expected outcome]
2. [Step 2 with expected outcome]
3. [Step 3 with expected outcome]

**Expected Results:**
- [Specific observable outcome 1]
- [Specific observable outcome 2]

## Files to Modify

1. **NEW:** `path/to/new_file.py` - Description
2. **MODIFY:** `path/to/existing_file.py` - What changes
3. **DELETE:** `path/to/old_file.py` - Why removing

## Verification Steps

1. Run unit tests: `pytest tests/test_feature.py`
2. Run integration tests: `pytest tests/integration/`
3. Manual testing:
   - [Specific test case 1]
   - [Specific test case 2]
4. Verify no regressions:
   - [Check related functionality]
5. Performance check (if applicable):
   - [Measure before/after]

**Success Criteria:**
- [ ] All tests pass
- [ ] Manual testing confirms fix
- [ ] No regressions detected
- [ ] Performance acceptable

## Rollback Plan

**If something goes wrong:**

1. [Step to revert change 1]
2. [Step to revert change 2]
3. [Command to rollback database if needed]

**Verification after rollback:**
- [How to confirm system is back to previous state]

## References

- [Standard/Documentation 1]
- [Standard/Documentation 2]
- [Tool/Library Documentation]
