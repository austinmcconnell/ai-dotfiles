# Datadog Conventions

## Datadog Site

This organization uses **ddog-gov.com** (GovCloud), not the default `datadoghq.com`. When
constructing URLs, referencing API endpoints, or configuring DD_SITE, always use `ddog-gov.com`.

The Pup CLI respects this via the `DD_SITE` environment variable or the authenticated session from
`pup auth login`.

## Unified Service Tagging (UST)

All services MUST have these three tags applied consistently across APM traces, metrics, logs, and
infrastructure:

- `env` — deployment environment (e.g., `production`, `staging`, `development`)
- `service` — the service name as it appears in the Service Catalog
- `version` — the deployed version (typically from git SHA or semantic version)

These tags must be set at:

1. **Application level** — via `DD_ENV`, `DD_SERVICE`, `DD_VERSION` environment variables
1. **Kubernetes level** — via `tags.datadoghq.com/env`, `tags.datadoghq.com/service`,
   `tags.datadoghq.com/version` pod labels
1. **Terraform level** — via tags on all `datadog_monitor`, `datadog_dashboard`, and
   `datadog_synthetics_test` resources

## ddtrace (Python)

For Python services using `ddtrace`:

- Enable via `ddtrace-run` or `DD_TRACE_ENABLED=true`
- Set `DD_PROFILING_ENABLED=true` for continuous profiling
- Set `DD_LOGS_INJECTION=true` to correlate logs with traces
- Set `DD_TRACE_SAMPLE_RATE` explicitly (don't rely on defaults)
- Use `DD_TAGS` for additional static tags (team, component)
- Configure `DD_AGENT_HOST` to point to the sidecar or DaemonSet agent

## Terraform-Managed Datadog Resources

All Datadog resources (monitors, dashboards, synthetics) are managed via Terraform. Never create or
modify them through the Datadog UI or API directly.

### Monitor Conventions

- Name format: `[<service>] <what is monitored> — <condition>`
- Include `service`, `env`, and `team` tags
- Set `notify_no_data: true` with appropriate `no_data_timeframe`
- Include recovery thresholds where applicable
- Use `include_tags: true` in notifications
- Escalation message should differ from the alert message

### Dashboard Conventions

- Title format: `<Service> — <Purpose>` (e.g., `Screenings Ingestion — Overview`)
- Include template variables for `env` and `service` at minimum
- Group widgets by concern (latency, throughput, errors, resources)

### Synthetics Conventions

- Name format: `[<env>] <service> — <what is tested>`
- Set appropriate `min_failure_duration` and `min_location_failed`
- Tag with `env`, `service`, and `team`

## Pup CLI Usage

Use `pup` for read-only queries against the Datadog platform:

- `pup monitors list --tags="service:<name>"` — find monitors for a service
- `pup monitors search --query="<text>"` — flexible monitor search
- `pup monitors diff` — compare Terraform state vs live (audit-relevant)
- `pup logs search --query="..." --from="1h"` — search recent logs
- `pup metrics query --query="..." --from="1h"` — query metrics
- `pup dashboards list` / `pup dashboards get <id>` — inspect dashboards
- `pup synthetics tests list` — list synthetic tests
- `pup infrastructure hosts list` — list monitored hosts
- `pup service-catalog list` — check service catalog entries

Use `--read-only` when running exploratory commands to prevent accidental writes, especially for
domains with subcommands you may not recognize. For explicit read commands (`list`, `get`,
`search`), the flag is redundant but harmless.

## Documentation vs API URLs

Datadog documentation is hosted at `docs.datadoghq.com` regardless of your org's site — always use
`docs.datadoghq.com` URLs when referencing documentation. Only API endpoints and the Pup CLI's
`DD_SITE` configuration use `ddog-gov.com`.

## Terraform Branch Review Protocol

When asked to review Datadog Terraform changes on a feature branch, perform the following:

1. **Correctness**: Validate metric names, query syntax, aggregation functions, and resource types
   against official Datadog documentation. Fetch docs — don't rely on training data for specifics
   like burn rate window pairings, SLO threshold semantics, or trace metric naming.
1. **Best practices**: Confirm current recommended approaches are used, not legacy/deprecated
   patterns. Check for cases where N resources are recommended but fewer exist (e.g., 3 burn rate
   monitors per 30d SLO, not 1).
1. **Completeness**: Flag missing fields that Datadog recommends (escalation_message,
   evaluation_delay, notify_no_data where traffic is expected, recovery thresholds).
1. **Consistency**: Compare new resources against existing monitors in the same module for naming,
   tagging, notification, and structural patterns.
1. **Semantic correctness**: Validate that threshold values, window sizes, and alert conditions make
   sense for the metric type, service traffic volume, and SLO target.

Always diff against main to scope the review to branch changes only.
