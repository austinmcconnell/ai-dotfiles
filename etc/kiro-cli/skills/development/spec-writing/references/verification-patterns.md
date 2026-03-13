# Verification Patterns

How to verify requirements are met through testing.

## Verification Table Format

```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| [What to verify] | [How to test] | [When it passes] |
```

## Test Methods

### Unit Tests
Test individual functions or components in isolation.

**When to use:**
- Business logic
- Data transformations
- Validation rules
- Edge case handling

**Example:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Highlight metrics > 80% | Unit test | Red color applied when value > 80% |
| Validate email format | Unit test | Rejects invalid emails, accepts valid |
```

### Integration Tests
Test multiple components working together.

**When to use:**
- API endpoints
- Database operations
- Service interactions
- Cache behavior

**Example:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| API returns metrics | Integration test | 200 status, valid JSON schema |
| Cache hit rate | Integration test | > 90% cache hits after warmup |
```

### End-to-End (E2E) Tests
Test complete user workflows through the UI.

**When to use:**
- Critical user paths
- Multi-step workflows
- UI interactions
- Cross-system flows

**Example:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| User can sign in | E2E test | Redirect to dashboard after login |
| Auto-refresh works | E2E test | Metrics update within 6 seconds |
```

### Performance Tests
Test speed, throughput, and resource usage.

**When to use:**
- Response time requirements
- Load handling
- Scalability claims
- Resource limits

**Example:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Dashboard loads < 2s | Performance test | p95 latency < 2000ms |
| Handle 1000 req/sec | Load test | No errors at 1000 RPS |
```

### Manual Tests
Test through human observation and interaction.

**When to use:**
- Visual design verification
- Usability testing
- Complex workflows
- Exploratory testing

**Example:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Error messages are clear | Manual test | User understands what went wrong |
| Mobile responsive | Manual test | Usable on iPhone and Android |
```

## Complete Examples

### API Feature

```markdown
## Verification

| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| GET /api/users returns list | Integration test | 200 status, array of users |
| Pagination works | Integration test | Correct page size and offset |
| Invalid auth returns 401 | Integration test | 401 status, error message |
| Response time < 200ms | Performance test | p95 < 200ms at 100 RPS |
| Handles 500 concurrent users | Load test | No errors, latency < 500ms |
```

### UI Feature

```markdown
## Verification

| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Form validates email | Unit test | Rejects invalid, accepts valid |
| Submit button disabled when invalid | E2E test | Button disabled until form valid |
| Success message shows after submit | E2E test | Green toast appears |
| Form clears after submit | E2E test | All fields reset to empty |
| Mobile responsive | Manual test | Usable on 375px width |
```

### Background Job

```markdown
## Verification

| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Job processes all records | Integration test | All records marked processed |
| Failed records retry 3 times | Integration test | Retry count = 3 before dead letter |
| Job completes in < 5 minutes | Performance test | Duration < 300 seconds |
| Handles 10K records | Load test | No errors, memory < 2GB |
| Dead letter queue works | Integration test | Failed records in DLQ |
```

## Pass Criteria Guidelines

**Be specific:**
- ✅ "p95 latency < 2000ms"
- ❌ "Fast enough"

**Be measurable:**
- ✅ "Cache hit rate > 90%"
- ❌ "Good cache performance"

**Be observable:**
- ✅ "Red color applied when value > 80%"
- ❌ "Looks right"

**Include thresholds:**
- ✅ "No errors at 1000 RPS"
- ❌ "Handles load"

## Test Coverage Goals

**Critical paths:** 100% coverage
- Authentication
- Payment processing
- Data integrity

**Business logic:** 90%+ coverage
- Validation rules
- Calculations
- State transitions

**Edge cases:** Explicit tests
- Empty states
- Error conditions
- Boundary values

**Happy path:** Always covered
- Primary user flows
- Common operations

## Verification Checklist

Before marking a spec complete:

- [ ] Every requirement has a test method
- [ ] Pass criteria are specific and measurable
- [ ] Critical paths have 100% coverage
- [ ] Edge cases are explicitly tested
- [ ] Performance requirements have benchmarks
- [ ] Manual tests have clear instructions

## Anti-Patterns

❌ **Vague criteria:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Works correctly | Manual test | Looks good |
```

✅ **Specific criteria:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Displays user name | E2E test | Name appears in header within 2s |
```

---

❌ **No test method:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Fast performance | TBD | TBD |
```

✅ **Clear test method:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| API response < 200ms | Performance test | p95 latency < 200ms |
```

---

❌ **Unmeasurable:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Good user experience | Manual test | Users like it |
```

✅ **Measurable:**
```markdown
| Requirement | Test Method | Pass Criteria |
|-------------|-------------|---------------|
| Task completion time | Manual test | Users complete task in < 30 seconds |
```
