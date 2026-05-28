# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                                    | Skill to load first        |
| --------------------------------------- | -------------------------- |
| Writing commit messages                 | `commit-message-writing`   |
| Creating new ansible projects           | `scaffold-ansible-project` |
| Updating ansible projects from template | `scaffold-ansible-project` |
| Creating Ansible roles                  | `create-role`              |
| Adding Molecule tests to a role         | `create-role`              |
| Creating a Molecule scenario            | `create-role`              |
| Creating Ansible playbooks              | `create-playbook`          |
| Reviewing Ansible code                  | `ansible-review`           |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
