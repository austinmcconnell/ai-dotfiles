---
name: datadog-audit
description: Audit Datadog observability setup for a service. Use when auditing monitors, APM configuration, UST compliance, Terraform-managed DD resources, or checking overall observability health.
---

# Datadog Audit

Read `references/datadog-audit-checklist.md` before performing any audit — it contains the full
checklist organized by category.

## Workflow

1. **Check prerequisites** — verify tooling is available:

   - Run `command -v pup` to confirm Pup CLI is installed
   - Run `pup auth status` to confirm authentication is valid
   - If Pup is unavailable or unauthenticated, skip live queries (step 7) and note in findings that
     live validation was not possible

1. **Identify the service** — determine the service name, language/framework, deployment method
   (K8s, ECS, etc.), and Datadog site (`ddog-gov.com`). If the working tree is on a feature branch,
   note this in findings and consider whether it affects the audit (e.g., missing config that exists
   on `main`).

1. **Fetch reference docs** — retrieve the relevant official Datadog documentation for the service's
   stack:

   - Unified Service Tagging:
     <https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/>
   - Library config (language-specific): e.g.,
     <https://docs.datadoghq.com/tracing/trace_collection/library_config/python/>
   - Profiler setup (language-specific): e.g.,
     <https://docs.datadoghq.com/profiler/enabling/python/>
   - Monitor best practices: <https://docs.datadoghq.com/monitors/guide/>

1. **Inspect application instrumentation** — find and read source code files:

   Discover files first:

   - Tracing init: `grep -rl "ddtrace\|patch_all\|Profiler" app/ src/ --include="*.py"`
   - Settings/config: `grep -rl "DD_" app/ src/ --include="*.py" | grep -i "setting\|config\|trac"`
   - Logging setup: `grep -rl "logging\|log_format\|getLogger" app/ src/ --include="*.py" | head -5`

   Then check each file for:

   - ddtrace configuration (env vars, `ddtrace-run`, programmatic setup)
   - UST env vars (`DD_ENV`, `DD_SERVICE`, `DD_VERSION`) — verify all three are passed to ddtrace
   - `version` parameter passed to `Profiler()` init
   - Log injection (`DD_LOGS_INJECTION`) and log format including `dd.trace_id`, `dd.span_id`
   - Structured JSON logging vs plain text format
   - `dd.env`, `dd.service`, `dd.version` in log format string
   - Profiling enablement (`DD_PROFILING_ENABLED`, `DD_PROFILING_EXCEPTION_ENABLED`,
     `DD_PROFILING_HEAP_ENABLED` for Python)
   - Custom span tags and resource naming
   - `DD_TAGS` for static tags (team, component)

1. **Inspect Kubernetes/Helm configuration** — find and read deployment files:

   Discover files first:

   - Helm values:
     `find infrastructure/ -name "values*.yaml" -o -name "*.yaml" -path "*/environments/*"`
   - ConfigMaps: `find infrastructure/ -name "configmap*"`
   - Deployments: `find infrastructure/ -name "deployment*"`
   - Service catalog: `find . -name "service.datadog.yaml" -maxdepth 2`

   Then check for:

   - UST pod labels (`tags.datadoghq.com/env`, `service`, `version`) on all pod templates
   - `DD_VERSION` env var in ConfigMap (not just the K8s label — ddtrace needs the env var)
   - `DD_TAGS` env var for team/component tags on emitted telemetry
   - `DD_RUNTIME_METRICS_ENABLED` set in deployed environments
   - `DD_GIT_REPOSITORY_URL` and `DD_GIT_COMMIT_SHA` for source code integration
   - Agent sidecar or DaemonSet configuration
   - `DD_AGENT_HOST` pointing to correct target
   - Admission controller annotations if applicable
   - `service.datadog.yaml` for Service Catalog integration

1. **Inspect Terraform Datadog resources** — check for:

   - Monitor naming conventions and tag compliance
   - Monitor recovery thresholds (`critical_recovery`, `warning_recovery`)
   - Error rate monitors using percentage (errors/hits), not just absolute count
   - Latency monitors using p95/p99, not just average
   - Dashboard structure, template variables (`env`, `service`, `version`), deployment markers
   - Dashboard runtime metrics widgets (GC, threads, memory breakdown)
   - Synthetics test coverage (health + API endpoints), location redundancy, body assertions
   - SSL certificate expiry tests
   - APM retention filters for critical traces
   - SLO definitions with error budget alerts
   - Consistent use of variables for service/env

1. **Query live state via Pup CLI** (skip if prerequisites failed) — use `pup` to:

   - List monitors for the service: `pup monitors list --tags="service:<name>"`
   - Get a quick summary of monitor names:
     `pup monitors list --tags="service:<name>" --jq '.[].name'`
   - Get individual monitor details to check recovery thresholds:
     `pup monitors get <id> --jq '.thresholds'`
   - Compare Terraform state vs live: `pup monitors diff`
   - Verify synthetic tests exist for critical endpoints: `pup synthetics tests list`
   - **Validate APM data is flowing** (config alone is insufficient):
     `pup metrics query --query="avg:trace.<framework>.request.hits{env:<env>,service:<name>}.as_count()" --from="1h"`
   - **Validate runtime metrics are flowing** (catches cases where env var is set but data isn't
     collected):
     `pup metrics query --query="avg:runtime.<lang>.thread_count{env:<env>,service:<name>}" --from="4h"`
   - **Validate custom metrics** (if app emits DogStatsD metrics, confirm at least one has data):
     `pup metrics query --query="avg:<custom_metric>{env:<env>,service:<name>}" --from="1h"`
   - If config says enabled but live query returns 0 series → flag as **BROKEN**, not just missing

1. **Produce findings** — organize by severity:

   - **Critical**: Missing UST tags, no monitors for key SLIs, broken instrumentation, metrics
     configured but not flowing
   - **Warning**: Suboptimal configuration, missing profiling, no synthetics, no SLOs
   - **Info**: Style inconsistencies, opportunities for improvement

## Output Format

Present findings as a structured report with:

- Maturity rating (1–5 scale)
- Executive summary and top 3 strengths
- Tagging consistency matrix (resource type × UST tags applied)
- Findings table (severity, category, description, recommendation)
- Quick wins with file paths and code snippets
- Priority remediation order
