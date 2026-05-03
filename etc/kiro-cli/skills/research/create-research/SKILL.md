---
name: create-research
description: Create structured research files with cited sources, YAML frontmatter, and standardized templates. Use when researching products, technologies, concepts, or any topic requiring organized, verifiable findings.
---

# Create Research

## Research Output Location

All research lives in `$PROJECTS_DIR/austinmcconnell/_research_/`. Each topic gets its own
subdirectory with a README.md index. The root `_research_/README.md` is a master index of all
topics.

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

Before starting any step, check the topic directory (`_research_/<topic>/`) for existing files. If
the directory exists, read what's already there. If prior files exist, build on them — don't
overwrite completed work. If orphaned `.tmp-*` files exist from a failed assembly, clean them up
before proceeding. If the topic is partially complete (some files written, others not), complete
only the missing parts.

### Step 0: Plan file layout and subagent delegation

Before creating any files, decide the full directory structure and file list for the topic. This is
the orchestrator's responsibility — subagents must never decide where files go.

**Large product ecosystems:** If the topic covers a large product ecosystem (multiple product
categories, tiers, or generations from a single vendor), check the knowledge base first — existing
research on the same vendor may already have the category structure mapped. Then survey the
manufacturer's store or product pages to fill gaps and confirm the current lineup. If the prompt
does not define a clear scope boundary, propose a file layout and scope boundary to the user before
proceeding — which categories/tiers are in scope, approximate product count per file, and anything
you'd recommend excluding. Wait for user confirmation before delegating to subagents. Split by
product category (products a buyer would compare against each other) rather than individual product.

**When to use subagents:** The topic has research areas that can be investigated independently.
Subagents keep the orchestrator's context clean for synthesis, cross-referencing, and any follow-up
research — even a 2-file topic benefits if the research involves heavy web fetching.

**When to skip subagents:** All files are tightly interdependent (each file's content depends on
what the others find), or the topic is small enough that a single agent can research and write it
without heavy web fetching. A single output file does **not** automatically mean "skip subagents" —
if the file covers many independent research domains with heavy web fetching, delegate the research
to subagents using the temp-file assembly pattern (see below and relocation-research-conventions for
an example).

#### Orchestrator responsibilities

1. Decide the topic directory: `_research_/<topic>/`
1. Plan the complete file list with exact filenames
1. Classify each file as **self-contained** (one subagent has everything it needs) or
   **cross-cutting** (requires knowledge from multiple subagents)
1. Assign self-contained files to subagents with exact output paths
1. Reserve cross-cutting files for the orchestrator to write after subagents complete:
   - Topic `README.md`
   - Comparison/recommendation files
   - Master index updates
   - Any file that cross-references multiple subagent outputs

#### Subagent prompt requirements

Each subagent prompt must include:

- **Exact output path:** "Write your findings to `_research_/networking-nics/25gbe-nics.md`"
- **Negative constraint:** "Do not create any other files, directories, or README files"
- **Template path:** Include the path to the appropriate template file (e.g.,
  `references/hardware-product-template.md`) and instruct the subagent to read it and use its exact
  section headings
- **Frontmatter template:** Include the YAML frontmatter example from Step 3 in the subagent prompt
  so each subagent produces consistent frontmatter without needing to read the skill file
- **Citation format:** Remind subagents to use `[source-key]` inline citations and include source
  URLs in the YAML `sources` block
- **Return value:** "Return only the output filename(s) — do not return file content as text"

#### After subagents complete

1. Read the files subagents created. For large files, prefer reading specific sections (e.g.,
   summary tables, recommendations) over full content when writing cross-cutting files.
1. If subagents wrote temp files (`.tmp-<topic>.md` + `.tmp-<topic>-sources.yaml`) for a single
   output file, **assemble** via shell concat — read only the small `-sources.yaml` files to build
   frontmatter, then `cat` the body files in template order. Do not read the body temp files into
   context. Do not rewrite, re-summarize, or re-synthesize subagent sections. Verify the assembled
   file (`wc -l` vs sum of temp files) before deleting `.tmp-*` files. See
   `relocation-research-conventions` for the full pattern.
1. Write cross-cutting files (README, comparison, etc.) with correct cross-references
1. Update the topic `README.md` and root `_research_/README.md`
1. Verify all relative links between files are correct

**Step responsibilities when using subagents:** Steps 1–4 describe the research and writing process.
When using subagents, each subagent executes Steps 2–3 for its assigned file(s). The orchestrator
handles Steps 0 (planning/delegation), 1 (directory setup), 4 (scope control review), and 5 (index
updates) directly.

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
template from `references/` — see the [Templates](#templates) section for selection criteria.
Include the chosen template path in subagent prompts (see Step 0).

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
- For multi-file topics covering a single vendor or ecosystem, cross-reference related files where
  specs interact (e.g., link AP PoE requirements to the switches file's PoE budget table, link
  gateway built-in ports to the switches file for expansion options). Link on first mention per
  section — do not re-link the same target within the same `##` section.

### Step 5: Update indexes

1. Update the topic `README.md` with a summary table and links to all files
1. Update the root `_research_/README.md` master index with the new topic

**Recommendations:** If the research has an explicit or implicit decision context (e.g., "which
switch for my home network"), add recommendations. For lightweight topics, a brief section in the
topic README after the file index table is sufficient. For topics with enough cross-cutting analysis
to warrant it (4+ files, multiple competing options, weighted criteria), use a separate
`recommendations.md` and link it from the README. If the research is purely informational with no
decision context, the file index table alone is sufficient.

## Unresolved Items

Use a git-ignored `todo.md` file in the topic directory for unresolved questions, blockers, and
session handoff notes. See the `todo` skill for the template and conventions.

## Cross-Cutting vs. Project-Specific Research

- **Project-specific research** (e.g., evaluating NVMe drives for a specific build) belongs in the
  project's own `research/` directory. The docs agent creates this.
- **Cross-project research** (e.g., ODROID product lineup, RAM pricing trends) belongs in
  `_research_/`. The default agent creates this using the research skill.
- The docs agent **reads** `_research_` via its knowledge base but does **not write** to it. This
  keeps the docs agent focused on its primary documentation repo.

## Freshness Policy

When citing existing research from the knowledge base, check `last_verified` in frontmatter. If
older than 90 days, warn the user:

> ⚠️ This research was last verified on YYYY-MM-DD (X days ago). Use stale data or update first?

## Validation Checklist

- [ ] Every file has complete YAML frontmatter (created, last_updated, last_verified,
  update_summary, sources)
- [ ] Every factual claim has an inline `[source-key]` citation
- [ ] Unfetchable data points are marked `[UNVERIFIED]` with reason
- [ ] Each file covers exactly one subject
- [ ] Cross-references use relative markdown links
- [ ] Topic README.md index is updated
- [ ] Root _research_/README.md master index is updated
- [ ] Primary sources preferred over secondary for prices/specs/availability
