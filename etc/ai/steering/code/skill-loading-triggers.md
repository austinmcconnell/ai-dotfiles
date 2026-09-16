# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                                        | Skill to load first                               |
| ------------------------------------------- | ------------------------------------------------- |
| Writing commit messages                     | `commit-message-writing`                          |
| Multi-commit implementation work            | `commit-workflow`                                 |
| Creating research files                     | `create-research`                                 |
| Updating existing research                  | `update-research`                                 |
| Verifying/fact-checking research            | `verify-research`                                 |
| Delegating research to sub-agents           | `research-delegation`                             |
| Researching countries for relocation        | `create-research` + `country-relocation-research` |
| Updating country relocation research        | `update-research` + `country-relocation-research` |
| Verifying country relocation research       | `verify-research` + `country-relocation-research` |
| Researching US states for relocation        | `create-research` + `state-relocation-research`   |
| Updating state relocation research          | `update-research` + `state-relocation-research`   |
| Verifying state relocation research         | `verify-research` + `state-relocation-research`   |
| Writing specs or design docs                | `spec-writing`                                    |
| Writing implementation guides               | `implementation-guide`                            |
| Running pre-commit hooks                    | `pre-commit-validation`                           |
| Verifying all checks pass                   | `verification-loop`                               |
| Creating or editing skills                  | `kiro-skill-authoring`                            |
| Recommending/comparing tools or libs        | `tool-selection`                                  |
| Writing/reviewing pytest tests              | `pytest-conventions`                              |
| Running Python tools/commands               | `virtual-environment`                             |
| Creating release analysis                   | `release-analysis`                                |
| Reviewing a PR / code review                | `pr-review`                                       |
| Stress-testing an article / auditing claims | `stress-test-analysis`                            |
| Brainstorming/refining ideas, picking work  | `idea-refinement`                                 |
| Tracking open questions / blockers          | `todo`                                            |
| Promoting corrections to steering           | `distill-learnings`                               |
| Navigating project docs / find a doc        | `readme-pointer`                                  |
| Saving/handing off engram memory            | `memory-management`                               |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
