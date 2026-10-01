# Hardening Patterns

Concrete patterns for the controls in `../SKILL.md`. Open the section you need when you reach that
code — don't read end to end. Examples are Python / bash; the principles are language-agnostic.

## Injection

Build queries with bound parameters, never string formatting:

```python
# WRONG — f-string interpolation is SQL injection
cur.execute(f"SELECT * FROM people WHERE email = '{email}'")

# RIGHT — bound parameters; the driver escapes
cur.execute("SELECT * FROM people WHERE email = %s", (email,))
```

Build subprocess calls as an argument list, never a shell string:

```python
# WRONG — shell=True + interpolation runs embedded shell metacharacters
subprocess.run(f"grep {pattern} {path}", shell=True)

# RIGHT — argument list, no shell
subprocess.run(["grep", "--", pattern, path], check=True)
```

In bash, quote every expansion and use `--` to end option parsing (see `shell-conventions.md`):

```bash
grep -- "${pattern}" "${path}"
```

## Broken Access Control

Authentication proves identity; authorization proves permission on the *specific* resource. Check
ownership on every request — never trust an ID from the client to be one the caller may touch (IDOR,
OWASP A01):

```python
def get_order(order_id: str, principal: Principal) -> Order:
    row = repo.get(order_id)
    if row is None or row.owner_id != principal.id:
        # Same 404 whether missing or forbidden — don't leak existence
        raise NotFound
    return row
```

## Broken Authentication

- Hash passwords with argon2 (preferred), scrypt, or bcrypt (≥12 rounds) via a maintained library —
  never a bare `hashlib` digest.
- Session/signing secrets come from the environment, never a literal in code.
- Sessions have a bounded lifetime and a server-side revocation path. For browser-facing cookies:
  `HttpOnly`, `Secure`, `SameSite=Lax` or `Strict`.

## Security Misconfiguration

Browser-facing services send security headers on every response and keep CORS to an explicit
allowlist from configuration:

- CSP from `default-src 'self'`, tightened — never loosened to `unsafe-inline` for convenience.
- HSTS, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` (or CSP `frame-ancestors`).
- CORS: an explicit origin list from config. **Never** `*` with credentials.

## Sensitive Data Exposure

Strip sensitive fields before serializing. Use an explicit output schema (allowlist) rather than
dumping the model:

```python
# RIGHT — the response schema names only what may leave the system
class PersonOut(BaseModel):
    id: str
    display_name: str
    # password_hash, reset_token, internal_notes intentionally absent
```

Error bodies are generic (`"internal error"` + a correlation id); the stack trace goes to server
logs, never to the caller.

## Schema Validation at Boundaries

Validate at the edge with a schema; downstream code uses only the parsed, typed value:

```python
class CreateOrder(BaseModel):
    product_id: str = Field(min_length=1, max_length=64)
    currency: Literal["usd", "eur"]
    items: list[LineItem]  # nested models validate recursively

def handler(raw: dict) -> Response:
    payload = CreateOrder.model_validate(raw)  # raises on bad input
    ...  # use payload.*, never raw[...]
```

Reject malformed input with a structured error and a 4xx. Never let the raw payload flow past the
boundary.

## File Upload Safety

- Allowlist the content type; don't trust the client-declared type or the extension.
- Cap the size before reading the whole body into memory.
- Verify content by magic bytes when the type matters (an image parser on a `.png` that is really a
  script).
- Store outside the web root; generate the stored name, never reuse the client's.

## Server-Side Request Forgery (SSRF)

Any user-influenced URL (webhook, import-from-URL, image proxy, link preview) can be aimed at
internal services or the cloud metadata endpoint (`169.254.169.254`):

- Allowlist scheme (`https` only) and host.
- Resolve **all** DNS records and reject any private/reserved address — loopback, link-local,
  private ranges, unique-local — for both IPv4 and IPv6.
- Forbid redirects (an allowlisted host can 302 to an internal one).

A gap remains: DNS rebinding can change the answer between the check and the connect (TOCTOU). For
high-risk surfaces, pin the resolved IP for the actual connection or front egress with a filtering
proxy.

## Destructive Operations on Derived Paths

A shape check (`path.endswith(".bak")`, a regex) proves well-formedness, not authorization. Require
all three before a delete/move/overwrite, and refuse rather than widen on failure:

```python
def safe_remove(target: str, allowed_root: Path) -> None:
    resolved = Path(target).resolve()          # symlinks + .. collapsed
    root = allowed_root.resolve()
    if not resolved.is_relative_to(root):      # 1. under the allowlisted root
        raise Refused(f"outside root: {resolved}")
    if resolved == root:                        # 2. strictly below the root
        raise Refused("refusing to operate on the root itself")
    st = resolved.lstat()                       # 3. ownership read BEFORE the op
    if st.st_uid != os.getuid():
        raise Refused(f"not owned by caller: {resolved}")
    resolved.unlink()
```

Two reasons the check is weaker than it reads:

- **Marker self-attestation.** A `.safe-to-delete` sentinel the target itself carries is written by
  whoever controls the target — it attests nothing an attacker couldn't forge. Ownership read from
  the filesystem is evidence; a marker inside the payload is not.
- **Check/use race (TOCTOU).** Between `resolve()` and `unlink()`, a symlink can be swapped. Where
  it matters, operate on a file descriptor opened with `O_NOFOLLOW` and re-`fstat` it, rather than
  re-resolving the path.

## Rate Limiting

Limit the API generally; limit auth strictly (~10 attempts / 15 min). The trap: an in-memory counter
multiplies by instance count once more than one process serves traffic, and never fires on
short-lived serverless workers. Back the limiter with a shared store (Redis, the database) keyed by
principal/IP so the limit is global, not per-process.

## Secrets Management

- Secrets come from the environment or a secrets manager — never a literal in code.
- In this repo: SOPS/age-encrypted files; the encrypted `*.enc.*` files and `.sops.yaml` are safe to
  read, the key material and the real project secret file are not
  (`security/env-file-protection.md`).
- Commit a placeholder example file with dummy values; keep the real one git-ignored.
- `grep` the staged diff for high-entropy strings / known key prefixes before committing.
- **A secret pushed to a remote is compromised the instant it lands.** Rotate first, then purge
  history — purging without rotating leaves a live secret in clones and caches.

## Dependency Audit Triage

When the native audit (`pip-audit`, `uv`'s audit, `safety`, `npm audit`, `bundler-audit`, …) reports
a finding:

1. **Reachable?** Is the vulnerable code on a runtime path, or only in build/test/dev tooling?
   Runtime critical/high is urgent; a dev-only advisory can be scheduled.
1. **Fix available?** A patched version within the declared range → upgrade and test. No fix →
   assess whether the vulnerable function is actually called; mitigate or pin, document the deferral
   with a review date.
1. **Never force-fix automatically.** `npm audit fix --force` and equivalents may jump across
   declared ranges and break callers. Preview, read the changelog, upgrade one at a time, test each.
1. **An audit is not a review.** It matches known advisories only. A newly malicious or typosquatted
   package passes a clean audit — review ownership, release age, maintenance, and the transitive
   graph when adding or bumping a dependency.

## Data Classification

Classify every field as you add it; the class drives handling, retention, and access:

| Class            | Examples                                 | Handling                                                   |
| ---------------- | ---------------------------------------- | ---------------------------------------------------------- |
| **Non-personal** | aggregate counts, feature flags, config  | Normal handling                                            |
| **PII**          | name, email, address, phone, account id  | Access-controlled, encrypted at rest, retention-limited    |
| **Sensitive**    | health (PHI), payment, biometric, gov id | Minimize/avoid; strict access + audit; dedicated retention |

You cannot protect, delete on request, or export data you cannot find. Design the schema so a
subject's data is locatable and erasable across primary store, backups, caches, search indexes, and
analytics copies.

## LLM Output Handling

Model output is untrusted input (OWASP LLM05). Treat it like any other boundary:

```python
# WRONG — model output straight into a dangerous sink
exec(model_reply)
cur.execute(model_reply)

# RIGHT — constrain, validate against a schema, then use the typed value
class ToolCall(BaseModel):
    action: Literal["lookup", "summarize"]
    arg: str = Field(max_length=200)

call = ToolCall.model_validate_json(model_reply)   # rejects anything off-schema
dispatch(call.action, call.arg)                     # never the raw string
```

- Prompt injection (LLM01): untrusted text in the context — a user message, a fetched page, a PDF, a
  tool result — can carry instructions. The system prompt is not a security boundary; enforce tool
  permissions in code and confirm destructive actions (LLM06).
- Keep secrets, other tenants' data, and the full system prompt out of the context window (LLM02,
  LLM07). Cap tokens, request rate, and recursion depth (LLM10). Partition RAG embeddings per tenant
  and validate documents before indexing (LLM08).
