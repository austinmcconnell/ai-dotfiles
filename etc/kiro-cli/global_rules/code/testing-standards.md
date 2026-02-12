# Testing Standards

When writing or suggesting tests:

## General Principles

- Every new feature should have tests
- Bug fixes should include regression tests
- Aim for high test coverage, especially for critical paths
- Tests should be independent and idempotent

## Python Testing

- Use pytest as the testing framework
- Organize tests to mirror the structure of the code
- Use fixtures for test setup
- Mock external dependencies

## Test Naming

- Test names should clearly describe what is being tested
- Follow pattern: `test_[function]_[scenario]_[expected result]`
- Example: `test_user_login_with_invalid_credentials_returns_error`

## Test Coverage

- Aim for minimum 80% code coverage
- Focus on testing edge cases and error conditions
- Don't just test the happy path
