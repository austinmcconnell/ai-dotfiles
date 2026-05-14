# Knowledge Base Usage

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
