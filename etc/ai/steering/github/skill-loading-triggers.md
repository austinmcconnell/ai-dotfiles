# Skill Loading Triggers

Triggers common to every agent, and the rule for applying them, live in
`shared/skill-loading-triggers.md`. The rows below are specific to this domain.

| Task                                 | Skill to load first   |
| ------------------------------------ | --------------------- |
| Beginning any multi-commit work      | `commit-workflow`     |
| Delegating research to sub-agents    | `research-delegation` |
| Recommending/comparing tools or libs | `tool-selection`      |
| Writing/reviewing pytest tests       | `pytest-conventions`  |
| Running Python tools/commands        | `virtual-environment` |
| Reviewing a PR / code review         | `pr-review`           |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
