# Deployment and Release

How to think about shipping a change once the code is written: separate *deploying* code from
*releasing* behavior, and make every deploy reversible. These are always-on principles for the
strategy layer. The mechanics of the pipeline itself — workflow YAML, OIDC, pinned actions, secret
handling — live in `../github/actions-conventions.md`; this doc is about the release *strategy* that
pipeline carries out.

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> harvesting the feature-flag-lifecycle and staged-rollout/rollback principles from its
> ci-cd-and-automation skill. The CI quality-gate and pipeline-optimization content of the source
> was intentionally dropped — it is already covered by `../github/actions-conventions.md` and was
> written in a web/Node idiom. Examples here are illustrative, not drawn from any company project.

## Decouple Deploy from Release

Deploying code and releasing behavior are two different events. Shipping the code to an environment
should not force the new behavior on users at the same instant. Keeping the two separate is what
lets you merge early, ship often, and turn a feature on deliberately — and turn it back off without
a redeploy.

A feature flag is the usual seam between the two. Guard risky or incomplete behavior behind a flag
so you can:

- Merge and deploy the code with the behavior off, then enable it when you are ready.
- Turn the behavior off by flipping the flag, not by reverting and redeploying.
- Enable it for a small slice first (a single tenant, internal users, a percentage) before everyone.

```python
# Illustrative: evaluate the flag per request/user, with a safe default when
# the flag service is unavailable. The default is the OFF (old) behavior.
if feature_flags.is_enabled('new-pricing-engine', context=user, default=False):
    return new_pricing(order)
return legacy_pricing(order)
```

The default value matters: when the flag backend is unreachable, evaluation must fall back to the
established behavior, never to the half-finished path.

## Feature-Flag Lifecycle

A flag is a temporary control, not a permanent branch. Give every flag a lifecycle and an end:

1. **Create** — add the flag with its default OFF; decide its evaluation context (per user, tenant,
   environment).
1. **Test** — exercise both states; a flag that is only ever tested in one state hides a bug in the
   other.
1. **Canary** — enable for a small, observable slice; watch the signals you instrumented before
   widening.
1. **Full rollout** — once it holds, enable for everyone.
1. **Remove** — delete the flag *and the dead code path it guarded*.

The last step is the one that gets skipped. A flag left in place after full rollout is permanent
branching in the code and in the flag backend — two live paths to reason about, test, and keep from
drifting. **Set a cleanup date when you create the flag.** Flags that live forever are technical
debt, and the dead `else` branch behind a fully-rolled-out flag is a latent bug waiting for someone
to flip the flag back by accident.

## Staged Rollout

Promote a build through environments in order of blast radius, not straight to production. The
specific stages depend on the service, but the shape is always lowest-risk first:

```text
merge / build → staging (verify) → pre-prod or canary env → production
```

Each stage is a chance to catch what the previous one could not: staging catches integration
breakage, a canary or pre-production environment catches real-traffic surprises before the whole
user base sees them. Automated post-deploy checks (smoke tests, health checks) at an early stage are
worth more than a manual look, because they run every time.

Gate the riskier stages — do not let a single merge walk itself all the way to production unattended
unless the whole pipeline, including rollback, is trustworthy enough to earn that.

## Every Deploy Is Reversible

Before you ship, know how you would unship. A deploy without a known rollback is a one-way door.

- **Prefer automatic rollback on failure.** A deploy that verifies health and reverts itself when
  the release does not come up healthy turns a bad deploy into a non-event. Many deploy tools expose
  this directly (for example, an atomic/`--atomic`-style mode that rolls back to the prior release
  if the upgrade does not become healthy within a wait window). Prefer that over a hope-and-watch
  deploy.
- **Keep a known-good previous version.** Rollback means redeploying the last version that worked,
  so that artifact must still exist and be deployable. Immutable, versioned build artifacts (a
  tagged image, a pinned chart) make rollback a redeploy of a known tag rather than a scramble.
- **A flag flip is the fastest rollback of all.** If the risky behavior is behind a flag, disabling
  the flag reverts the behavior with no deploy at all — which is the whole point of decoupling
  deploy from release.
- **Rollback is not free for stateful changes.** A schema migration or a data backfill may not be
  reversible by redeploying the old code. For those, plan the backward step explicitly (expand/
  contract migrations, a reverse backfill) *before* shipping — do not assume "redeploy the old
  version" undoes a migration.

## Relationship to Other Guidance

- `../github/actions-conventions.md` — the pipeline mechanics (workflow structure, OIDC, pinned
  actions, secret handling) that *carry out* the strategy here. Strategy lives in this doc; the YAML
  and its security posture live there.
- `code-health.md` — healthy, cohesive code is what makes a flag path and its eventual removal cheap
  rather than a tangle.
