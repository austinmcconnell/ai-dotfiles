# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills. A plan, handoff, or prior-session memory that supplies a ready-made
artifact (e.g. a commit message) does not replace the mapped skill — read the skill and check the
artifact against it, even when you believe you already know the convention.

| Task                                       | Skill to load first      |
| ------------------------------------------ | ------------------------ |
| Writing commit messages                    | `commit-message-writing` |
| Multi-commit implementation work           | `commit-workflow`        |
| Creating ADRs/decisions                    | `create-adr`             |
| Creating component files                   | `create-component`       |
| Creating configuration files               | `create-configuration`   |
| Creating procedure files                   | `create-procedure`       |
| Creating project research                  | `create-docs-research`   |
| Delegating research to sub-agents          | `research-delegation`    |
| Reviewing documentation                    | `docs-review`            |
| Stress-testing doc claims / reasoning      | `stress-test-analysis`   |
| Running pre-commit hooks                   | `pre-commit-validation`  |
| Brainstorming/refining ideas, picking work | `idea-refinement`        |
| Tracking open questions / blockers         | `todo`                   |
| Saving/handing off engram memory           | `memory-management`      |
| Promoting corrections to steering          | `distill-learnings`      |
| Navigating project docs / find a doc       | `readme-pointer`         |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
