---
name: api-idempotency-and-contracts
description: Make a service endpoint or outbound call safe to repeat, and treat its observable behavior as a contract once consumers exist. Use when designing or changing a POST/PUT endpoint, an outbound request that may be retried, request deduplication, a retry or replay path, or any response shape external callers depend on.
---

# API Idempotency and Contracts

A networked operation will be retried — by a client timeout, a load balancer, a message queue, your
own retry/replay logic. The only question is whether a retry is *safe*. An operation is idempotent
when running it twice has the same effect as running it once; everything below is about engineering
that property deliberately instead of hoping for it. The short closing section is the other half of
the same coin: once external callers observe your behavior, that behavior becomes a contract you
can't quietly change — including its idempotency.

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> re-idiomed from its web/Node origin to a Python-service surface (harvested from the upstream
> `api-and-interface-design` skill). The idempotency and Hyrum's-Law reasoning is upstream's; the
> examples are illustrative Python (Flask / `requests`) showing the two mechanisms that recur in
> practice — an outbound `Idempotency-Key` header and an inbound atomic claim keyed on that key. The
> source skill's HTTP One-Version-Rule / version-header and generic REST/pagination/PATCH/naming
> material is intentionally dropped.

## When to Use

- Designing or changing a `POST`/`PUT`/`PATCH` endpoint whose effect must not double on retry
- Adding or reviewing an outbound call that a retrying session may send more than once
- Building request deduplication, a replay path, or "has this already been processed?" logic
- Changing a response shape, status code, header, or error body that external callers may depend on
- Deciding what key to deduplicate on, and how to handle the "I don't know if it ran" case

## The Core Idea: Derive a Key From Intent

Idempotency needs a stable key that is the *same for a retry of the same intent* and *different for
a genuinely new operation*. Two ways to get one, and the two often coexist:

- **Caller-supplied / content-derived key.** Derive the key deterministically from the operation's
  meaningful content, not from a fresh UUID per attempt (a new UUID per attempt defeats the point —
  every retry looks new). A hash of the stable request content is a good key.
- **Resource identity.** When the operation targets one already-identified resource, the resource id
  *is* the natural key.

A key-builder picks between exactly these two, sending the key as an outbound HTTP header so the
downstream service can deduplicate:

```python
IDENTITY_FIELDS = ('resource_id',)        # if present, these alone identify the intent
INTENT_FIELDS = ('actor', 'action', 'target', 'amount')  # otherwise, what makes it "the same"

def idempotency_key(request_body: dict, resource_id: str | None) -> str:
    """One stable key per intent, identical across retries of that intent.

    A present resource id already names the intent, so it is the key verbatim.
    Otherwise, canonicalize the meaningful fields into an ordered, delimited
    string and hash that — a per-attempt UUID or timestamp is deliberately
    never part of the material.
    """
    if resource_id:
        return f'res:{resource_id}'
    parts = (f'{field}={request_body.get(field, "")}' for field in INTENT_FIELDS)
    canonical = '|'.join(parts)
    return 'sha:' + hashlib.sha256(canonical.encode()).hexdigest()


# at the call site — the key rides as a header on the outbound POST
headers = {'Idempotency-Key': idempotency_key(body, resource_id)}
response = session.post(url, json=body, headers=headers)
response.raise_for_status()
```

The key is derived from *what the request means*, so the retry a `requests` session fires after a
`502` carries the identical key and the downstream service collapses it. A per-attempt UUID would
not.

## The Workflow: Derive → Claim → Handle the Three Outcomes

1. **Derive the key from intent** (above). Deterministic from content, or the resource id. Never a
   fresh random value per attempt.

1. **Claim the operation atomically, before doing the work.** The lookup + decision must be a single
   atomic step so two concurrent retries can't both pass the check. The cleanest way to get
   atomicity for free is to make the key a **unique constraint** and let the database arbitrate: try
   to insert a claim row keyed on the idempotency key; exactly one racer wins the insert, the rest
   get a uniqueness violation and know a claim already exists:

   ```python
   def claim(key: str) -> bool:
       """Return True if THIS caller won the claim (first to insert), False if
       the key was already claimed. The DB's unique index is the arbiter — no
       read-then-write race."""
       try:
           db.execute(insert(Claims).values(key=key, state='in_progress'))
           db.commit()
           return True
       except UniqueViolation:
           db.rollback()
           return False
   ```

1. **Handle the three outcomes — success, failure, and *unknown* — distinctly.** The outcome that
   sinks naive implementations is the third: a prior attempt that is recorded but *not known to have
   succeeded*. Treating "seen before" as a flat "it's a duplicate, reject" is wrong — it strands
   failed and in-flight attempts forever. A correct duplicate check is status-aware and allows a
   retry when the prior attempt did not reach a terminal success:

   ```python
   def resolve(key: str) -> tuple[str, object]:
       """Map a key to one of three outcomes. The caller dispatches on the
       first element; the ladder-of-ifs is replaced by one lookup + a match."""
       if current_app.config.get('ALLOW_DUPLICATE_REQUESTS'):
           return ('run', None)                 # operator override: always reprocess

       row = Claims.get(key)
       match row:
           case None:
               return ('run', None)             # unclaimed — do the work
           case _ if row.state == 'succeeded' and row.result is not None:
               return ('return_cached', row.result)
           case _:
               return ('run', None)             # claimed-but-not-succeeded → retry

   # at the call site, dispatch on the outcome
   action, payload = resolve(key)
   if action == 'return_cached':
       return payload                            # prior success — don't redo the work
   do_the_work(key)                              # 'run' covers new AND failed/in-flight
   ```

   The three outcomes:

   - **New** (no claim row, or operator override) → `run` the work.
   - **Succeeded** (claim `state == 'succeeded'` with a stored result) → `return_cached`: hand back
     the *prior* result, so the caller gets the same answer a first call would have, which is what
     idempotency promises.
   - **Unknown / failed** (claimed, but not succeeded) → `run` the retry rather than rejecting it. A
     claimed-but-unsuccessful attempt must be re-runnable, or a transient failure becomes permanent.

1. **Provide an operator escape hatch, scoped and loud.** A config flag like
   `ALLOW_DUPLICATE_REQUESTS` that forces reprocessing is useful for backfills and incident
   recovery. Keep such a hatch explicit and off by default; it bypasses the safety property, so it
   belongs behind config, not a request parameter any caller can set.

## Contracts: Hyrum's Law

> With a sufficient number of users of an API, it does not matter what you promise in the contract:
> all observable behaviors of your system will be depended on by somebody.

Once a service has external consumers, **every observable behavior is a de-facto contract** — not
just the documented response schema, but status codes, error-body shape, header presence, ordering,
and the idempotency/dedup behavior above. A service consumed by several independent clients is a
genuine Hyrum's-Law environment: a change that looks internal can break a caller who quietly came to
rely on a behavior you never meant to promise.

Practical consequences when you touch an endpoint or outbound call:

- **The dedup/idempotency behavior is itself a contract.** Callers build retry logic around "a
  resubmit is safe / returns the prior result." Changing *when* you treat something as a duplicate,
  or what a duplicate returns, is a breaking change even though no schema changed. Don't alter it
  silently.
- **Error shape is part of the contract.** The structured error body (its field names, nesting, and
  types) is parsed by consumers. Adding a field is usually safe; renaming, removing, or changing the
  type of an existing one is breaking.
- **Prefer additive change.** New optional fields and new endpoints don't break existing callers;
  removing or re-typing does. When a breaking change is genuinely needed, it is a coordinated,
  announced change — not a quiet edit.
- **Don't rely on undocumented behavior you don't intend to keep.** The flip side: if a behavior is
  incidental (insertion-order of a list, a tolerated-but-unspecified input), either specify it or
  deliberately vary it early, before consumers calcify it into a contract.

## Red Flags

- A fresh UUID (or timestamp) minted per attempt as the "idempotency key" — every retry looks new
- A duplicate check that treats *any* prior sighting as a hard reject — strands failed/in-flight
  attempts, turning a transient failure permanent
- The success case re-does the work instead of returning the prior result
- The key lookup and the "process it" decision are separate, non-atomic steps — two concurrent
  retries both pass
- No escape hatch for backfills/recovery, or an escape hatch exposed as a request parameter instead
  of operator config
- Silently changing a response shape, status code, error body, or dedup behavior on a consumed
  endpoint — a breaking change wearing an "internal refactor" label
- An idempotency key built from unstable content (wrapper ids, timestamps, request-order) so genuine
  retries don't collide

## Verification

When adding or changing idempotency/dedup or a consumed endpoint:

- [ ] The key is derived deterministically from intent (content hash or resource id), identical
  across retries of the same operation
- [ ] The claim/lookup is atomic — concurrent retries can't both pass the "not seen" check
- [ ] All three outcomes are handled: new → process; succeeded → return prior result; unknown/failed
  → allow retry
- [ ] Any force-reprocess escape hatch is operator-scoped config, off by default, not
  caller-settable
- [ ] Response shape, status codes, error body, and dedup behavior on consumed endpoints are
  unchanged — or the change is additive, or coordinated/announced as breaking
- [ ] Tests cover the retry-of-a-success and the retry-of-a-failure paths, not just the first call
