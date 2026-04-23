# Steering Gap Analysis

Analyze kiro-cli agent configurations to identify gaps in steering docs — small, high-value
principles or conventions that are currently missing and would improve agent behavior across
sessions.

## Context

Steering docs are concise principles and conventions that shape EVERY response. Reference material,
templates, and workflows live in on-demand skills. The philosophy is: steering docs should be small
(ideally \<3KB each) and contain rules that apply to every session, not task-specific guidance.

This dotfiles repo is shared across work and personal machines. Not all referenced repos or
knowledge bases exist on both — that's expected.

## Agent usage notes

Brief descriptions of how each agent is primarily used:

- **default**: General development, code review, git operations across many repos
- **github**: PR review, issue triage, repository analysis
- **jira**: Story creation/updates, worklog entries
- **docs**: Writing/editing mdBook documentation across multiple repos

## What to analyze

For each agent (default, github, jira, docs), review:

1. **Agent prompt** in `~/.dotfiles/etc/kiro-cli/cli-agents/{name}-prompt.md`
1. **Current steering docs** loaded via resources in
   `~/.dotfiles/etc/kiro-cli/cli-agents/{name}.json` (follow the `file://` resource globs to find
   which steering docs each agent loads)
1. **Skills available** to the agent (follow the `skill://` resource globs)
1. **Tool permissions** in toolsSettings (what the agent can and can't do)

For each agent, consider:

- What tasks does this agent handle most often given its tools, description, and usage notes above?
- Are there recurring patterns or conventions that should shape every response but aren't captured
  in steering? (e.g., naming conventions, safety rules, output format preferences)
- Are there common mistakes an AI agent makes in this domain that a small steering rule would
  prevent?
- Is anything in the agent prompt that would be better as a steering doc (reusable across agents) or
  vice versa?
- Are there principles from the skills that are important enough to warrant a compressed rule in
  steering? (The bar is: does this need to influence responses even when the skill isn't loaded?)

## Pre-commit alignment

Verify proposed conventions against `.pre-commit-config.yaml` and any associated linter config files
(`.markdownlintrc`, `.yamllint.yaml`, `.prettierrc`, `.editorconfig`, `shellcheckrc`, shfmt args,
etc.). Steering docs must not contradict what pre-commit hooks enforce. Check the dotfiles repo and
2-3 documentation repos in `~/projects/austinmcconnell/_documentation_/` for shared hook configs.

## What NOT to recommend

- Don't recommend large reference docs or templates as steering — those belong in skills
- Don't recommend duplicating skill content into steering
- Don't recommend changes to skills themselves — only steering and agent prompts
- Don't recommend steering docs over 3KB

## Output format

For each agent, present:

- Current steering inventory (what it loads today, with sizes)
- Gaps identified (what's missing, why it matters, how often it would apply)
- Proposed steering doc or prompt change (actual content, not just a description)
- Estimated size of each addition

Prioritize by impact: which gaps cause the most frequent or most visible quality issues?
