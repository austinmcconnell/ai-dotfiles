# Skill Loading Triggers

Triggers common to every agent, and the rule for applying them, live in
`shared/skill-loading-triggers.md`. The rows below are specific to this domain.

| Task                                       | Skill to load first        |
| ------------------------------------------ | -------------------------- |
| Beginning any work you intend to commit    | `commit-workflow`          |
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

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
