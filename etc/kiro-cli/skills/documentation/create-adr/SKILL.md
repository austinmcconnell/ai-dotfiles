---
name: create-adr
description: Create Architecture Decision Records (ADRs) following project-specific templates. Use when creating ADRs, documenting architectural decisions, recording design choices, or when asked to create a new ADR.
---

# Create ADR Skill

## Core Principle

**Always use the project's own ADR template if one exists.** The project template defines section
names, metadata format, consequence style, and overall structure. Only fall back to MADR conventions
when no project template is found.

## ADR Creation Workflow

### Step 1: Find the project template

1. Look for `decisions/adr-template.md` in the project
1. Check `AGENTS.md` for template location or ADR conventions
1. Check `decisions/README.md` for ADR format guidance

**If a project template exists, use it for all formatting decisions.** Skip the MADR fallback
sections below.

If no project template exists, use `references/madr-template.md` as a fallback.

### Step 2: Determine next ADR number

1. List all existing ADR files in `decisions/` directory
1. Find the highest numbered ADR (format: `adr-XXX-*.md`)
1. Increment by 1 for the new ADR number
1. Format as zero-padded 3-digit number (e.g., 001, 002, 010)

### Step 3: Gather ADR information

Gather the information needed to fill in the template sections. At minimum:

- **Title**: Short, descriptive title (e.g., "Use PostgreSQL for Database")
- **Context**: What problem or decision needs to be made? What are the constraints?
- **Decision**: What was decided? Include concrete specifications when applicable.
- **Consequences**: What are the positive and negative outcomes?
- **Alternatives**: What options were evaluated? Why were they rejected?

### Step 4: Create ADR file

1. Generate filename: `decisions/adr-XXX-title-in-kebab-case.md`
1. Fill in the template with the gathered information
1. Follow the format from the selected template (project-specific or MADR fallback)
1. Set date to today (YYYY-MM-DD format)

### Step 5: Update project index

If the project has `decisions/README.md` with an ADR index:

1. Add new entry to the index
1. Keep entries sorted by ADR number
1. Include: ADR number, title, status, date

### Step 6: Update SUMMARY.md (if using mdBook)

If the project uses mdBook with `SUMMARY.md`:

```markdown
- [Decisions](decisions/README.md)
  - [ADR-XXX: Title](decisions/adr-XXX-title.md)
```

### Step 7: Cross-reference related ADRs

If this ADR relates to existing ADRs:

1. Add references in the "Related ADRs" section
1. Consider updating related ADRs to reference the new ADR
1. Use format: `[ADR-XXX](adr-XXX-title.md): Brief description`

If `research/` contains evaluations relevant to this decision, link to them in the References or
Related Documentation section. Research entries that informed this ADR should also cross-reference
back to it.

### Step 8: Check cross-repo impact

If this ADR changes shared resource assignments (IP addresses, switch ports, rack slots, PDU ports,
VLAN assignments, DNS records), run a targeted conflict check:

1. Identify which shared resources the ADR affects
1. Read only the authoritative source file for each affected resource (see ownership table below)
1. Verify the ADR's values don't conflict with existing assignments
1. Update the authoritative repo first, then update references in consumer repos. Never modify repos
   outside the current working directory without proposing the changes and receiving explicit
   approval first.
1. Note affected repos in the ADR's consequences section

**Ownership quick reference** (for full details, see the `cross-repo-audit` skill):

| Resource                   | Authoritative repo → file                                      |
| -------------------------- | -------------------------------------------------------------- |
| IP addresses, VLANs, DNS   | ubiquiti-network-stack → `configuration/network-topology.md`   |
| Rack slots, PDU ports      | tiny-lab → `configuration/rack-layout.md`, `components/pdu.md` |
| Compute switch ports       | tiny-lab → `configuration/network.md`                          |
| Main switch, gateway ports | ubiquiti-network-stack → `configuration/network-topology.md`   |

## Validation Checklist

Before finalizing the ADR, verify:

- [ ] ADR follows the project template format
- [ ] ADR number is sequential (no gaps or duplicates)
- [ ] Filename follows project convention
- [ ] All template sections are present and filled in
- [ ] Date is in YYYY-MM-DD format
- [ ] Context explains the "why" not just the "what"
- [ ] Decision is clear and includes concrete specifications
- [ ] Consequences include both positive and negative
- [ ] Alternatives show what was considered and why each was rejected
- [ ] Project index is updated (if exists)
- [ ] SUMMARY.md is updated (if using mdBook)
- [ ] Cross-repo impact assessed (if shared resources affected)

## Tips for Writing Good ADRs

1. **Write when context is fresh** — don't wait until later
1. **Be specific** — use actual names, versions, dates, prices, specs
1. **Document alternatives** — this is often the most valuable part
1. **Keep it concise** — one decision per ADR
1. **Update status** — mark as deprecated or superseded when needed
1. **Link liberally** — reference related ADRs and documentation

## Common Mistakes to Avoid

- Skipping the alternatives section (shows what was evaluated)
- Vague context (explain the problem, not just the solution)
- Missing consequences (both positive AND negative)
- Forgetting to update the project index and SUMMARY.md
- Not cross-referencing related ADRs
- Using placeholders instead of actual values
- Mixing multiple decisions in one ADR
- Ignoring the project template in favor of generic MADR format
- Including market conditions or procurement timing in ADR context. ADR context should focus on
  technical decision drivers (workload requirements, constraints, trade-offs). Prices are
  appropriate when comparing alternatives — cost is a legitimate trade-off factor. But current
  market shortages, deal-watching strategy, and "buy now vs later" reasoning are procurement
  concerns that belong in planning/ or components/, not in the decision rationale.

## Fallback: MADR Format

**Only use this when no project template exists.**

If the project has no `decisions/adr-template.md`, use the MADR 4.0 template at
`references/madr-template.md`. See also:

- `references/example-short.md` — minimal ADR example
- `references/example-long.md` — full ADR example with detailed analysis
- Official MADR documentation: <https://adr.github.io/madr/>
