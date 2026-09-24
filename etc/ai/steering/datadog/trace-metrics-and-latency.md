# Trace Metrics & Latency Querying (generic)

Reusable know-how for querying APM request latency via pup, applicable to any ddtrace web service.
The integration name varies (flask/express/rails/gin/…); the patterns don't. Project-specific values
(concrete metric names, monitor thresholds, DD_VERSION milestones, timeout values) belong in that
project's analysis notes or engram, NOT here.

## Percentiles vs max: distribution vs gauge

- Percentiles (p50–p99) come from the DISTRIBUTION metric `trace.<integration>.request` (e.g.
  `trace.flask.request`, `trace.express.request`). This is what a p95 latency monitor queries:
  `percentile(last_5m):p95:trace.<integration>.request{...}`.
- `trace.<integration>.request.duration` is a GAUGE — avg/min/max/sum only. `p95:` on it returns an
  EMPTY series with NO error. Use it for MAX; use the base metric for percentiles.
- Related: `trace.<integration>.request.hits` / `.errors` (counts; availability = (hits −
  errors)/hits), `.apdex`.

## resource_name has two forms (metric vs trace)

- METRIC queries: underscore, method-prefixed — `get_/v2/foo`, `put_/v2/foo/_id`.
- TRACE queries: method + space + raw path — `GET /v2/foo`, `PUT /v2/foo/<id>`.
- Using the wrong form silently returns zero results. Discover the real values by grouping:
  `by {resource_name}` (metrics) or `--group-by resource_name` (traces) over a short window.

## Triage: split an endpoint's tail by status code BEFORE concluding it's "slow"

```bash
pup traces aggregate --read-only --query='service:S resource_name:"GET /path"' \
  --compute='percentile(@duration, 95)' --group-by='@http.status_code' --from=7d
```

Aggregate p95/max routinely HIDE that the tail is a status CLASS with its own root cause — e.g. slow
auth-path 401s, or timeout 500s — distinct from the happy-path 200 latency. Often the single most
clarifying query in a latency investigation.

## Custom span tags & retention

- App-emitted tags usually live on CHILD spans (a serialize/db/render span), not the root request
  span; query them as facets (`@tagname`) via `pup traces`.
- Trace/span data: ~15-day retention. Trace-generated METRICS: ~15 months. A custom span tag with no
  corresponding span-based metric is only reachable via `pup traces` within the ~15d window — past
  that it's gone.

## version attribution caveats

- Per-`version` splits are only reliable once DD_VERSION is wired for the service; before that,
  attribute by deploy-timestamp correlation and flag it. Derive deploy timestamps from
  `... by {version}` first/last-seen per version.
- A version-tagged latency change can be CLIENT-driven: a caller-side change gets stamped with
  whatever SERVER version was live at the time. Before crediting a server release for a latency
  shift, check whether a consumer/client repo deployed a coincident change.

## Diagnostic heuristics

- Clustered near-identical max durations (many requests at ~the same ceiling) => a TIMEOUT
  (statement/gunicorn/proxy), not organic latency. Find the matching timeout config value.
- `pup traces aggregate` over wide or high-traffic windows intermittently 408-times-out; narrow the
  window (per-day/per-hour) and retry.

## Optional local harness

A project may keep a git-ignored `analysis/datadog/latency-query.py` wrapping these patterns (p95 /
max / service-p95 / version / availability / status-split). Local artifact, not shared.
