---
name: observability-and-instrumentation
description: Instrument a service so production questions are answerable before they are asked — metrics, traces, and alerts tied to on-call pain. Use when adding or reviewing in-code instrumentation (statsd/DogStatsD metrics, ddtrace custom spans and tags), when wiring a new endpoint, job, or external call for observability, when deciding what to measure or alert on, or when a service is hard to debug in production.
---

# Observability and Instrumentation

Instrument for the questions you will ask at 3am, not for a dashboard that looks busy. Every metric,
span, and alert exists to answer a specific operational question — "is it up, is it fast, is it
erroring, and where?" If a signal can't be traced to a question an on-call engineer will actually
ask, it is cost (cardinality, noise, alert fatigue), not value.

This skill is the **instrument-as-you-build** tier: how to emit good telemetry *from the service
code*. Its complement is the **audit-existing** tier — the `datadog-audit` skill and the `datadog/`
steering (`conventions.md`, `trace-metrics-and-latency.md`), which read and grade the declared
Datadog surface (monitors, SLOs, dashboards in Terraform). This skill writes the emitting side that
those declarations consume; reach for `datadog-audit` when the task is reviewing or querying what
already exists.

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> re-idiomed from its web/Node origin to a Python-service surface. The language-agnostic
> observability reasoning is upstream's; the examples are rewritten to `ddtrace` + `datadog.statsd`
> (DogStatsD) and use an invented order-service domain purely for illustration.

## When to Use

- Adding a new endpoint, scheduled job, cache layer, or external integration that will run in
  production
- A service is hard to debug: an incident took too long because the signal wasn't there
- Deciding what to measure, what to tag, or what to alert on
- Reviewing a diff that adds metrics or spans — checking cardinality, request-path safety, naming
- Standing up observability for a service that has little or none

## Vendor Note: ddtrace/statsd Primary, OTel-Equivalent

Examples use `ddtrace` (APM spans) and `datadog.statsd` (DogStatsD metrics) as a concrete stack. The
*concepts* are vendor-neutral and map one-to-one onto OpenTelemetry: a ddtrace `tracer.trace(name)`
span is an OTel span (`tracer.start_as_current_span`); `span.set_tag` is an OTel attribute;
`statsd.increment/gauge/histogram` are OTel counter/gauge/histogram instruments; a tag is an OTel
attribute, and the cardinality discipline below is identical. If a service adopts OTel, keep the
workflow and the naming/cardinality rules unchanged — only the API surface changes.

## Workflow

Instrument in this order. The first step is the one most often skipped, and skipping it is why
dashboards fill with signals no one reads.

1. **Start from the on-call question, not the metric.** Write down the question first: "is checkout
   erroring?", "which endpoint is slow?", "is the connection pool exhausted?". Each question names
   the signal that answers it. A metric with no question behind it is noise you pay to store and
   scroll past. If you can't state the question, don't emit the signal.

1. **Cover RED for request-driven work, USE for resources.** These two mnemonics catch the signals
   that answer most incidents:

   - **RED** (endpoints, handlers, jobs, queue consumers): **R**ate (throughput), **E**rrors (count
     and rate), **D**uration (latency distribution — percentiles, not just average).
   - **USE** (pools, queues, caches, workers, connections): **U**tilization, **S**aturation,
     **E**rrors. A set of `request_pool.*` gauges is a USE instrument for a DB connection pool.

   Prefer the APM library's automatic request metrics (`trace.flask.request.{hits,errors}` and the
   latency distribution) for per-endpoint RED before adding custom counters — custom metrics are for
   what auto-instrumentation can't see.

1. **Instrument — emit the signal.** Add the metric or span at the boundary that owns the question.
   Three idioms cover almost everything (full patterns in
   [references/instrumentation-checklist.md](references/instrumentation-checklist.md)):

   - **Counter / gauge / histogram** via `datadog.statsd` — for rates, levels, and distributions.
   - **Custom span** via `ddtrace` `tracer.trace(...)` — for a unit of work you want timed and
     breakable-out in a trace (serialization, validation, an external call).
   - **Span tag** via `span.set_tag(...)` — to enrich an existing span with a dimension you'll slice
     by (an id, a mode flag, an error count) without creating a new metric.

   A per-outcome counter for a background job. Shaped as a context manager so the outcome is
   resolved once, in `__exit__`, from whatever propagated — rather than a wrapper threading each
   branch by hand:

   ```python
   from contextlib import contextmanager
   from datadog import statsd

   class NothingToDo(Exception):
       """A job raises this to report an empty run — a success, not a failure."""

   @contextmanager
   def job_metrics(name, queue):
       tags = [f'job:{name}', f'queue:{queue}']
       statsd.increment('jobs.started', tags=tags)
       outcome = 'completed'
       try:
           yield
       except NothingToDo:
           outcome = 'empty'
       except Exception:
           outcome = 'failed'
           raise
       finally:
           statsd.increment(f'jobs.{outcome}', tags=tags)

   # at the call site
   with job_metrics('rebuild_index', queue='low'):
       rebuild_index()
   ```

   The outcome is decided by what reaches `__exit__`, and the single emit in `finally` fires on
   every path — including the re-raised failure — so no branch can forget to record its result.

   A custom span tagged with a dimension to slice by:

   ```python
   from ddtrace import tracer

   with tracer.trace('orders.serialize') as span:
       span.set_tag('include_items', include_items)
       return serialize_order(order, include_items=include_items)
   ```

1. **Protect the request path — metrics must never break the thing they measure.** Instrumentation
   runs inside the hot path. A metrics backend hiccup, a bad tag value, or a pool call that raises
   must not take down the request. Wrap emission so it degrades to silence, never to an exception:

   ```python
   # Guard every emission inline — telemetry must degrade to silence, never
   # raise into the request.
   try:
       statsd.gauge('request_pool.in_use', pool.active_count())
   except Exception:    # noqa: BLE001
       pass    # a metrics backend blip must not fail the request
   ```

   This guard wraps every pool/query metric emission. The same rule applies to span enrichment:
   guard a `current_span()` that may be `None` rather than letting a missing span raise. Observing a
   system must not change its availability.

1. **Control cardinality — it is the #1 cost and failure mode.** A tag's cost is the number of
   distinct values it can take, multiplied across every other tag (the combinatorial explosion is
   per time series). **Never tag with an unbounded or high-cardinality value** — raw SQL statements,
   user ids, request ids, full URLs, free-form error strings, timestamps. A query-error counter
   makes this concrete — count *that* a query failed, with no statement text on the tag. Tag with
   the bounded dimension instead: the normalized route, the job name, the error *class*, the status
   *code* — not the instance. When you need the high-cardinality detail, put it on a **span**
   (traces are sampled and keyed differently), not a metric tag. See
   [references/instrumentation-checklist.md](references/instrumentation-checklist.md#cardinality)
   for the allow/deny tag list.

1. **Alert on symptoms, not causes.** Page on what the user feels — elevated error rate, p95/p99
   latency past the SLO, a saturated pool that will soon reject work — not on every internal
   fluctuation (a brief CPU spike, a single slow query). Cause-level signals belong on dashboards
   for diagnosis *after* a symptom alert fires. Error monitors should use an **error rate**
   (errors/hits) with a recovery threshold, not an absolute count; latency monitors use **p95/p99**,
   not average. Every alert needs a recovery threshold so it resolves cleanly and doesn't flap. (The
   alert *declarations* live in Terraform and are the `datadog-audit` skill's domain — this step is
   about choosing the right signal to alert on, which only the person instrumenting the code knows.)

1. **Link the runbook.** An alert with no runbook is a 3am puzzle. Every symptom alert should point
   at a short runbook: what the signal means, the first diagnostic query, and the known
   remediations. If the runbook doesn't exist yet, the alert is not done.

## Naming and Tagging

- **Metric names:** lowercase, dot-namespaced, `noun.subject.measure` — `request_pool.in_use`,
  `jobs.failed`, `cache.hit`. Group a subsystem under a shared prefix so its signals sort together.
  Suffix with the unit when it isn't obvious: `..._seconds`, `..._bytes`.
- **Unified Service Tagging (UST):** rely on `env`, `service`, `version` coming from the deploy
  environment (`DD_ENV`/`DD_SERVICE`/`DD_VERSION`) — don't hand-tag them per call. `version`
  attribution (per-deploy slicing) only works once `DD_VERSION` is wired; confirm that before
  trusting per-version splits. (UST wiring itself is a `datadog-audit` concern.)
- **Tag keys** name a bounded dimension to slice by (`job`, `queue`, `name`, `operation`,
  `error_type`, `status_code`). The value must be bounded — see cardinality above.

## Red Flags

- A metric or dashboard widget no one can tie to an on-call question
- A tag whose value is a user id, request id, raw SQL, full URL, timestamp, or free-form string
- Metric emission on the request path with no exception guard — a backend blip can 500 the request
- An error monitor on an absolute count instead of a rate; a latency monitor on average instead of
  p95/p99
- An alert with no recovery threshold (it will flap) or no runbook link (it will stump on-call)
- Per-endpoint custom counters duplicating what APM request metrics already provide automatically
- A new external call or job with no span and no error counter — invisible when it fails
- Reaching for a metric tag to carry high-cardinality detail that belongs on a span

## Verification

After adding or changing instrumentation:

- [ ] Each new signal answers a stated on-call question (not "might be useful")
- [ ] Request-driven work has RED coverage; resources have USE coverage
- [ ] Every metric tag value is bounded — no ids, raw statements, URLs, or free-form strings
- [ ] All request-path emission is wrapped so a metrics failure degrades to silence, never an
  exception; span enrichment guards a possibly-`None` current span
- [ ] Metric names are dot-namespaced with units where non-obvious; UST (`env`/`service`/`version`)
  comes from the environment, not per-call tags
- [ ] New alerts target symptoms (error rate, p95/p99, saturation), carry a recovery threshold, and
  link a runbook
- [ ] Custom metrics/spans don't duplicate automatic APM request metrics
- [ ] Tests assert on emitted metrics where the signal is load-bearing (patch the statsd client and
  assert the call and its tags — see the testing pattern in
  [references/instrumentation-checklist.md](references/instrumentation-checklist.md#testing-instrumentation))
