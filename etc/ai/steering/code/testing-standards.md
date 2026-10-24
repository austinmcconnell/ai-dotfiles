---
paths:
  - '**/*.py'
  - '**/tests/**'
  - '**/test_*'
  - '**/conftest.py'
---

# Testing Standards

## What to Test

- Every new feature gets tests before or alongside implementation
- Bug fixes include a regression test that fails without the fix — but only for a regression in
  shipped/tested behavior. When a first-draft, uncommitted heuristic is corrected on its first
  contact with real data, re-run and verify instead of standing up a test suite ahead of need; offer
  the test, don't impose it
- Test behavior, not implementation — assert outputs and side effects, not internal state
- Cover error paths: invalid input, network failures, empty results, edge cases
- Integration tests for DB queries and multi-component flows
- Unit tests for business logic, transformations, and validation

For pytest mechanics once you're writing a test — fixtures, factories, mocking, parametrize,
assertions, test organization, coverage, and ruff `PT` rule specifics — see the `pytest-conventions`
skill.
