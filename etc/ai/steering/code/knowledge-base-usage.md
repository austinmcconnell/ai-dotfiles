# Knowledge Base Usage

## Which Channel: Knowledge Base vs Memory vs Eager Context

Before reaching for the knowledge base, know what it *owns* versus the other two channels (the full
routing rule and its rationale live in `cross-session-memory.md`; the `readme-pointer` skill is the
eager-context map that feeds retrieval):

- **Knowledge base (semantic retrieval)** — *facts that live in the repo or docs corpus*: how the
  code works, what a doc says, cited research. This is the channel to query for repo/doc facts
  rather than eager-loading the docs or copying them into memory.
- **Persistent memory (engram)** — cross-session *narrative*: decisions, rationale, failed
  approaches, corrections, preferences. Not repo facts.
- **Eager context** — small, stable, high-signal always-loaded files plus a thin README *map* of
  what else exists. The map points at docs to retrieve on demand; it is not the corpus itself.

A README pointer telling you a doc exists is a *retrieval trigger*: follow it into the KB (if the
repo is indexed) or read the target doc directly. Do not treat "not already in context" as "does not
exist" — the map and the KB are there precisely so you retrieve rather than guess.

## Reach for the KB First in an Indexed Repo

When working in a repo that has a knowledge base, reach for the KB *before* hand-navigating with
`grep`/`read` — but scope it by question type. This is "use the KB to orient, use grep to pin down,"
not "the KB replaces grep."

- **Comprehension / orientation questions** — "how does X work," "what handles Y," "where does this
  flow live," "what are the pieces of subsystem Z." Search the KB first: it returns the right files
  and the prose that explains them far faster than reading around. This is exactly the case agents
  habitually skip — doing KB-shaped work by hand in an indexed repo is the documented failure mode
  this rule exists to correct.
- **Pointed call-site / definition hunts** — "every caller of `foo()`," "the exact line where `BAR`
  is set." Here the KB is a *starting point*, not the final answer: semantic retrieval ranks
  explanatory docs (markdown) above the source code they describe, so the precise call site often
  sits below the useful doc or off the result list. Use the KB to find the right file and orient,
  then confirm exact call sites with `grep`/`code`.

The net rule: let the KB give you the map and the comprehension, then let `grep`/`code` give you the
exhaustive, line-precise answer. Neither alone is sufficient in an indexed repo; skipping the KB
entirely is the more common mistake.

## Search Before Researching

Before performing web research, search available knowledge bases first. Existing research may
already cover the topic with cited sources.

## Cross-Machine Availability

Knowledge bases reference repos that may not exist on every machine. Personal repos are absent on
work machines and vice versa. If a KB search returns no results or a referenced repo doesn't exist,
that's expected — move on without commenting on it.

## Staleness Check

When citing KB results, check `last_verified` in YAML frontmatter:

- **< 90 days**: Present normally
- **90–180 days**: Warn user findings may be outdated
- **> 180 days**: Warn and suggest re-verification before relying on data

## Presenting Results

- Mention the source file and verification date
- Distinguish verified facts from conclusions/opinions
- If partial overlap exists, present what's available and identify remaining gaps

## Source Type Awareness

When citing KB results that mix official and community sources, note the source type if it affects
reliability. Official vendor documentation is authoritative for specs and supported configurations.
Community sources (forums, blogs, GitHub repos) are authoritative for workarounds, real-world
behavior, and undocumented features — but may be version-specific or anecdotal.

## Updating Research

When new information contradicts or supplements existing research, load the `update-research` skill
— don't modify research files ad-hoc.
