# Research & External-Source Discipline

How to acquire information from sources outside the codebase — which form to prefer, and how to
fetch efficiently. (For *which retrieval channel* to reach for — indexed KB vs engram vs web — see
`knowledge-base-usage.md` and `cross-session-memory.md`; for reasoning about the claims a source
makes, see `analytical-discipline.md`.)

## Prefer the machine-readable form for data

When you need a source's *data* (not its narrative), reach for its structured distribution — CSV,
GeoJSON, a JSON API, a data.gov DCAT record — over parsing values out of a PDF or documentation
prose. Don't reject a source because its human-facing docs are a PDF; check whether the underlying
data has a stable, fetchable machine-readable form first, and verify a load-bearing fact against
that distribution rather than the prose.

## Fetch narrowly

When pulling documentation, don't `web_fetch` a full page from a large doc site (e.g. MapLibre /
Mapbox API references) — the response carries tens of thousands of tokens of navigation chrome for a
few sentences of signal. Use selective mode with tight `search_terms`, deep-link to the relevant
anchor, or skip the fetch if a search snippet already answers the question.
