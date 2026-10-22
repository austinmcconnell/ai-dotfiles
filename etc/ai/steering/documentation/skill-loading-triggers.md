# Skill Loading Triggers

Triggers common to every agent, and the rule for applying them, live in
`shared/skill-loading-triggers.md`. The rows below are specific to this domain.

| Task                                       | Skill to load first     |
| ------------------------------------------ | ----------------------- |
| Beginning any work you intend to commit    | `commit-workflow`       |
| Creating ADRs/decisions                    | `create-adr`            |
| Creating component files                   | `create-component`      |
| Creating configuration files               | `create-configuration`  |
| Creating procedure files                   | `create-procedure`      |
| Creating project research                  | `create-docs-research`  |
| Delegating research to sub-agents          | `research-delegation`   |
| Reviewing documentation                    | `docs-review`           |
| Stress-testing doc claims / reasoning      | `stress-test-analysis`  |
| Running pre-commit hooks                   | `pre-commit-validation` |
| Brainstorming/refining ideas, picking work | `idea-refinement`       |
| Tracking open questions / blockers         | `todo`                  |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
