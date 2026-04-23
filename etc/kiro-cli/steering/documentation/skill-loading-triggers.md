# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                         | Skill to load first      |
| ---------------------------- | ------------------------ |
| Writing commit messages      | `commit-message-writing` |
| Creating ADRs/decisions      | `create-adr`             |
| Creating component files     | `create-component`       |
| Creating configuration files | `create-configuration`   |
| Creating procedure files     | `create-procedure`       |
| Creating project research    | `create-docs-research`   |
| Reviewing documentation      | `docs-review`            |
| Running pre-commit hooks     | `pre-commit-validation`  |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
