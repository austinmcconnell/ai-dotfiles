# Commit Message Examples

Real-world examples of well-written commit messages.

## Features

### New User-Facing Feature

```text
feat(dashboard): add real-time metrics display

Add dashboard showing CPU, memory, and disk usage with auto-refresh
every 5 seconds. Metrics exceeding 80% threshold are highlighted in red.

- Implement metrics API endpoint
- Add client-side polling with 5s interval
- Add threshold highlighting logic
- Include error handling and empty states

Jira issue: DASH-456
```

### API Enhancement

```text
feat(api): add pagination to user list endpoint

Support page and per_page query parameters for /api/users endpoint.
Returns total count in response metadata for client-side pagination.

Example: GET /api/users?page=2&per_page=50

Jira issue: API-234
```

### Authentication Feature

```text
feat(auth): implement OAuth2 login flow

Replace basic authentication with OAuth2 for improved security.
Implements PKCE flow for public clients with secure session cookies.

- Add OAuth2 client configuration
- Implement authorization code flow with PKCE
- Add session management with HttpOnly cookies
- Add role-based access control

Breaking change: Removes /api/login endpoint. Clients must migrate
to /api/auth/login with OAuth2 flow.

Jira issue: AUTH-123
```

## Bug Fixes

### Simple Bug Fix

```text
fix(api): handle null responses from external service

Add null check before accessing response.data to prevent crashes
when external service returns empty response.

Fixes #789
```

### Performance Fix

```text
fix(db): optimize user lookup query

Add index on users.email column to improve login performance.
Reduces average query time from 800ms to 45ms.

Jira issue: PERF-567
```

### Security Fix

```text
fix(auth): prevent session fixation vulnerability

Regenerate session ID after successful authentication to prevent
session fixation attacks. Session is now marked as permanent with
proper expiration.

Addresses security audit finding SA-2024-003
```

## Refactoring

### Code Cleanup

```text
refactor(user): extract validation logic to separate module

Move user validation from controller to dedicated validator class
for better testability and reuse across multiple endpoints.

- Create UserValidator class
- Add comprehensive validation tests
- Update controllers to use validator
```

### Architecture Change

```text
refactor(api): migrate to service layer pattern

Introduce service layer between controllers and database to improve
separation of concerns and testability.

- Create service classes for each domain
- Move business logic from controllers to services
- Update tests to mock services instead of database
```

## Documentation

### README Update

```text
docs(readme): add Docker setup instructions

Include steps for running application in Docker container with
environment variable configuration and volume mounts.

- Add Dockerfile example
- Document required environment variables
- Add docker-compose.yml example
```

### API Documentation

```text
docs(api): document authentication endpoints

Add OpenAPI/Swagger documentation for OAuth2 authentication flow
including request/response examples and error codes.
```

## Testing

### New Tests

```text
test(user): add validation edge case tests

Add tests for email validation edge cases including:
- International domain names
- Plus addressing (user+tag@example.com)
- Subdomain handling
```

### Test Infrastructure

```text
test: add integration test fixtures

Create reusable test fixtures for database seeding and API mocking
to reduce test setup boilerplate.
```

## Chores

### Dependency Update

```text
chore(deps): update Flask to 3.0.0

Update Flask from 2.3.x to 3.0.0 for security fixes and performance
improvements. No breaking changes in our usage.
```

### Build Configuration

```text
chore(ci): add automated security scanning

Add Bandit and Safety checks to CI pipeline to detect security
vulnerabilities in code and dependencies.
```

### Tooling

```text
chore: add pre-commit hooks for code quality

Configure pre-commit with black, isort, and flake8 to enforce
code style consistency before commits.
```

## Style Changes

### Formatting

```text
style: format code with black

Run black formatter on all Python files to ensure consistent
code style. No functional changes.
```

### Linting

```text
style(api): fix linting warnings

Address flake8 warnings including unused imports, line length,
and whitespace issues. No behavior changes.
```

## Breaking Changes

### API Change

```text
feat(api)!: change user response format

Standardize API responses to use consistent envelope format with
data, meta, and errors fields.

BREAKING CHANGE: User endpoints now return data in `data` field
instead of root level. Update clients to access `response.data.user`
instead of `response.user`.

Before:
{
  "id": "123",
  "email": "user@example.com"
}

After:
{
  "data": {
    "id": "123",
    "email": "user@example.com"
  },
  "meta": {
    "timestamp": "2024-01-01T00:00:00Z"
  }
}

Jira issue: API-890
```

### Configuration Change

```text
chore!: migrate to environment-based configuration

Replace config files with environment variables for better
container compatibility and security.

BREAKING CHANGE: Configuration files are no longer supported.
Set environment variables instead:
- DATABASE_URL (required)
- SECRET_KEY (required)
- REDIS_URL (optional)

See .env.example for full list.
```

## Multi-Component Changes

### Feature Spanning Multiple Areas

```text
feat: add user profile management

Implement complete user profile functionality including view,
edit, and avatar upload.

- Add profile API endpoints (GET, PUT /api/profile)
- Add profile UI components
- Implement avatar upload with S3 storage
- Add profile validation and error handling
- Add profile update tests

Jira issue: USER-345
```

### Cross-Cutting Refactor

```text
refactor: standardize error handling across application

Implement consistent error handling pattern using custom exception
classes and centralized error handler.

- Create custom exception hierarchy
- Add global error handler
- Update all endpoints to use custom exceptions
- Add error response tests
```

## Reverts

### Reverting a Commit

```text
revert: revert "feat(api): add pagination"

This reverts commit abc123def456.

Pagination implementation caused performance regression in production.
Will reimplement with proper indexing in next iteration.

Jira issue: HOTFIX-789
```

## Co-Authored Commits

### Pair Programming

```text
feat(search): implement full-text search

Add PostgreSQL full-text search for user and organization names
with ranking and highlighting support.

Co-authored-by: Jane Developer <jane@example.com>
```

## Release Commits

### Version Bump

```text
chore(release): bump version to 2.1.0

Update version number and generate changelog for 2.1.0 release.

Includes:
- 5 new features
- 12 bug fixes
- 3 performance improvements
```
