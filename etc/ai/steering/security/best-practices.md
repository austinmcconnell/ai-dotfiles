# Security Best Practices

These are the always-on principles for writing and reviewing code. Rules that apply to every agent,
whatever its domain, live in `shared/guardrails.md`. For the full hardening workflow —
threat-model-first analysis, STRIDE, the Always/Ask-first/Never boundary system, and per-control
patterns (injection, SSRF, destructive paths, secrets, dependencies, LLM output, privacy) — load the
`security-and-hardening` skill when the task warrants it.

When generating or reviewing code:

## Data Handling

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

- Avoid SQL injection by using parameterized queries; build subprocess calls as an argument list,
  never `shell=True` with interpolated input
- Encode output for its sink — escape HTML for browser-facing output, and never pass untrusted input
  (including LLM output) to `eval`/`exec`, a shell, or a file path
- Restrict CORS and network egress to an explicit allowlist for services that expose them
- Implement proper error handling without leaking sensitive information
