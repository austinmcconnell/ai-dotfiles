# Instrumentation Checklist

Load this file when deciding **what to instrument** on a new endpoint, job, cache, or external call,
or when checking a tag for cardinality risk. The SKILL.md body carries the workflow and short
snippets; this file carries the decision tables and the longer patterns.

## What to Instrument (by surface)

| Surface                        | Signal (method)   | Concretely                                                                 |
| ------------------------------ | ----------------- | -------------------------------------------------------------------------- |
| HTTP endpoint / handler        | RED               | Rate + errors from APM request metrics; latency distribution (p95/p99)     |
| Scheduled / background job     | RED               | Counter per outcome (started/completed/failed/skipped), tagged job + queue |
| Queue consumer                 | RED + USE         | Processed/failed counters; queue depth gauge; consumer lag                 |
| Connection pool                | USE               | checked_out / size / checked_in / overflow gauges; in-use-time histogram   |
| Cache layer                    | RED + USE         | hit / miss / error counters tagged by cache name; hit-rate derivable       |
| External API / downstream call | RED               | Custom span around the call; error counter by error class; timeout counter |
| Serialization / validation     | Duration          | Custom span (`tracer.trace`) with a dimension tag to slice slow cases      |
| DB query (aggregate)           | Duration + Errors | Query-time histogram; query-error counter — **no per-statement tag**       |

Prefer the APM library's automatic per-endpoint request metrics
(`trace.<framework>.request.{hits,errors}` + the latency distribution) for endpoint RED before
hand-rolling counters. Custom metrics are for what auto-instrumentation can't see.

## Cardinality

The decisive rule when choosing a tag. A metric's cost is one time series per *combination* of tag
values; one unbounded tag multiplies the whole metric without limit and is the most common way a
metrics bill or a backend falls over.

### Safe tag values (bounded — allow)

- Normalized route / resource name (`get_/v2/orders/_order_id`, not the id-filled URL)
- Job name, queue name, worker pool name, cache name
- HTTP status *code* (`200`, `404`, `500`) or status *class* (`2xx`, `5xx`)
- Error *class* / *type* (`connection`, `timeout`, `serialization`) — a bounded enum
- A boolean / small-enum mode flag (`include_items:true`, `operation:read`)
- UST: `env`, `service`, `version` (bounded by deploys — and these come from the environment)

### Unsafe tag values (unbounded — deny on metrics)

- User id, person id, provider id, account id, session id
- Request id / trace id / correlation id
- Raw SQL statement or query text
- Full URL or path with ids / query strings embedded
- Free-form error message or exception string
- Timestamps, durations, or any continuously-varying value
- Email, filename, or any user-supplied free text

**When you need the high-cardinality detail**, put it on a **span tag**, not a metric tag. Traces
are sampled and indexed differently, so a `customer_id` on a span is queryable within trace
retention without creating a metric time series per user. This is the split to aim for:
`database.query.*` metrics carry **no** statement tag (unbounded), while a request-handling span can
carry `orders.customer_id` via `set_tag` because that lives on a sampled trace.

## Patterns

### Request-path safety guard

Metrics code runs inside the hot path; it must degrade to silence, never raise.

```python
# Guard every emission inline — telemetry must degrade to silence, never raise.
try:
    statsd.gauge('request_pool.in_use', pool.active_count())
except Exception:    # noqa: BLE001
    pass    # a metrics backend blip must not fail the request
```

For span enrichment, guard a possibly-missing current span rather than assuming one is active:

```python
span = tracer.current_span()
if span:
    span.set_tag('orders.customer_id', customer_id)
```

### USE instrument via pool lifecycle callbacks

Hook the pool's lifecycle so the instrument stays correct without touching call sites. The point is
the *signals* (gauges on acquire/release, a hold-time histogram, an error counter) and the
cardinality rule — not the specific wiring, which varies by pool library:

```python
def on_acquire(record):
    record.acquired_at = now()
    try:
        statsd.gauge('request_pool.active', pool.active_count())
    except Exception:    # noqa: BLE001
        pass

def on_release(record):
    held = now() - record.acquired_at
    try:
        statsd.histogram('request_pool.held_seconds', held)
    except Exception:    # noqa: BLE001
        pass

def on_query_error(_err):
    # Count that a query failed — never tag with the statement text, which is
    # unbounded cardinality.
    try:
        statsd.increment('request_pool.query_errors')
    except Exception:    # noqa: BLE001
        pass
```

### Custom span with a slice dimension

Open a span around a unit of work you want timed and breakable-out in the trace, tagging it with the
bounded dimension you'll slice slow cases by:

```python
with tracer.trace('schema.validate_response') as span:
    errors = list(validator.iter_validation_errors(request, response))
    span.set_tag('schema.validation_errors', len(errors))
```

### Dropping noise traces

Not every span is worth keeping. Drop expected-noise traces (health probes, readiness checks) with a
`TraceFilter` so they don't inflate your error-rate metric during normal operation:

```python
class DropNoiseTraces(TraceFilter):
    NOISE_PREFIXES = ('GET /status', 'GET /ping')

    def process_trace(self, trace):
        if any(s.resource and s.resource.startswith(self.NOISE_PREFIXES) for s in trace):
            return None    # drop
        return trace

tracer.configure(trace_processors=[DropNoiseTraces()])
```

## Testing Instrumentation

Where a signal is load-bearing (an alert fires on it, or an incident depended on it), assert it is
emitted. Patch the statsd client and assert the call:

```python
@patch('jobs.metrics.statsd')
def test_emits_failure_on_exception(self, mock_statsd):
    with pytest.raises(RuntimeError):
        with job_metrics('rebuild_index', queue='low'):
            raise RuntimeError('boom')
    mock_statsd.increment.assert_any_call('jobs.failed', tags=['job:rebuild_index', 'queue:low'])
```

Assert the *tags* too, not just the metric name — a correct metric with a wrong or unbounded tag is
the bug this catches.
