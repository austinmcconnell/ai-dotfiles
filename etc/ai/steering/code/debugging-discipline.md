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
