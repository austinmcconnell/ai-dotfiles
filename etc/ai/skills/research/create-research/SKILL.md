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
- **[comparison-template.md](references/comparison-template.md)** — for evaluating multiple options
  against each other (e.g., ZFS vs Btrfs, Zigbee vs Z-Wave, container runtimes, NAS software).
  Includes options table, per-option analysis, tradeoffs matrix, recommendations.
- **[technology-integration-template.md](references/technology-integration-template.md)** — for
  technology deep-dives with platform-specific configuration and troubleshooting (e.g., Sonos
  networking on UniFi, WireGuard on OPNsense). Includes requirements, platform configuration,
  troubleshooting decision trees, known issues.
- **[analytical-research-template.md](references/analytical-research-template.md)** — for
  framework-based analytical research that synthesizes academic or institutional data around a
  question (e.g., language learning timelines, education system analysis, tax regime comparisons).
  Includes framework/taxonomy, summary table, deep-dives, contextual analysis, key takeaways.
- **[clothing-brand-template.md](references/clothing-brand-template.md)** — for clothing brand
  research (e.g., Alex Crane, Taylor Stitch, Buck Mason). Includes brand overview, materials,
  product lineup with comparison table, sales/discounts, customer reception.

If none of the templates fit, check whether the research matches a different pattern entirely (e.g.,
historical analysis, market trends, regulatory landscape). If so, propose a custom structure to the
user — section headings, file layout, and rationale for the organization. **Wait for user
confirmation before proceeding.** Do not force content into an ill-fitting template — a
well-organized custom structure is better than a template used wrong. Additional templates can be
added to `references/` as needed.

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

**Multi-file non-product research:** If the topic will require 3+ files or covers both a technology
deep-dive and platform-specific configuration, propose the file layout to the user before proceeding
— which files, what each covers, and the dependency order between them. This prevents scope creep
and ensures the user agrees with the split before subagents start writing.

**Custom structure (no template fit):** If none of the existing templates match the research
subject, propose the custom section structure and file layout to the user before proceeding. Explain
why existing templates don't fit and what the custom structure covers. Wait for user confirmation
before delegating to subagents.

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
- **Template path:** Include the path to the appropriate template file and instruct the subagent to
  read it. The template defines section names and order.
- **Citation format:** Remind subagents to use `[source-key]` inline citations and include source
  URLs in the YAML `sources` block
- **Shared source keys:** If the orchestrator knows multiple subagents will cite the same source,
  specify canonical source keys in each subagent prompt so they produce consistent keys without
  deduplication at assembly time.
- **Return value:** "Return only the output filename(s) — do not return file content as text"
- **No pseudo-headings:** Subagents must never use bold text as pseudo-headings — always use proper
  markdown headings.

**Additional requirements by output mode:**

**Standalone files** (one subagent → one complete file):

- Subagent uses the template's exact heading structure and levels
- Include the YAML frontmatter example from Step 3 so the subagent produces complete frontmatter

**Temp files for assembly** (multiple subagents → one file):

- Specify which template sections the subagent owns
- Specify the exact heading depth (e.g., "Your top-level sections are `###`, subsections are
  `####`") — the template shows section names and order, but the heading level may differ from the
  template if the subagent's output will be nested under a parent heading
- Subagent writes two files: `.tmp-<topic>.md` (body only, no YAML frontmatter) and
  `.tmp-<topic>-sources.yaml` (source keys and URLs only). Do not include the frontmatter example in
  the subagent prompt — the orchestrator builds frontmatter during assembly.

#### After subagents complete

1. Read the files subagents created. For large files, prefer reading specific sections (e.g.,
   summary tables, recommendations) over full content when writing cross-cutting files.
1. If subagents wrote temp files (`.tmp-<topic>.md` + `.tmp-<topic>-sources.yaml`) for a single
   output file, **assemble** via shell concat — read only the small `-sources.yaml` files to build
   frontmatter, then `cat` the body files in template order. Do not read the body temp files into
   context. Do not rewrite, re-summarize, or re-synthesize subagent sections. Verify the assembled
   file (`wc -l` vs sum of temp files) before deleting `.tmp-*` files. Also verify heading hierarchy
   — if heading levels are wrong at this stage, the subagent prompt was underspecified (missing
   heading level guidance). Fix the prompt pattern for next time rather than manually adjusting
   assembled output. See `relocation-research-conventions` for the full pattern.
1. **Deduplicate source keys.** After merging `-sources.yaml` files, check for duplicate URLs across
   subagents. If two keys point to the same URL, keep one and update inline citations in the
   assembled body file accordingly. This is a post-assembly step that requires reading the file.
   (Specifying shared source keys in subagent prompts — see above — prevents most duplicates.)
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

**Research depth:** For technology integration topics, official documentation alone is rarely
sufficient. Community sources (forums, GitHub repos, blog posts) often contain the practical
knowledge that official docs omit — workarounds, firmware-specific bugs, configuration gotchas. A
good heuristic: if you've only found official sources, you haven't researched enough. If community
sources contradict official sources, document both positions and note the conflict.

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
- Cross-referencing means linking, not copying. When a sibling file already documents a
  configuration or spec, link to it with a brief context note (e.g., "see
  [STP configuration](unifi-sonos-configuration.md#6-stp--spanning-tree) for the full settings")
  rather than re-listing the same information. Duplication creates maintenance burden — when the
  data changes, every copy must be updated.
- For multi-file topics, each file should open with a one-sentence scope statement ("This file
  covers X — not Y") and link to sibling files for out-of-scope content. This prevents readers from
  searching the wrong file and makes the file boundaries clear.

**When to split into multiple files:** Split when the research has clearly separable audiences or
use cases. Signs that splitting is appropriate:

- A reader might need file A (reference) without file B (configuration) — e.g., someone on pfSense
  doesn't need the UniFi config file
- A file exceeds ~500 lines and has natural seam points between sections
- The topic has a platform-independent layer and a platform-specific layer

Signs that splitting is NOT appropriate:

- Every file constantly cross-references every other file for basic comprehension
- The "files" are really just chapters of one document
- Splitting would force readers to open 3 tabs to understand one concept

### Step 5: Update indexes

1. Update the topic `README.md` with a summary table and links to all files
1. Update the root `_research_/README.md` master index with the new topic

**Key findings:** For topics with 3+ files, include a "Key Findings" or "Summary" section in the
topic README before the file index table. This gives readers the bottom line without requiring them
to open every file. Keep it to 3–6 bullet points covering the most important takeaways.

**Recommendations:** If the research has a decision context — whether "which product to buy," "which
approach to take," or "how to configure this" — add recommendations. The format should match the
decision type:

- **Product selection:** "For use case X, choose Y because..."
- **Configuration:** A ranked list of approaches with tradeoffs (complexity, reliability, security)
  — this can live in the troubleshooting file as a "fallback approaches" section rather than a
  separate file
- **Comparison:** Per-use-case picks with reasoning

For lightweight topics, a brief section in the topic README after the file index table is
sufficient. For topics with enough cross-cutting analysis to warrant it (4+ files, multiple
competing options, weighted criteria), use a separate `recommendations.md` and link it from the
README. If the research is purely informational with no decision context, the file index table alone
is sufficient.

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
- [ ] Heading hierarchy is correct (no skipped levels, subsections nest under their parent)
- [ ] No duplicate source URLs across different keys in frontmatter
