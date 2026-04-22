---
name: update-research
description: Update existing research files with new information, additional sources, or corrections. Use when adding findings to existing research, incorporating new products/options, or when the user provides new data to integrate.
---

# Update Research

## When to Use

- Adding new information to an existing research file (new product variant, price change, new
  source)
- Incorporating user-provided corrections or additions
- Expanding a topic with additional files (e.g., adding a new product family to an existing topic)
- Restructuring or splitting files that have grown beyond a single subject

## Update Workflow

### Step 1: Read the existing file

Read the target file and understand its current content, frontmatter, and source registry.

### Step 2: Fetch new data

Follow the same web fetching discipline as create-research:

- Fetch from primary sources (manufacturer sites, official stores)
- Never rely on cached/old data for prices or availability
- Mark unfetchable data with `[UNVERIFIED]` and note why

### Step 3: Integrate changes

- Add new content in the appropriate section (follow the existing template structure)
- Add new sources to the frontmatter `sources` registry
- Add inline citations for all new factual claims
- Maintain scope control: if new content doesn't belong in this file, create a new file instead

### Step 4: Update frontmatter

```yaml
last_updated: YYYY-MM-DD  # today
last_verified: YYYY-MM-DD # today if sources were re-checked, otherwise leave unchanged
update_summary: Added M2 variant pricing and availability  # single line, overwritten each update
```

Update `verified` dates only on sources that were actually re-fetched during this update.

### Step 5: Update indexes

1. Update the topic `README.md` if the summary table or links need changes
1. Update the root `_research_/README.md` master index if a new topic or file was added

## Freshness

See [create-research freshness policy](../create-research/SKILL.md#freshness-policy) for the 90-day
staleness threshold.

## Scope Boundaries

- If an update would make a file cover more than one subject, split it into separate files
- If adding a new product family or concept to an existing topic, create a new file rather than
  appending to an existing one
- Cross-reference new files from the topic README and from related files using relative links
