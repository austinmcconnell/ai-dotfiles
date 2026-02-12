# Security Best Practices

When generating or reviewing code:

## Data Handling

- Never hardcode credentials or secrets
- Use environment variables for sensitive configuration
- Sanitize user inputs to prevent injection attacks
- Validate and sanitize data before storing or processing

## Authentication & Authorization

- Use secure authentication methods (OAuth, JWT)
- Implement proper authorization checks
- Use HTTPS for all network communications
- Implement rate limiting for authentication attempts

## Dependency Management

- Regularly update dependencies to patch security vulnerabilities
- Avoid using deprecated or unmaintained packages
- Use lockfiles to ensure consistent dependency versions
- Scan dependencies for known vulnerabilities

## Code Security

- Avoid SQL injection by using parameterized queries
- Prevent XSS by escaping output in web applications
- Set appropriate CORS policies
- Implement proper error handling without leaking sensitive information
