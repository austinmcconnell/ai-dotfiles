---
name: verify-research
description: Verify and fact-check existing research files by re-fetching sources, checking prices/availability, and updating frontmatter. Use when research may be stale, when asked to verify findings, or when last_verified is older than 90 days.
---

# Verify Research

## When to Verify

- User explicitly asks to verify or fact-check research
- `last_verified` in frontmatter is older than 90 days (see
  [create-research freshness policy](../create-research/SKILL.md#freshness-policy))
- User is about to make a purchase or decision based on research
- A source URL has changed or returned errors during a previous session

## Verification Workflow

### Step 1: Read the research file

Read the file and extract the `sources` registry from YAML frontmatter.

### Step 2: Re-fetch primary sources

For each source in the registry:

1. Fetch the URL using `web_fetch`
1. Compare key facts (prices, specs, availability, status) against what the file states
1. Note any discrepancies

**Prioritize primary sources** (official store pages, manufacturer sites) over secondary sources
(news articles, reviews) for factual data.

### Step 3: Report findings

Present a summary to the user:

```text
✅ Verified (no changes): source-key-1, source-key-2
⚠️  Changed: source-key-3 — price was $139, now $149
❌ Unreachable: source-key-4 — returned 403
🆕 New info: [describe anything significant found during verification]
```

### Step 4: Apply updates (with user approval)

If discrepancies are found:

1. Show the user what changed
1. Ask whether to update the file
1. If approved, update the content and frontmatter:
   - Set `last_verified` to today
   - Set `last_updated` to today
   - Set `update_summary` to a single-line description of changes
   - Update `verified` date on each re-checked source

If no discrepancies:

1. Update only `last_verified` to today
1. Update `verified` date on each re-checked source

### Step 5: Flag unresolvable items

If a source can't be fetched, mark affected data points with `[UNVERIFIED]` and note the reason in
the file.

## Batch Verification

When verifying an entire topic directory:

1. List all `.md` files in the topic directory
1. Sort by `last_verified` (oldest first)
1. Verify each file following the workflow above
1. Update the topic README.md if any file statuses changed
