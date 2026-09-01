# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                                  | Skill to load first                               |
| ------------------------------------- | ------------------------------------------------- |
| Writing commit messages               | `commit-message-writing`                          |
| Creating research files               | `create-research`                                 |
| Updating existing research            | `update-research`                                 |
| Verifying/fact-checking research      | `verify-research`                                 |
| Researching countries for relocation  | `create-research` + `country-relocation-research` |
| Updating country relocation research  | `update-research` + `country-relocation-research` |
| Verifying country relocation research | `verify-research` + `country-relocation-research` |
| Researching US states for relocation  | `create-research` + `state-relocation-research`   |
| Updating state relocation research    | `update-research` + `state-relocation-research`   |
| Verifying state relocation research   | `verify-research` + `state-relocation-research`   |
| Writing specs or design docs          | `spec-writing`                                    |
| Writing implementation guides         | `implementation-guide`                            |
| Running pre-commit hooks              | `pre-commit-validation`                           |
| Verifying all checks pass             | `verification-loop`                               |
| Creating or editing skills            | `kiro-skill-authoring`                            |
| Creating release analysis             | `release-analysis`                                |
| Reviewing a PR / code review          | `pr-review`                                       |
| Promoting corrections to steering     | `distill-learnings`                               |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
