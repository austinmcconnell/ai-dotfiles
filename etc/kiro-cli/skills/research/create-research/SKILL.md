---
name: create-research
description: Create structured research files with cited sources, YAML frontmatter, and standardized templates. Use when researching products, technologies, concepts, or any topic requiring organized, verifiable findings.
---

# Create Research

## Research Output Location

All research lives in `~/projects/austinmcconnell/_research_/`. Each topic gets its own subdirectory
with a README.md index. The root `_research_/README.md` is a master index of all topics.

```text
_research_/
├── README.md              ← master index of all topics
├── odroid/
│   ├── README.md          ← topic index
│   ├── odroid-h.md
│   └── odroid-c.md
└── zigbee-vs-zwave/
    ├── README.md
    └── ...
```

## Templates

Choose the template that fits the research subject:

- **[hardware-product-template.md](references/hardware-product-template.md)** — for product lineup
  or product family research (e.g., ODROID SBCs, Ubiquiti switches, NVMe drives). Includes variants
  table, pricing, use cases, limitations, community reception, comparisons, accessories/ecosystem.
- **[general-research-template.md](references/general-research-template.md)** — for concept,
  technology, or comparison research (e.g., ZFS vs Btrfs, Zigbee vs Z-Wave, container runtimes).
  Includes overview, options/alternatives, tradeoffs, recommendations, sources.

If neither template fits, adapt the closest one. Additional templates can be added to `references/`
as needed.

## Workflow

### Step 1: Set up the topic directory

1. Create `_research_/<topic>/` if it doesn't exist
1. Create `_research_/<topic>/README.md` as the topic index

### Step 2: Research with web fetching discipline

**Always fetch current data from primary sources:**

- Manufacturer sites, official store pages, and official documentation
- Prefer primary sources over secondary sources (news articles, reviews) for factual data like
  prices, specs, and availability

**Never rely on:**

- Cached/old data or training knowledge for prices, availability, or current specs
- Launch-day news articles for current pricing (prices change)

**When a source can't be fetched** (bot-blocked, down, paywalled):

- Mark the data point with `[UNVERIFIED]` and note why
- Example: `The H4+ is $180 [UNVERIFIED — hardkernel.com returned 403]`

### Step 3: Create research files

Each file covers ONE thing — one product family, one concept, one comparison. Use the appropriate
template from `references/`.

**Required YAML frontmatter for every research file:**

```yaml
---
created: 2026-04-21
last_updated: 2026-04-21
last_verified: 2026-04-21
update_summary: Initial research
sources:
  source-key:
    url: "https://example.com/page"
    verified: 2026-04-21
  another-source:
    url: "https://example.com/other"
    verified: 2026-04-21
---
```

**Inline citation format:** Reference sources by key in square brackets.

```markdown
The H4+ is $139 [hardkernel-h4p]. It supports up to 48 GB DDR5 [cnx-h4-review].
```

### Step 4: Scope control

- One file per product family, concept, or comparison
- Cross-reference between files using relative markdown links: `[H-series](odroid-h.md)`
- Aggregation and comparison belongs in dedicated comparison files or the topic README, not inline

### Step 5: Update indexes

1. Update the topic `README.md` with a summary table and links to all files
1. Update the root `_research_/README.md` master index with the new topic

### Step 6: Offer to reindex

After creating research files, remind the user to reindex the `_research_` knowledge base if one is
configured:

> Research files created. Run `knowledge update` to reindex the _research_ knowledge base.

## Freshness Policy

When citing existing research from the knowledge base, check `last_verified` in frontmatter. If
older than 90 days, warn the user:

> ⚠️ This research was last verified on YYYY-MM-DD (X days ago). Use stale data or update first?

## Validation Checklist

- [ ] Every file has complete YAML frontmatter (created, last_updated, last_verified,
  update_summary, sources)
- [ ] Every factual claim has an inline source citation
- [ ] Unfetchable data points are marked `[UNVERIFIED]` with reason
- [ ] Each file covers exactly one subject
- [ ] Cross-references use relative markdown links
- [ ] Topic README.md index is updated
- [ ] Root _research_/README.md master index is updated
- [ ] Primary sources preferred over secondary for prices/specs/availability
