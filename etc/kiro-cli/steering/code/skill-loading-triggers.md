# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                             | Skill to load first                                            |
| -------------------------------- | -------------------------------------------------------------- |
| Writing commit messages          | `commit-message-writing`                                       |
| Creating research files          | `create-research`                                              |
| Updating existing research       | `update-research`                                              |
| Verifying/fact-checking research | `verify-research`                                              |
| Researching countries/relocation | `create-research` + `relocation-research-conventions` steering |
| Writing specs or design docs     | `spec-writing`                                                 |
| Writing implementation guides    | `implementation-guide`                                         |
| Running pre-commit hooks         | `pre-commit-validation`                                        |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
