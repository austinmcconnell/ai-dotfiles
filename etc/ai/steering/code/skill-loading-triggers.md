# Skill Loading Triggers

Read the relevant skill BEFORE acting on these tasks — never rely on training data for conventions
that have explicit skills. A plan, handoff, or prior-session memory that supplies a ready-made
artifact (e.g. a commit message) does not replace the mapped skill — read the skill and check the
artifact against it, even when you believe you already know the convention.

| Task                                                                 | Skill to load first                 |
| -------------------------------------------------------------------- | ----------------------------------- |
| Writing commit messages                                              | `commit-message-writing`            |
| Beginning any multi-commit work                                      | `commit-workflow`                   |
| Creating research files                                              | `create-research`                   |
| Updating existing research                                           | `update-research`                   |
| Verifying/fact-checking research                                     | `verify-research`                   |
| Delegating research to sub-agents                                    | `research-delegation`               |
| Writing specs or design docs                                         | `spec-writing`                      |
| Writing implementation guides                                        | `implementation-guide`              |
| Running pre-commit hooks                                             | `pre-commit-validation`             |
| Verifying all checks pass                                            | `verification-loop`                 |
| Creating or editing skills                                           | `kiro-skill-authoring`              |
| Recommending/comparing tools or libs                                 | `tool-selection`                    |
| Writing/reviewing pytest tests                                       | `pytest-conventions`                |
| Running Python tools/commands                                        | `virtual-environment`               |
| Creating release analysis                                            | `release-analysis`                  |
| Reviewing a PR / code review                                         | `pr-review`                         |
| Stress-testing an article / auditing claims                          | `stress-test-analysis`              |
| Doubting a non-trivial decision before it stands                     | `doubt-driven-development`          |
| Hardening code / handling untrusted input, auth, secrets, LLM output | `security-and-hardening`            |
| Instrumenting a service / adding metrics, spans, or alerts           | `observability-and-instrumentation` |
| Designing/changing a service endpoint or retried outbound call       | `api-idempotency-and-contracts`     |
| Optimizing backend performance / N+1, slow queries, pooling, caching | `backend-performance`               |
| Deciding what to work on / scoping an idea                           | `idea-refinement`                   |
| Session start / open questions arise                                 | `todo`                              |
| Promoting corrections to steering                                    | `distill-learnings`                 |
| Navigating project docs / find a doc / explain how a subsystem works | `readme-pointer`                    |
| Saving/handing off engram memory                                     | `memory-management`                 |

When citing existing research from a knowledge base, check `last_verified` in the file's YAML
frontmatter. If older than 90 days, warn the user before presenting the data as current.
