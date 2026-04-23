# PR Conventions

## Template Discovery

Before drafting a PR description, check for project-specific templates:

1. Look in `.github/` for `pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, or templates in
   `.github/PULL_REQUEST_TEMPLATE/`
1. If a template exists, use it — fill in each section per the template's guidance
1. If no template exists, use the default structure below

## Default PR Structure

### Title

- Conventional commit format: `type(scope): description`
- Under 70 characters, lowercase after prefix

### Body

- **Summary**: 1-3 sentences explaining what and why
- **Changes**: bullet list of meaningful changes
- **Testing**: what was tested and how

## Workflow

- One logical change per PR
- Link related issues: `Closes #N` or `Relates to #N`
- Draft PRs for work-in-progress
- Reference commits by SHA, not description
