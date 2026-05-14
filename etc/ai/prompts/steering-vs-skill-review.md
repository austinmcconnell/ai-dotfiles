# Steering vs Skill Review

Review all steering documents in `~/.dotfiles/etc/kiro-cli/steering/` and evaluate whether each one
is correctly placed as a steering doc or would be better as a skill.

## Context

This dotfiles repo uses a two-tier system for AI agent guidance:

- **Steering docs** are loaded into every session for a given agent. They cost context window on
  every interaction, so they must earn their place.
- **Skills** are loaded on demand when a specific task is detected. They have no context cost until
  needed.

## Decision criteria

For each steering document, evaluate against these questions in priority order:

1. **Does the agent need this to do its core job in most sessions?** This is the primary question.
   If removing the doc would cause the agent to make frequent, visible mistakes in routine work, it
   belongs in steering regardless of size or content format.
1. **Is the content principles/conventions or workflows/templates/reference material?** Principles
   and conventions that shape every response belong in steering. Workflows, templates, and reference
   material that only apply during specific tasks belong in skills.
1. **Is it only needed for specific tasks?** Content that applies only when doing a particular
   activity (e.g., creating JIRA tickets, scaffolding a project) is a candidate for a skill, unless
   it contains safety guardrails that must be always-loaded.
1. **Does an existing skill already cover the same ground?** Check skill descriptions in
   `~/.dotfiles/etc/kiro-cli/skills/` for overlap. If a skill exists, determine whether the steering
   doc duplicates it or provides complementary always-needed rules.

**Important:** Content format (tables, code examples, diagrams) is a weak signal. A terminology
table that prevents style violations every session is a convention, not reference material. Evaluate
based on frequency of need, not format.

## What to analyze

For each steering document:

1. Read the full file
1. Identify which agent(s) load it (check resource globs in
   `~/.dotfiles/etc/kiro-cli/cli-agents/*.json`)
1. Classify content against the decision criteria above
1. Note file size for context cost awareness
1. Check for overlapping skills

## What NOT to recommend

- Don't recommend converting safety guardrails to skills — safety rules must be always-loaded
- Don't recommend changes to skills themselves — only evaluate steering placement
- Don't use file size alone as a reason to convert — a large file the agent needs every session is
  better than a small file it never needs

## Output format

Present findings as a table with columns: file, size, agent(s), classification, recommendation
(keep/convert/split/trim), and rationale.

For any file recommended for conversion, splitting, or trimming, include:

- What specifically should move or be removed
- Where it should go (which existing or new skill)
- What should remain in steering (if splitting)
- Estimated size after the change

End with a summary: total current context cost per agent, proposed cost after changes, and
prioritized action items.
