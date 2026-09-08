# Debugging Discipline

How to behave when a problem resists the first fix — so investigation converges instead of burning
effort.

## Research to settle, not to fuel the next guess

On a non-obvious problem, research official docs, upstream issues, and case studies BEFORE trying
local tweaks — someone has likely hit it. But research must *settle the question*, not just supply a
citation for the next attempt. Applying researched fix A → it fails → researching fix B → it fails →
… is still a guess-loop, just with citations.

- Before applying a researched fix, confirm it actually explains the observed failure. If it
  doesn't, you're guessing.
- Reproduce cheaply only to CONFIRM a formed hypothesis, not to explore.
- If three researched fixes in a row don't hold, the PREMISE is likely wrong. Question the test,
  fixture, or assumption itself — don't just add more mitigation ("wait harder").

## Verify the fix reached the running system before doubting the fix

When a change that should be correct produces ZERO observable change, suspect the DELIVERY path — a
stale cache, an unrebuilt bundle, a served-from-disk old artifact — before re-tuning the change
itself. "Looks identical no matter what I change" is the signature of an edit that never reached the
running system, not of a wrong edit.

- Confirm the new code is actually what's running (hard-reload, bust the cache, rebuild, check the
  served bytes) before adjusting values.
- Re-tuning numbers against a stale artifact burns rounds and produces false evidence that the
  approach is wrong — the classic tell is that even a large change has no effect.

## Stop when the fix escapes the task

If your change perturbs behavior OUTSIDE what you were asked to do — especially a pre-existing or
unrelated flaky test — stop and surface it rather than silently expanding the task to fix it. Ask
whether it is even yours to chase.

Present the situation crisply and let the user decide before spending:

> "X is done and verified. My change perturbed Y (evidence: baseline 8/8 → 6/8). Options: (a) revert
> my Y-affecting changes and file Y as separate work, (b) fix Y's root cause, (c) accept as-is.
> Which do you prefer?"

A timing perturbation in an unrelated test is not a mandate to fix that test.

## Fetch narrowly

When pulling documentation, don't `web_fetch` a full page from a large doc site (e.g. MapLibre /
Mapbox API references) — the response carries tens of thousands of tokens of navigation chrome for a
few sentences of signal. Use selective mode with tight `search_terms`, deep-link to the relevant
anchor, or skip the fetch if a search snippet already answers the question.
