# Skill Loading Triggers

Triggers common to every agent, and the rule for applying them, live in
`shared/skill-loading-triggers.md`. The rows below are specific to this domain.

| Task                                    | Skill to load first          |
| --------------------------------------- | ---------------------------- |
| Auditing Datadog observability setup    | `datadog-audit`              |
| Reviewing monitors for best practices   | `datadog-audit`              |
| Checking UST compliance                 | `datadog-audit`              |
| Reviewing ddtrace configuration         | `datadog-audit`              |
| Reviewing Terraform DD changes on a PR  | `datadog-audit`              |
| Checking DD resource configs for errors | `datadog-audit`              |
| Persisting a Datadog analysis's output  | `analysis-output` (steering) |
