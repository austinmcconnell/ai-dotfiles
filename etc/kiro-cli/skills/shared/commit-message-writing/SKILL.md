---
name: commit-message-writing
description: Write clear, conventional commit messages following conventional commits format. IMPORTANT - Read full skill before running git log — never use --oneline. Use when writing commit messages, committing code, using git commit, reviewing commits, or asking about commit message format, types, or conventions.
---

# Commit Message Writing

## When to Use This Skill

Write commit messages for:

- Any Git commit
- Pull request titles
- Changelog generation
- Release notes

## Matching Repository Conventions

Before writing a commit message, inspect recent commits to learn the repository's conventions:

```bash
git log -10 --format="%h%n%B---"
```

Always use a format that shows full commit messages including body and footer. Do not use
`--oneline` — it hides multi-line conventions like body bullet style and footer usage.

**This skill is the primary authority for commit message structure.** Repo history may inform minor
stylistic choices but never overrides the rules defined here.

### Allowed adaptations from repo history

- **Scope naming style** — short names (`auth`, `components`) vs paths (`components/cpu`)
- **Body bullet format** — `- description` vs `- file: description` vs prose paragraphs
- **Scope omission patterns** — when the repo omits scope for cross-cutting changes

### Never adapt from repo history

- Commit type selection (use the types defined in this skill)
- Subject line length, format, or casing rules
- Imperative mood requirement
- Body line wrapping (72 characters)
- Breaking change format
- Whether to include a body (decide based on change complexity, not repo trends)

## Atomic Commits

Each commit should contain exactly one logical change. When staged or unstaged changes span multiple
concerns, recommend separate commits rather than combining them into one.

**Split into separate commits when changes have:**

- Different commit types (e.g., a `fix` and a `feat`)
- Different scopes (e.g., `auth` and `api`)
- Independent motivations (could be reverted independently)

**Keep as one commit when changes are:**

- All required to achieve a single goal
- Meaningless without each other (e.g., a feature and its config)

When recommending multiple commits, present them in dependency order — the commit that others build
on comes first.

## Commit Message Format

### Structure

```text
<type>(<scope>): <subject>

<body>

<footer>
```

### Subject Line (Required)

**Format:** `<type>(<scope>): <subject>`

**Rules:**

- Maximum 50 characters
- Use imperative mood ("add" not "added" or "adds")
- No period at the end
- Lowercase after colon

**Example:**

```text
feat(auth): add OAuth2 login support
```

### Body

Include a body by default. Omit it only for trivial changes where the subject line tells the
complete story (typo fixes, single-line config changes, version bumps).

**Include a body when:**

- The change touches multiple files or areas
- The motivation is not obvious from the subject line alone
- There are multiple distinct sub-changes within one logical commit
- The change has side effects, implications, or trade-offs worth noting

**Rules:**

- Wrap at 72 characters per line
- Explain **what** and **why**, not **how**
- Separate from subject with blank line
- Use bullet points with `-` for multiple items

**Example:**

```text
feat(auth): add OAuth2 login support

Implement OAuth2 authentication flow to replace basic auth.
This provides better security and enables SSO integration.

- Add OAuth2 client configuration
- Implement PKCE flow for public clients
- Add session management with secure cookies
```

### Footer (Optional)

**Rules:**

- Reference issues, tickets, or breaking changes
- Format: `Token: value` or `Token #value` (follows git trailer convention)
- Use `BREAKING CHANGE:` (all caps) for breaking changes

**Example:**

```text
Refs: #123
Jira issue: AUTH-123
BREAKING CHANGE: Removes /api/login endpoint
```

## Commit Types

### Primary Types

- **feat** - New feature for users
- **fix** - Bug fix for users
- **docs** - Documentation changes
- **style** - Formatting, whitespace (no code change)
- **refactor** - Code restructuring (no behavior change)
- **perf** - Performance improvements
- **test** - Adding or updating tests
- **build** - Build system or external dependencies
- **ci** - CI configuration files and scripts
- **chore** - Other changes (tooling, etc.)
- **revert** - Reverts a previous commit

### When to Use Each Type

**feat:**

- New user-facing functionality
- New API endpoints
- New UI components

**fix:**

- Bug fixes
- Error handling improvements
- Performance fixes

**docs:**

- README updates
- Code comments
- API documentation

**refactor:**

- Code cleanup
- Extracting functions
- Renaming variables

**perf:**

- Performance optimizations
- Query improvements
- Caching implementations

**test:**

- New test cases
- Test refactoring
- Test infrastructure

**build:**

- Build system changes
- Dependency updates
- Compiler configuration

**ci:**

- CI/CD pipeline changes
- GitHub Actions workflows
- Deployment scripts

**chore:**

- Tooling updates
- Configuration changes
- Maintenance tasks

**revert:**

- Reverting previous commits
- Rolling back changes

## Scope Guidelines

Scope indicates the area of change:

**Examples:**

- `feat(auth): add login endpoint`
- `fix(api): handle null responses`
- `docs(readme): update installation steps`
- `test(user): add validation tests`

**Common scopes:**

- Component names: `auth`, `api`, `ui`, `db`
- Feature areas: `login`, `dashboard`, `settings`
- File/module names: `user`, `order`, `payment`

**Omit scope when:**

- Change affects multiple areas
- Scope is obvious from context
- Change is global (e.g., `chore: update dependencies`)

## Writing Guidelines

**Subject line:**

- Start with type and optional scope
- Use imperative mood
- Be specific but concise
- Focus on user impact

**Body:**

- Explain motivation for change
- Describe what changed at high level
- Note any side effects or implications
- Reference related changes

**Footer:**

- Link to issue tracker
- Note breaking changes with `BREAKING CHANGE:`
- Credit co-authors

## Breaking Changes

Breaking changes can be indicated in two ways:

1. **Add `!` after type/scope:**

   ```text
   feat(api)!: remove deprecated endpoint
   ```

1. **Add `BREAKING CHANGE:` footer:**

   ```text
   feat(api): update response format

   BREAKING CHANGE: Response now uses data envelope
   ```

1. **Use both for emphasis:**

   ```text
   feat(api)!: update response format

   BREAKING CHANGE: Response now uses data envelope
   ```

## Examples

See [references/examples.md](references/examples.md) for comprehensive real-world examples.

### Quick Reference

Subject-only (trivial changes):

```text
docs(readme): fix typo in setup instructions
style: format code with black
chore(config): update linter rules
```

With body (most changes):

```text
feat(dashboard): add real-time metrics display

Show CPU, memory, and disk usage with auto-refresh every 5 seconds.
Metrics exceeding 80% threshold are highlighted in red.

- Add metrics API endpoint
- Add client-side polling with 5s interval
- Add threshold highlighting and empty states
```

```text
fix(api): prevent null pointer in user lookup

External service occasionally returns empty responses. Add null
check before accessing response.data to prevent crashes.

Fixes #789
```

```text
docs: add Docker setup instructions

Include steps for running the application in a Docker container
with environment variable configuration and volume mounts.

- Add Dockerfile example
- Document required environment variables
- Add docker-compose.yml example
```

## Breaking Changes Examples

```text
feat(api)!: change user response format
fix!: remove deprecated configuration option
feat(auth)!: migrate to OAuth2

BREAKING CHANGE: Basic auth is no longer supported
```

## Common Mistakes

❌ Vague: `fix: bug fix` → ✅ Specific: `fix(auth): prevent session timeout during active use`

❌ Past tense: `feat: added new feature` → ✅ Imperative: `feat: add new feature`

❌ Too long: `feat: add a new dashboard that shows real-time system metrics including CPU and memory`
→ ✅ Concise: `feat(dashboard): add real-time system metrics`

❌ No context: `fix: change timeout value` → ✅ With context:
`fix(api): increase timeout to 30s for large uploads`

❌ Wrong breaking change format: `Breaking change: removes endpoint` → ✅ Correct:
`BREAKING CHANGE: removes endpoint` or use `!`

## Reference Documentation

- [references/conventional-commits.md](references/conventional-commits.md) - Full conventional
  commits specification
- [references/examples.md](references/examples.md) - Real-world commit message examples
