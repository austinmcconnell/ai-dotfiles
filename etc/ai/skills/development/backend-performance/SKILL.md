---
name: backend-performance
description: Optimize backend service performance with a measure-first discipline — fix the proven bottleneck, verify it paid off, and revert what didn't. Use when a service or endpoint is slow, when you suspect an N+1 query, when a connection pool is exhausted, when deciding whether to add an index or a cache, or when a performance change needs to be justified by before/after numbers.
---

# Backend Performance

Measure before optimizing. Performance work without measurement is guessing, and guessing leads to
premature optimization that adds complexity without improving what matters. Profile first, find the
actual bottleneck, fix that one thing, measure again, and keep the change only if the number moved.

This skill is the backend half of a performance discipline: database queries, connection pools,
caching, and the measure→fix→verify loop that governs all of them. It pairs with the always-on
`code-health.md` steering (static structural health — function length, cohesion, brain methods) and
the `observability-and-instrumentation` skill (the metrics and spans you *measure with* here).
`code-health.md` is about code that is easy to change; this skill is about code that is fast at
runtime — different axes, both needed.

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> re-idiomed from its web/Node origin to a Python-service surface and scoped to the backend. The
> measure→fix→verify reasoning and the anti-pattern catalogue are upstream's; the frontend half of
> the source skill (Core Web Vitals, bundles, render performance) is intentionally dropped because
> this is a backend-service context. Examples are illustrative Python/SQL, not drawn from any
> company project.

## When to Use

- A service, endpoint, or job is slow, or monitoring reports elevated latency
- You suspect an N+1 query pattern in data fetching or serialization
- Every endpoint slows at once and connections pile up — a connection-pool question
- You're about to "add an index" or "just cache it" and want to do it on evidence, not reflex
- A performance change needs to be justified, kept, or reverted on before/after numbers

**When NOT to use:** don't optimize before you have evidence of a problem. Premature optimization
adds complexity that costs more than the performance it buys. No measurement, no change.

## The Optimization Workflow

```text
1. MEASURE  → Establish a baseline with real data
2. IDENTIFY → Find the actual bottleneck (not the assumed one)
3. FIX      → Address that specific bottleneck
4. VERIFY   → Measure again; keep or revert
5. GUARD    → Add a test or monitor so the regression can't come back
```

### Step 1 — Measure

Establish a baseline before touching anything. For a backend service, the signals that matter are
response time (percentiles, not just the mean), the per-request query count and query time, and
resource saturation (connection pool, CPU, memory). Use whatever the service already emits — APM
latency distributions, DB query logging with timing, pool gauges — before adding ad-hoc timing.

Use the symptom to decide what to measure first:

| Symptom                       | Measure first                                                            |
| ----------------------------- | ------------------------------------------------------------------------ |
| One endpoint slow             | Its database queries (count + time) and whether an index is used         |
| *Every* endpoint slow at once | The connection pool — saturation and time spent waiting for a connection |
| Intermittent slowness         | Lock contention, GC pauses, a slow external dependency                   |
| Memory growth over time       | Unbounded caches, leaked references, oversized payloads                  |

### Step 2 — Identify the Bottleneck

Common backend bottlenecks and how to confirm each:

| Symptom                     | Likely cause                                            | How to confirm                                                     |
| --------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| Slow single endpoint        | N+1 queries, a missing/unused index, an unbounded fetch | Count queries per request; read the query plan                     |
| All endpoints slow together | Connection-pool exhaustion                              | Time spent waiting for a connection; DB shows mostly idle sessions |
| High latency on a hot read  | Missing cache, redundant recomputation                  | Measure the cost of the operation and its read:write ratio         |
| Memory growth               | Leaked refs, unbounded cache, large payloads            | Heap snapshot; check cache eviction                                |

Confirm the bottleneck with a number before fixing it. "This is probably the slow part" is a
hypothesis, not a measurement.

### Step 3 — Fix the Anti-Pattern

#### N+1 queries

One query to load a list, then one more per row to load a relationship — the query count grows with
the data instead of staying constant.

```python
# BAD: N+1 — one query for the list, then one per task for its owner
tasks = Task.query.all()
for task in tasks:
    task.owner  # lazy load → one SELECT per task

# GOOD: eager-load the relationship in a single round trip
tasks = Task.query.options(joinedload(Task.owner)).all()
```

**The trap that defeats eager loading: a commit before serialization.** Many ORMs expire all loaded
attributes on commit (SQLAlchemy's `expire_on_commit=True` is the default). After the commit, every
relationship access re-fires as an individual lazy load — so model-level `joined`/`selectin` loading
strategies, which only apply *at query time*, give zero benefit on the post-commit read. The symptom
is an endpoint that writes and then serializes the result exploding into hundreds of queries while a
read-only endpoint for the same object is fine.

```python
# BAD: commit expires the instance, then serialization lazy-loads every relationship
obj = Model.query.get(obj_id)
update(obj)
db.session.commit()          # expires obj and all its relationships
return serialize(obj)        # N+1 storm: each relationship access is a fresh SELECT

# GOOD: re-load with explicit eager options AFTER the commit, for the read you serialize
db.session.commit()
obj = Model.query.options(
    joinedload(Model.children).selectinload(Child.grandchildren)
).get(obj_id)
return serialize(obj)
```

Eager-load for the *shape of the read you actually serialize*, not reflexively everywhere — eager
loading a relationship you don't render just moves wasted work into the first query.

#### Unbounded data fetching

```python
# BAD: load every row into memory
rows = Record.query.all()

# GOOD: paginate with an explicit limit and a deterministic order
rows = (Record.query
        .order_by(Record.created_at.desc())
        .limit(page_size)
        .offset((page - 1) * page_size)
        .all())
```

#### Read the query plan before adding an index

"Add an index" is the guess. The query plan is the measurement. Read it *before* and *after*:

```sql
EXPLAIN ANALYZE
SELECT id, title FROM tasks
WHERE owner_id = 42
ORDER BY created_at DESC
LIMIT 20;
```

Three things in the output decide the fix:

| What you see                                               | What it means                                                                      |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `Seq Scan` on a large table where you expected an index    | No usable index for this predicate                                                 |
| Estimated `rows=` off from actual by an order of magnitude | Stale statistics; the planner is choosing on bad information (`ANALYZE` the table) |
| A `Sort` node above the scan                               | The index covers the filter but not the `ORDER BY`                                 |

Index for the **shape of the query**, not a column in isolation. In a composite index, equality
columns come first, then the range or sort column:

```sql
CREATE INDEX idx_tasks_owner_created ON tasks (owner_id, created_at DESC);
```

**When an index will not help:**

| Situation                                                                                     | Why                                                                                                                                                   |
| --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Low selectivity on the dominant value (a `status` that is 95% `active`, filtered on `active`) | A sequential scan is genuinely cheaper; the planner ignores the index. Filtering on the *rare* value is the opposite — a partial index serves it well |
| Leading wildcard (`LIKE '%term'`)                                                             | A B-tree can't seek without a prefix; needs trigram or full-text                                                                                      |
| Function on the column (`WHERE lower(email) = ?`)                                             | The plain column index is unusable; index the expression instead                                                                                      |
| Write-heavy table                                                                             | Every index taxes every `INSERT`/`UPDATE`; weigh the write cost, not just the read gain                                                               |

Re-run `EXPLAIN ANALYZE` after. An index that didn't change the plan is a revert (Step 4) — and it
isn't free, it still costs on every write.

#### Connection-pool exhaustion

The signature is distinctive: **every** endpoint slows at once, the slow time is spent *waiting for
a connection* rather than executing a query, and the database reports mostly idle sessions.

```python
# BAD: a pool per request or per worker that multiplies without bound —
# instances × pool size can blow past the database's connection ceiling

# GOOD: one pool per process, sized against the database's ceiling
engine = create_engine(
    url,
    pool_size=5,          # steady connections per process
    max_overflow=2,       # burst headroom; instances × (pool_size+overflow) < max_connections
    pool_timeout=10,      # fail fast instead of queueing forever
    pool_pre_ping=True,   # drop dead connections before handing them out
)
```

Do the arithmetic explicitly: `instance_count × (pool_size + max_overflow)` must stay under the
database's `max_connections`, with headroom for other clients. Under autoscaling, instance count is
the variable that surprises you — a pool that's safe at 4 instances exhausts the database at 25.

**Bigger is not faster.** A pool larger than what the database can execute concurrently just moves
the queue from your app to the database, where it's harder to see. When instance count is unbounded
(autoscaling), a proxy that multiplexes connections (pgbouncer, RDS Proxy) is the fix, not a higher
`max`. Raising the pool size in response to exhaustion, without finding what *holds* connections, is
the classic non-fix.

#### Caching — cache what is expensive and re-read far more than it changes

Caching a call that was already cheap buys nothing and adds a staleness bug, a network hop, and an
eviction policy to maintain. Cache deliberately.

**Pick the layer:**

| Layer                     | Visible to        | Use when                                                     | Cost                                                |
| ------------------------- | ----------------- | ------------------------------------------------------------ | --------------------------------------------------- |
| In-process (`dict`, LRU)  | One instance      | Small, hot, per-instance staleness acceptable                | Each instance drifts; invalidation reaches only one |
| Shared (Redis, Memcached) | All instances     | Instances must agree, or the value is expensive to recompute | A network hop and another service to run            |
| CDN / edge                | Everyone, per key | Responses are public and identical for a key                 | Invalidation is the hard part                       |

**Key design decides correctness.** Every input that changes the response belongs in the key:
tenant, user, locale, permissions, feature flags. A key that omits the viewer is how one user's data
gets served to another — and it ships as a "performance win."

```python
# BAD: key omits the viewer — different users collide on one entry
key = f'dashboard:{report_id}'

# GOOD: every input that changes the response is in the key
key = f'dashboard:{tenant_id}:{user_id}:{report_id}:{locale}'
```

**Choose one invalidation strategy, not three:**

| Strategy                              | Trade-off                                                                               |
| ------------------------------------- | --------------------------------------------------------------------------------------- |
| TTL                                   | Simplest; you accept staleness up to the TTL, so state the acceptable window explicitly |
| Event / tag based                     | Fresh on write, but writers must now know the cache topology                            |
| Versioned keys (`user:42:profile:v7`) | Never invalidate, just stop reading old keys; costs memory until eviction               |

**Guard against the stampede.** A hot key expires, every concurrent request misses together, and the
origin takes the full load at once — the cache becomes an outage instead of preventing one. Coalesce
concurrent misses behind a single in-flight recompute (single-flight), or serve stale while one
request refreshes:

```python
def get_or_fetch(key, fetch_func, ttl):
    cached = cache.get(key)
    if cached is not None:
        return cached
    # Single-flight: one caller acquires the lock and recomputes; the rest
    # wait for the populated value instead of all hammering the origin.
    if cache.acquire_lock(key, ttl=LOCK_TTL):
        try:
            value = fetch_func()
            cache.set(key, value, ttl=jittered(ttl))  # jitter TTL to desync expiries
            return value
        finally:
            cache.release_lock(key)
    return cache.wait_for(key, fetch_func)  # others read the filled value
```

A circuit breaker around the cache client (skip the cache and go straight to the origin after N
consecutive errors) keeps a cache outage from becoming a service outage. **Do not cache** anything
whose staleness is a correctness bug (balances, permissions, inventory at checkout).

### Step 4 — Verify (Keep or Revert)

A fix is a hypothesis until you re-measure. This step decides whether it survives.

- **Re-measure the way you measured the baseline** — same query, same conditions, same fixed budget.
  A baseline on a cold cache against a result on a warm one measures the cache, not your change.
- **Change one thing at a time.** Three optimizations landed together produce one number you can't
  attribute. If they must ship together, measure each in isolation first.
- **Beat the noise, not just the mean.** Repeat and compare the delta against run-to-run variance. A
  3% gain inside ±5% variance is a different sample, not a win.

Then decide, strictly:

| Result vs. baseline                 | Action                                                     |
| ----------------------------------- | ---------------------------------------------------------- |
| Past the threshold, tests green     | **Keep.** Commit with before/after numbers in the message. |
| Within noise (no measurable change) | **Revert.**                                                |
| Worse                               | **Revert.**                                                |
| Improved, but a test went red       | **Revert** — a regression wearing a win's clothing.        |

**"Neutral" is a revert, not a keep.** This is the step teams skip: the change is already written,
throwing it away feels wasteful, so it lands unmeasured and the codebase accretes complexity that
never bought anything. Code you keep, you maintain forever — make it pay for itself.

**Correctness gates the metric.** An "optimization" that wins by dropping work the product needed —
skipping a validation, caching something that must be fresh, removing a load-bearing `await` — is a
regression, not a win. The suite stays green *and* the number moves.

#### Log every attempt, including the reverted ones

Reverted work leaves no trace in git history, which is exactly why the same dead idea gets retried
next quarter. Keep a short ledger so a discarded idea stays discarded:

| Idea                                | Baseline → Result | Verdict  | Why                                                              |
| ----------------------------------- | ----------------- | -------- | ---------------------------------------------------------------- |
| Add index on `tasks(status)`        | 180ms → 178ms     | reverted | 95% of rows are `active`; planner ignores it, write cost remains |
| Eager-load owners in the list query | 420ms → 90ms      | kept     | N+1 gone; one query instead of 1+N                               |
| Cache the config lookup             | 12ms → 12ms       | reverted | Already fast; added a staleness bug for nothing                  |

A section in the PR description or a `PERF.md` both work. What matters is the next person (or agent)
reads it before re-running an experiment that already failed.

### Step 5 — Guard Against Regression

Guard the metric the user actually feels — p95/p99 latency, the per-request query count — not every
available number. Two complementary layers:

- **Test gate:** a test that fails if the query count or latency for a known path regresses past a
  budget. Compare a median/trend so normal variance doesn't make it flaky.
- **Field monitoring:** alert on a meaningful p95/p99 movement in production (this is where the
  `observability-and-instrumentation` skill's metrics and the `datadog-audit` monitors come in).

When a guard fires, return to Step 1 and establish a fresh baseline before proposing another fix.

## Common Rationalizations

| Rationalization                                         | Reality                                                                                                                           |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| "We'll optimize later"                                  | Performance debt compounds. Fix obvious anti-patterns now, defer micro-optimizations.                                             |
| "It's fast on my machine"                               | Your machine isn't production. Profile against representative data volumes and latency.                                           |
| "The ORM handles performance"                           | ORMs prevent some issues but will happily emit an N+1 and ignore an index.                                                        |
| "The query is slow, add an index"                       | Read the plan first. The index may already exist and be unusable, and every index taxes writes forever.                           |
| "Just cache it"                                         | Caching an already-cheap call buys nothing and adds a staleness bug. Cache what is expensive *and* re-read far more than written. |
| "Raise the pool size, we're running out of connections" | A pool bigger than the database can serve moves the queue somewhere less visible. Find what holds connections.                    |
| "It didn't help much, but it doesn't hurt"              | Neutral changes are a revert. You pay maintenance on them forever and got nothing back.                                           |
| "The improvement is obvious, no need to re-measure"     | Then re-measuring is cheap and proves it. Unmeasured wins are how neutral complexity lands.                                       |

## Red Flags

- Optimization without a before measurement to justify it
- N+1 query patterns in data fetching or serialization — especially a relationship accessed after a
  commit that expired the instance
- An index added without a query plan before and after to justify it
- A cache key that omits an input the response depends on (tenant, locale, viewer)
- A cache with no stated staleness window and no invalidation strategy
- A hot cache key with no stampede protection (no single-flight, no stale-while-revalidate)
- Connection-pool size raised in response to exhaustion, without finding what holds connections
- List endpoints without pagination
- Several optimizations bundled into one measurement, so no single change can be attributed
- A "win" that required a test to be changed, skipped, or deleted
- The same failed optimization attempted twice because nobody recorded the first attempt

## Verification

After any backend performance change:

- [ ] Before and after measurements exist (specific numbers), taken the same way
- [ ] The improvement exceeds run-to-run variance, not just the mean
- [ ] Changes that didn't beat the baseline were reverted, not kept as neutral
- [ ] Attempts are logged, kept and reverted alike, so a dead idea isn't re-run
- [ ] The specific bottleneck is identified and addressed, not an assumed one
- [ ] No N+1 queries in new data-fetching or serialization code (check the post-commit read path)
- [ ] Any new index is justified by a query plan before and after, and its write cost was considered
- [ ] Any new cache states what it keys on, how it goes stale, and how it survives a stampede
- [ ] Connection-pool sizing math (`instances × (pool_size + overflow) < max_connections`) still
  holds
- [ ] The measured metric has a test budget or field monitor that can detect the regression
- [ ] Existing tests still pass — the optimization didn't change behavior
