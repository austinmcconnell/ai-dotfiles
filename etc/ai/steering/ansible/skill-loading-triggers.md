# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills.

| Task                                       | Skill to load first        |
| ------------------------------------------ | -------------------------- |
| Writing commit messages                    | `commit-message-writing`   |
| Multi-commit implementation work           | `commit-workflow`          |
| Creating new ansible projects              | `scaffold-ansible-project` |
| Updating ansible projects from template    | `scaffold-ansible-project` |
| Creating Ansible roles                     | `create-role`              |
| Adding Molecule tests to a role            | `create-role`              |
| Creating a Molecule scenario               | `create-role`              |
| Creating Ansible playbooks                 | `create-playbook`          |
| Reviewing Ansible code                     | `ansible-review`           |
| Delegating research to sub-agents          | `research-delegation`      |
| Recommending/comparing tools or libs       | `tool-selection`           |
| Brainstorming/refining ideas, picking work | `idea-refinement`          |
| Tracking open questions / blockers         | `todo`                     |
| Saving/handing off engram memory           | `memory-management`        |
| Promoting corrections to steering          | `distill-learnings`        |
| Navigating project docs / find a doc       | `readme-pointer`           |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
