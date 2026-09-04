# Research Delegation

How to delegate deep research to sub-agents without either bloating your own context or trusting an
unverified summary.

## The Tension

Doing all research inline puts first-hand source material in your context (good for writing
follow-on docs) but bloats the window. Pure delegation keeps context lean but loses the primary
sources and forces you to trust a sub-agent's prose. The hybrid below resolves both.

## The Hybrid Pattern

1. **Sub-agents scan the landscape** (the context-heavy work) and report back a distilled, ranked
   comparison.
1. **Each load-bearing claim carries its source URL**, tagged by type (official docs / spec vs
   community / blog vs case study) and bound to the specific claim it supports — not a bare list of
   links.
1. **The orchestrator verifies the decision-critical sources.** Fetch only the handful of
   authoritative pages that actually drive the decision, confirm the sub-agent's claims against
   them, and keep those primary sources in context for any doc you then write.

This gets verified primary sources into your context *without* the full-scan bloat, and it satisfies
the standing preference to check official docs rather than trust training-data recall or an
intermediary's summary.

## Notes

- Prefer official docs / specs for capability and licensing claims; community sources are fine for
  real-world gotchas and case-study lessons — tag them so their weight is legible.
- Ask sub-agents to make the key URLs precise (deep links to the relevant section), so verification
  is cheap.
- Sequence dependent decisions rather than researching everything at once: when one decision
  constrains another, settle the first so the second is scoped by a known answer.
