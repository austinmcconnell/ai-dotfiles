# Claude Code Configuration Update Research

## Purpose

Research recent Claude Code releases and evaluate whether configuration updates are needed based on
breaking changes, deprecations, and new features that fit the specific setup.

## Research Phase

Search online for the latest Claude Code releases and changes from the past 3-6 months. Focus on:

1. Recent version releases and their key features
1. Changes to `settings.json` schema (new fields, deprecated fields, syntax changes)
1. Changes to the permissions model (`allow`/`deny`/`ask` patterns, tool name syntax)
1. Changes to the hooks system (new events, matcher syntax, payload fields)
1. Changes to subagents/personas (`agents/` frontmatter fields, invocation syntax)
1. Current best practices for `CLAUDE.md` / memory, MCP server configuration, and skills
1. Breaking changes or migration requirements

Provide a summary with specific version numbers, dates, and concrete configuration examples.

## Analysis Phase

Compare those findings with my current Claude Code config in `etc/claude-code/`. Also read
`install/claude-code.sh` and the "Claude Code Conventions" section of `AGENTS.md` to understand my
setup and usage patterns.

Analyze:

1. **Breaking changes** - Are there any changes where my current config is not fully working
   anymore?
1. **Deprecations** - Are there any features that currently work but won't in the future?
1. **Recommended updates** - Are there non-breaking changes or new features I should adopt?

## Evaluation Criteria

For recommended updates, critically evaluate whether each recommendation makes sense for MY specific
setup:

- Consider my permission model (deny-first, minimal-friction reads, cross-tool parity with kiro-cli)
- Consider my subagent architecture (four scoped personas plus the main session as generalist —
  no persona equivalent of kiro's `code` agent)
- Consider my hook usage (shared scripts across kiro-cli and Claude Code via `SessionStart`,
  `PreToolUse`, `PostToolUse`, `UserPromptSubmit`)
- Consider maintenance burden vs. actual benefit
- Skip recommendations that add complexity without solving a real problem
- Prioritize changes that fix issues, close security gaps, or improve maintainability

## Output Format

Write findings to `claude-code-changes.md` with these sections:

1. **Breaking Changes** - Issues requiring immediate fixes
1. **Deprecations** - Working now but will break in future
1. **Recommended Updates** - Changes worth considering for this setup
1. **Not Recommended** - Features that don't fit this use case (brief list with reasons)

For each actionable item (sections 1-3), include:

- Short description of the change/feature
- Why it matters for this setup
- Link to official Claude Code documentation
- Code example

**Important:** Only include items in "Recommended Updates" if they require action. Don't list things
that are already configured correctly.
