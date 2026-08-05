# Datadog Audit Checklist

## Unified Service Tagging (UST)

- [ ] `DD_ENV` set in deployment config (container env var, not just label)
- [ ] `DD_SERVICE` set and matches Service Catalog entry
- [ ] `DD_VERSION` set as container env var (ddtrace needs this; K8s label alone is insufficient)
- [ ] Pod labels `tags.datadoghq.com/env`, `service`, `version` present (K8s)
- [ ] `DD_VERSION` value changes with each deployment (image tag, git SHA, or semver)
- [ ] Terraform resources tagged with `service`, `env`, `team`
- [ ] Traces, logs, and metrics all carry consistent `env`, `service`, `version` tags

## APM / Tracing

- [ ] ddtrace (or equivalent) installed and active
- [ ] `DD_TRACE_ENABLED=true` (not disabled in production)
- [ ] `DD_TRACE_SAMPLE_RATE` explicitly configured
- [ ] `DD_AGENT_HOST` correctly targets the agent (sidecar or DaemonSet)
- [ ] Service name in traces matches `DD_SERVICE`
- [ ] No high-cardinality resource names (avoid user IDs, timestamps in span names)
- [ ] `DD_TAGS` set with static tags (e.g., `team:screenings`) so traces carry team context
- [ ] `DD_TRACE_128_BIT_TRACEID_GENERATION_ENABLED` considered for W3C interop
- [ ] `DD_TRACE_PROPAGATION_STYLE` set if integrating with non-Datadog services

### Advanced APM (lower priority)

- [ ] `DD_SERVICE_MAPPING` configured to rename auto-detected service names (Redis, PostgreSQL)
- [ ] `DD_TRACE_RATE_LIMIT` explicitly set if non-default rate limiting is needed
- [ ] `DD_TRACE_SPAN_ATTRIBUTE_SCHEMA` set to desired schema version
- [ ] `DD_TRACE_OBFUSCATION_QUERY_STRING_REGEXP` reviewed for PII protection

## APM Retention Filters

- [ ] Retention filters configured for critical traces (long duration, errors, key endpoints)
- [ ] Retention rate is appropriate (100% for critical, lower for high-volume)
- [ ] Filter queries use `service` and `@duration` or `@http.status_code` appropriately
- [ ] Managed via Terraform (`datadog_apm_retention_filter` resource)

## Profiling

- [ ] `DD_PROFILING_ENABLED=true` in production
- [ ] `DD_PROFILING_EXCEPTION_ENABLED=true` for exception hotspot detection
- [ ] `DD_PROFILING_HEAP_ENABLED=true` for memory profiling (Python)
- [ ] `version` parameter passed to `Profiler()` init (Python) or equivalent
- [ ] Profiler language support confirmed (Python: `ddtrace>=1.x`)
- [ ] Profile data visible in Datadog Continuous Profiler

## Log Correlation

- [ ] `DD_LOGS_INJECTION=true` (injects trace/span IDs into log records)
- [ ] Log format includes `dd.trace_id` and `dd.span_id`
- [ ] Logs are tagged with `service`, `env`, `version`
- [ ] Log pipeline configured in Datadog (parsing, attributes, service remapping)

## Monitors

- [ ] At least one monitor per key SLI (latency, error rate, throughput)
- [ ] Error rate monitor uses percentage (errors/hits ratio), not just absolute count
- [ ] Latency monitor covers p95 or p99 (not just average)
- [ ] Monitor names follow convention: `[<service>] <description> — <condition>`
- [ ] `notify_no_data: true` with reasonable `no_data_timeframe`
- [ ] Recovery thresholds set (`critical_recovery`, `warning_recovery`) to avoid flapping
- [ ] Notification channels defined (Slack, PagerDuty, email)
- [ ] Tags include `service`, `env`, `team`
- [ ] Escalation message differs from alert message
- [ ] All monitors managed via Terraform (not created in UI)

## SLOs

- [ ] SLOs defined for key endpoints (availability, latency)
- [ ] Error budget alerts configured (burn rate or remaining budget)
- [ ] SLOs linked to monitors for alerting on budget burn
- [ ] Managed via Terraform (`datadog_service_level_objective` resource)

## Dashboards

- [ ] Service has at least one overview dashboard
- [ ] Template variables include `env`, `service`, and `version`
- [ ] Deployment event overlay markers configured for visual correlation
- [ ] Widgets cover: latency (p50/p95/p99), error rate, throughput, resource usage
- [ ] Runtime metrics widgets present (GC pauses, thread count, memory breakdown)
- [ ] Dashboard title follows convention: `<Service> — <Purpose>`
- [ ] Managed via Terraform

## Synthetics

- [ ] Health check endpoint has a synthetic API test
- [ ] Critical API endpoints tested (not just health checks)
- [ ] Critical user journeys have synthetic browser tests (if applicable)
- [ ] Tests run from multiple locations (avoids single-point-of-failure false positives)
- [ ] Response body assertions validate content correctness, not just status code
- [ ] SSL certificate expiry test configured
- [ ] Failure thresholds configured (`min_failure_duration`, `min_location_failed`)
- [ ] Tagged with `service`, `env`, `team`
- [ ] Managed via Terraform

## Datadog Agent Configuration (K8s)

- [ ] Agent deployed as sidecar or DaemonSet
- [ ] APM enabled on the agent (`DD_APM_ENABLED=true`)
- [ ] Logs collection enabled if using agent-based log forwarding
- [ ] Agent version is recent (check for known issues in old versions)
- [ ] Resource limits set appropriately for the agent container

## Service Catalog

- [ ] `service.datadog.yaml` exists in project root
- [ ] Schema version is `v2.2` or later
- [ ] Team ownership defined (`team:` field)
- [ ] Contacts listed (Slack channel, email)
- [ ] On-call / escalation linked (PagerDuty or equivalent)
- [ ] Documentation URLs provided (README, API docs, runbooks)
- [ ] Repository URL linked
- [ ] SLOs defined on the Service Page

## Logging Format

- [ ] Structured JSON logging (not plain text) for reliable facet extraction
- [ ] Log format includes `dd.trace_id` and `dd.span_id` (for log-trace correlation)
- [ ] Log format includes `dd.env`, `dd.service`, `dd.version` (for unified tagging in logs)
- [ ] TraceIDFilter fallback for local dev (prevents KeyErrors when ddtrace inactive)
- [ ] Log pipeline configured in Datadog (parsing, service remapping, attributes)

## Runtime Metrics

- [ ] `DD_RUNTIME_METRICS_ENABLED=true` in deployed environments
- [ ] Runtime metrics confirmed flowing via live query (config alone is insufficient)
- [ ] DogStatsD access confirmed (Agent host + port 8125 reachable)
- [ ] Dashboard widgets visualize runtime metrics (GC pauses, thread count, memory breakdown)
- [ ] No custom `DD_DOGSTATSD_PORT` conflicts

## Source Code Integration

- [ ] `DD_GIT_REPOSITORY_URL` configured (links profiler/errors to source)
- [ ] `DD_GIT_COMMIT_SHA` configured (from image tag, build arg, or git rev-parse)
- [ ] Source code integration visible in Profiler UI (frames link to source)
- [ ] Source code integration visible in Error Tracking (stack frames link to source)

## Terraform Structure

- [ ] DD resources in dedicated module or directory (not mixed with app infra)
- [ ] Variables used for service name, env, team (not hardcoded)
- [ ] Monitor definitions use `for_each` or modules for consistency
- [ ] State is managed (remote backend, not local)
- [ ] Provider configured with `api_url` for ddog-gov.com
