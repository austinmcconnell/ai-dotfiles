---
name: security-and-hardening
description: Harden code against vulnerabilities with a threat-model-first workflow. Use when handling untrusted input, authentication, authorization, data storage, secrets, or external integrations; when building a feature that accepts untrusted data or calls a third-party service; when a delete/move/overwrite targets a derived path; when auditing dependencies or triaging a package-manager audit; when an LLM/model output feeds code; or when personal data or privacy compliance (GDPR, CCPA) is involved.
---

# Security and Hardening

Treat every external input as hostile, every secret as sacred, and every authorization check as
mandatory. Security is a constraint on every line that touches untrusted data, authentication, or
external systems — not a phase bolted on at the end.

This skill is the on-demand *workflow* tier. The always-on *principles* tier is the
`security/best-practices.md` steering doc (the short "never hardcode secrets / parameterize queries
/ validate input" list loaded for the `code` agent). Reach here for the threat-model process, the
boundary system, and the per-control patterns; the steering doc remains the standing summary.

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> re-idiomed from its web/Node origin to this repo's Python-service / bash / infra surface. The
> language-agnostic security reasoning is upstream's; the examples are rewritten.

## When to Use

- Building anything that accepts user input, a request body, a file, or a webhook
- Implementing or changing authentication / authorization
- Storing or transmitting sensitive data (PII, payment, credentials)
- Integrating with an external API, queue, or callback
- A destructive filesystem operation (delete/move/overwrite) whose target is derived from input
- Auditing dependencies, triaging an audit finding, or vetting a new package
- Any feature that calls an LLM or consumes model output
- Any feature that collects, stores, or shares personal data

## Process: Threat Model First

Controls bolted on without a threat model are guesses. Before hardening, spend five minutes thinking
like an attacker — this is OWASP **A04: Insecure Design**, where most breaches begin:

1. **Map the trust boundaries.** Where does untrusted data cross into the system? HTTP requests,
   form fields, file uploads, webhooks, third-party APIs, message queues, **and LLM output** — plus
   the local values that *look* internal because the OS handed them over: another process's command
   line or environment, filenames on a shared volume, a path in a job payload. **Trust follows who
   *wrote* a value, not which channel delivered it.** Every boundary is attack surface.

1. **Name the assets.** What is worth stealing or breaking? Credentials, PII, PHI, payment data,
   admin actions, money movement, the integrity of a data pipeline.

1. **Run STRIDE over each boundary** — a quick lens, not a ceremony:

   | Threat                     | Ask                                        | Typical mitigation                           |
   | -------------------------- | ------------------------------------------ | -------------------------------------------- |
   | **S**poofing               | Can someone impersonate a user/service?    | Authentication, signature verification       |
   | **T**ampering              | Can data be altered in transit or at rest? | Integrity checks, parameterized queries, TLS |
   | **R**epudiation            | Can an action be denied later?             | Audit logging of security events             |
   | **I**nformation disclosure | Can data leak?                             | Encryption, field allowlists, generic errors |
   | **D**enial of service      | Can it be overwhelmed?                     | Rate limiting, input size caps, timeouts     |
   | **E**levation of privilege | Can a user gain rights they shouldn't?     | Authorization checks, least privilege        |

1. **Write abuse cases next to use cases.** For each feature, ask "how would I misuse this?" — then
   make that your first test.

If you can't name the trust boundaries for a feature, you are not ready to secure it.

## The Three-Tier Boundary System

### Always Do (No Exceptions)

- **Validate all external input** at the system boundary (request handlers, task entry points, CLI
  arg parsing) with a schema — allowlist the shape, lengths, enums, formats.
- **Parameterize all database queries** — never build SQL/NoSQL from input strings. Never build a
  shell command from input strings; pass an argument list, not a formatted string.
- **Encode output** for its sink (HTML, shell, SQL, a file path) — never trust auto-escaping you
  bypassed.
- **Use TLS** for all external communication.
- **Hash passwords** with argon2/scrypt/bcrypt (never store plaintext, never a bare hash).
- **Pull secrets from the environment or a secrets manager**, never from code or the repo.
- **Run the detected package manager's native audit** against the committed lockfile before every
  release.

### Ask First (Requires Human Approval)

- New authentication flows or changes to auth logic
- Storing a new category of sensitive data (PII, payment, PHI)
- A new external service integration
- Changing CORS or network-egress configuration
- Adding a file-upload or webhook handler
- Modifying rate limiting or throttling
- Granting elevated permissions or roles

### Never Do

- **Never commit secrets** (API keys, passwords, tokens) to version control.
- **Never log sensitive data** (passwords, tokens, full card numbers, PHI).
- **Never trust client-side or caller-side validation** as the security boundary.
- **Never pass untrusted input to `eval`, `exec`, `pickle.loads`, `yaml.load` (unsafe), a shell, or
  a file path** without validation.
- **Never expose stack traces** or internal error detail to the caller.
- **Never fall back to a broader default path** when a destructive-operation safety check refuses.

## Hardening Controls

The rules below are the workflow; concrete Python/bash patterns live in
[references/hardening-patterns.md](references/hardening-patterns.md). Open the section you need when
you reach that code, not before.

### Injection and access control

- Parameterize every query (`cursor.execute(sql, params)` / the ORM's bound parameters) — never
  f-string or `%`-format input into SQL. Build subprocess calls as an argument list
  (`subprocess.run([...])`), never `shell=True` with an interpolated string.
- Check **authorization** on every request, not just authentication: the authenticated principal
  must own, or be permitted on, the *specific* resource (A01, IDOR). Authentication proves who; it
  does not prove allowed-to-touch-this-row. Patterns:
  [Injection](references/hardening-patterns.md#injection),
  [Access control](references/hardening-patterns.md#broken-access-control).

### Authentication and sessions

- Hash passwords with argon2 (preferred), scrypt, or bcrypt (≥12 rounds). Session/signing secrets
  come from the environment, never from code.
- Session tokens/cookies: bounded lifetime, server-side revocation path, and — for browser-facing
  services — `HttpOnly`, `Secure`, `SameSite=Lax|Strict`. Store auth tokens server-side or in secure
  cookies, never where client-side script can read them. Pattern:
  [Authentication](references/hardening-patterns.md#broken-authentication).

### Headers, CORS, and responses

- For browser-facing services: send security headers on every response, CSP tightened from
  `default-src 'self'`, and HSTS. Restrict CORS to an explicit origin allowlist from config — never
  `*` with credentials.
- Strip sensitive fields (`password_hash`, reset tokens, internal IDs) before serializing a
  response. Error bodies are generic; internals go to server logs only. Patterns:
  [Misconfiguration](references/hardening-patterns.md#security-misconfiguration),
  [Sensitive data exposure](references/hardening-patterns.md#sensitive-data-exposure).

### Input validation and uploads

- Validate at the boundary with a schema (pydantic, dataclass + validators, jsonschema): allowlisted
  shape, lengths, enums, formats. Reject malformed input with a structured error; downstream code
  uses only the parsed, typed value — never the raw payload.
- Uploads: allowlist content type, cap size, verify content (magic bytes) when it matters. The file
  extension proves nothing. Patterns:
  [Schema validation](references/hardening-patterns.md#schema-validation-at-boundaries),
  [File upload](references/hardening-patterns.md#file-upload-safety).

### Server-side fetches (SSRF)

Any URL the user influences — webhooks, import-from-URL, image proxies, link previews — can be aimed
at internal services or the cloud metadata endpoint. Allowlist scheme and host, resolve **all** DNS
records and reject any private or reserved address (loopback, link-local `169.254.169.254`, private,
unique-local — IPv4 and IPv6), and forbid redirects. A DNS-rebinding TOCTOU gap remains: for
high-risk surfaces, pin the resolved IP or front it with a filtering egress proxy. Pattern:
[SSRF](references/hardening-patterns.md#server-side-request-forgery-ssrf).

### Destructive operations on derived paths

A delete, move, or overwrite is only as safe as the value naming its target, and **trust follows who
*wrote* that value, not which channel delivered it** — another process's command line or a config
value is as attacker-controlled as a form field. A shape check proves well-formedness, not
authorization. Before the call, require all three:

1. the resolved target (symlinks resolved, `..` collapsed) sits under an **allowlisted root**;
1. it is at least one level **below** that root (never the root itself);
1. it carries **ownership evidence read before the operation**.

On refusal, log the rejected target and stop — never fall back to a broader default path. This is
the most dotfiles-relevant control: install scripts, symlink management, and the repo's own memory/
secret-guard hooks all operate on derived paths. Why the check is weaker than it reads (marker
self-attestation, check/use races):
[Destructive paths](references/hardening-patterns.md#destructive-operations-on-derived-paths).

### Rate limiting

Limit the API generally and auth endpoints strictly (about 10 attempts per 15 minutes). Once more
than one process serves traffic, an in-memory counter silently becomes `max × instances` (or never
fires on serverless): back the limiter with a shared store. Pattern:
[Rate limiting](references/hardening-patterns.md#rate-limiting).

### Secrets

Secrets come from the environment or a secrets manager. In this repo that means SOPS/age-encrypted
files kept out of git, with the dotenv file for a project likewise git-ignored — the encrypted
`*.enc.*` files and `.sops.yaml` are safe to read; the real dotenv files and age key material are
not (see `security/env-file-protection.md`). Commit a placeholder example file, never the real one;
grep the staged diff for secrets before committing. **A secret that reaches a remote is compromised
the moment it lands: rotate it first, then purge history.** If your own tooling leaks a secret,
disclose it immediately per `security/best-practices.md` "Disclosing Exposures." Pattern:
[Secrets management](references/hardening-patterns.md#secrets-management).

### Dependencies and supply chain

1. **Find the installation boundary and manager.** Use the workspace root that owns the lockfile.
   Corroborate the manager (pip/uv/poetry/pipenv, npm/pnpm, bundler, go), the lockfile, and CI; stop
   on disagreement or competing lockfiles. Pin the manager version.
1. **Block install/build scripts before first execution.** Bootstrap with scripts disabled or a
   documented fail-closed policy, inspect the pending script source, approve only the minimum, then
   verify with a clean frozen/locked install. Never blanket-approve.
1. **Run the native audit against the committed lockfile before every release** — `pip-audit` /
   `uv`'s audit / `safety` for Python, `npm audit` / `pnpm audit` for Node, `bundler-audit`, etc.
   Triage critical/high by **reachability** (runtime vs build vs test vs deploy path) and fix
   availability. Never apply a forced auto-remediation (`npm audit fix --force` or equivalent): it
   may cross declared version ranges. Preview, read changelogs, test each upgrade. Document every
   deferral with a reason and a review date.
1. **Audits only match known advisories.** They do not catch a newly malicious or typosquatted
   package (`crossenv` vs `cross-env`; a lookalike PyPI name). Review new dependencies, lockfile
   diffs, and script-policy changes together: ownership, maintenance, release age, provenance,
   transitive graph. Triage decision tree:
   [Dependency audit triage](references/hardening-patterns.md#dependency-audit-triage).

### Personal data and privacy

Hardening asks "can an attacker read it?" Privacy asks "should *we* hold it at all, and for how
long?" The cheapest data to protect, breach, and comply over is the data you never collected.

- **Classify fields as you add them** (non-personal, PII, sensitive). You cannot protect, or honor a
  deletion request for, data you cannot find.
- **Collect only against a stated purpose.** "Might be useful later" is latent breach scope, not a
  purpose. Keep PII out of telemetry and logs.
- **Set retention up front, then actually delete** — including backups, caches, search indexes, and
  analytics copies.
- **Support the data-subject rights your jurisdiction requires** (GDPR, CCPA): export, correct,
  delete. Design the schema so a user's data is findable and erasable.
- **Consent gates collection and third-party sharing, and is auditable.** Sending PII to an
  analytics, ad, or LLM vendor is sharing; the vendor needs a data-processing agreement.
  Classification table: [Data classification](references/hardening-patterns.md#data-classification).

### AI / LLM features

Calling an LLM — chatbots, summarizers, agents, RAG, or the agent tooling in this very repo — adds a
new attack surface; map it to the
[OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/):

- **Model output is untrusted input** (LLM05). Never pass it into `eval`/`exec`, SQL, a shell, a
  file path, or a template without parsing defensively, validating against a schema, then encoding.
- **Prompts can be hijacked** (LLM01). Untrusted text in the context — a user message, a fetched
  page, a PDF, a tool result — can carry instructions. The system prompt is **not** a security
  boundary; enforce permissions in code. (This repo already treats external content as untrusted and
  guards against injection strings in saved memory — the same posture.)
- **Keep secrets, other tenants' data, and the full system prompt out of the context window**
  (LLM02, LLM07); scope tool permissions, validate every tool argument, and confirm destructive
  actions (LLM06); cap tokens, request rate, and recursion depth (LLM10); partition RAG embeddings
  per tenant and validate documents before indexing (LLM08). Pattern:
  [LLM output handling](references/hardening-patterns.md#llm-output-handling).

## Common Rationalizations

| Rationalization                                     | Reality                                                                                      |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| "This is an internal tool, security doesn't matter" | Internal tools get compromised. Attackers target the weakest link.                           |
| "We'll add security later"                          | Retrofitting is 10x harder than building it in. Add it now.                                  |
| "No one would try to exploit this"                  | Automated scanners will. Security by obscurity is not security.                              |
| "The framework handles security"                    | Frameworks provide tools, not guarantees. You still have to use them correctly.              |
| "It's just a prototype"                             | Prototypes become production. Security habits from day one.                                  |
| "Threat modeling is overkill here"                  | Five minutes of "how would I attack this?" prevents design flaws no control can patch later. |
| "It's just LLM output, it's only text"              | That text can be a SQL statement, a shell command, or a path traversal. Treat it as input.   |
| "The audit passed, so the dependency is safe"       | Audits match known advisories. They miss a newly malicious package or an unreviewed script.  |
| "Collect it now, we might need it later"            | Data you don't hold can't be breached, subpoenaed, or mis-deleted. "Might need it" is scope. |
| "We'll handle deletion requests manually"           | Manual erasure misses backups, caches, analytics. If the schema can't find it, you can't.    |

## Red Flags

- User input passed directly to a query, a shell command, `eval`/`exec`, or a template
- A delete/move/overwrite whose target comes from a payload, config, or another process's command
  line, guarded only by a shape check on the path
- Secrets in source or commit history; secrets or PII in logs or telemetry
- An endpoint or task that authenticates but never checks authorization on the specific resource
- Missing CORS config or a wildcard (`*`) origin with credentials (browser-facing)
- No rate limiting on auth, or an in-memory limiter in front of more than one instance
- Stack traces or internal errors returned to the caller
- Dependencies with known critical vulns, competing lockfiles, non-reproducible installs, or
  blanket-approved install scripts
- A server fetch of a user-supplied URL with no allowlist (SSRF)
- LLM/model output passed into a query, a shell, `eval`, a path, or a template
- Secrets, PII, or the full system prompt placed inside an LLM context window
- Personal data collected with no stated purpose, retention limit, or deletion path

## Verification

After implementing security-relevant code:

- [ ] All external input validated at system boundaries with a schema
- [ ] Queries parameterized; subprocess calls use an argument list, not `shell=True` + interpolation
- [ ] No secrets in source or git history; none in logs/telemetry
- [ ] Destructive filesystem operations resolve symlinks, then verify allowlisted root, minimum
  depth, and ownership before running — and refuse rather than widen the path
- [ ] Authentication AND authorization checked on every protected endpoint/task
- [ ] Security headers present and CORS restricted (browser-facing services)
- [ ] Error responses don't expose internal detail
- [ ] Rate limiting active on auth, backed by a shared store when more than one instance serves
- [ ] Server-side URL fetches validated against an allowlist (no SSRF)
- [ ] LLM/model output validated and encoded before use (if AI features present)
- [ ] The native audit has no unmitigated reachable critical/high findings against the committed
  lockfile; CI blocks unreviewed dependency scripts
- [ ] Personal data classified, minimized to a stated purpose, with a retention limit and a working
  end-to-end deletion/export path (including backups, caches, analytics copies)
