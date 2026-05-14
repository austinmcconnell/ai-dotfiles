# PR Conventions

## Template Discovery

Before drafting a PR description, check for project-specific templates:

1. Look in `.github/` for `pull_request_template.md`, `PULL_REQUEST_TEMPLATE.md`, or templates in
   `.github/PULL_REQUEST_TEMPLATE/`
1. If a template exists, use it — fill in each section per the template's guidance
1. If no template exists, use the default structure below

## Filling Project Templates

When a project template has an **Implementation Details** section:

- Keep implementation details focused on *what was changed* — the specific code/config modifications
- Use a bullet list for implementation details when there are multiple changes
- Add a **Background Information** section before Implementation Details — even if the template
  doesn't define one — when the reviewer needs context to understand *why* the change was made: root
  cause analysis, metric explanations, architectural context, etc.
- Background should explain the problem and its cause; implementation details should explain the fix
- Skip Background Information for self-explanatory changes (typo fixes, dependency bumps,
  formatting)

For templates without an Implementation Details section, follow the template's own structure.
Lightweight templates (few sections, minimal guidance) are a minimum — add sections when they help
the reviewer. Detailed templates (many sections, specific instructions) signal a stricter structure;
add extra sections only when the change would be unclear without them.

For template sections that don't apply to the change, write "N/A" rather than removing the section.

## Default PR Structure

### Title

- Conventional commit format: `type(scope): description`
- Under 72 characters, lowercase after prefix

### Body

- **Summary**: 1-3 sentences explaining what and why
- **Changes**: bullet list of meaningful changes
- **Testing**: what was tested and how

## Workflow

- One logical change per PR
- Link related issues: `Closes #N` or `Relates to #N`
- Draft PRs for work-in-progress
- Reference commits by SHA, not description

## Output Format

Always output PR descriptions as raw markdown — no wrapping in code fences, no surrounding
commentary. Before running `gh pr create`, show the proposed title and description to the user and
get explicit approval.
