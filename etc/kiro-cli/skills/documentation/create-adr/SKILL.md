---
name: create-adr
description: Create Architecture Decision Records (ADRs) following MADR format. Use when creating ADRs, documenting architectural decisions, recording design choices, or when asked to create a new ADR.
---

# Create ADR Skill

## ADR Creation Workflow

Follow these steps to create a new Architecture Decision Record (ADR) using the MADR (Markdown Architectural Decision Records) format.

### Step 1: Determine Next ADR Number

1. List all existing ADR files in `decisions/` directory
2. Find the highest numbered ADR (format: `adr-XXX-*.md` or `NNNN-*.md`)
3. Increment by 1 for the new ADR number
4. Format as zero-padded 3 or 4-digit number (e.g., 001, 002, 010 or 0001, 0002)

### Step 2: Select Template

**Check for project-specific template first:**

1. Look for `decisions/adr-template.md` in the project
2. Check `AGENTS.md` for template location or ADR conventions
3. Check `README.md` for ADR format guidance

**Use MADR template if no project template exists:**

- Use `references/madr-template.md` (MADR 4.0 compliant)
- See `references/example-short.md` for minimal format
- See `references/example-long.md` for full format with pros/cons

### Step 3: Gather ADR Information

Prompt the user for the following information:

**Required (MADR Core):**

- **Title**: Short, descriptive title (e.g., "Use PostgreSQL for Database")
- **Context and Problem Statement**: What problem or decision needs to be made? What are the constraints?
- **Considered Options**: What options were evaluated?
- **Decision Outcome**: What was decided? Why?
- **Consequences**: What are the positive and negative outcomes?

**Recommended (MADR Extended):**

- **Decision Drivers**: Forces or concerns driving the decision
- **Confirmation**: How to validate the decision was implemented correctly
- **Pros and Cons of Options**: Detailed analysis of each option
- **More Information**: Links to documentation, discussions, related ADRs

**Optional (MADR Metadata):**

- **Status**: proposed | rejected | accepted | deprecated | superseded by ADR-XXXX
- **Date**: YYYY-MM-DD
- **Decision Makers**: Who was involved in the decision
- **Consulted**: Who provided input (two-way communication)
- **Informed**: Who was kept updated (one-way communication)

### Step 4: Create ADR File

1. Generate filename: `decisions/adr-XXX-title-in-kebab-case.md` or `decisions/NNNN-title-with-dashes.md`
2. Use selected template (project-specific or MADR)
3. Replace all placeholders with information gathered in Step 3
4. Add YAML frontmatter with metadata (status, date, decision-makers)
5. Set Status to "proposed" for new ADRs
6. Set Date to today's date (YYYY-MM-DD format)
7. Create the file with the filled-in content

### Step 5: Update ADR Index (if exists)

If the project has `decisions/README.md` or similar index:

1. Add new entry to the index
2. Keep entries sorted by ADR number
3. Include: ADR number, title, status, date

### Step 6: Update SUMMARY.md (if using mdBook)

If the project uses mdBook with `SUMMARY.md`:

```markdown
- [Architecture Decisions](decisions/README.md)
  - [ADR-XXX: Title](decisions/adr-XXX-title.md)
```

### Step 7: Cross-Reference Related ADRs

If this ADR relates to existing ADRs:

1. Add references in "More Information" or "Related ADRs" section
2. Consider updating related ADRs to reference the new ADR
3. Use format: `[ADR-XXX](adr-XXX-title.md): Brief description`

## MADR Template Structure

The MADR 4.0 template (see `references/madr-template.md`) includes:

```markdown
---
status: proposed
date: YYYY-MM-DD
decision-makers: [names]
consulted: [names]
informed: [names]
---

# {short title}

## Context and Problem Statement

{Describe the context and problem}

## Decision Drivers

* {driver 1}
* {driver 2}

## Considered Options

* {option 1}
* {option 2}
* {option 3}

## Decision Outcome

Chosen option: "{option}", because {justification}.

### Consequences

* Good, because {positive consequence}
* Bad, because {negative consequence}

### Confirmation

{How to validate implementation}

## Pros and Cons of the Options

### {Option 1}

* Good, because {argument}
* Bad, because {argument}

### {Option 2}

* Good, because {argument}
* Bad, because {argument}

## More Information

{Additional context, links, related ADRs}
```

## When to Use Short vs Long Format

**Use Short Format** (`references/example-short.md`) when:
- Decision is straightforward
- Options are well-known
- Consequences are obvious
- Quick documentation is needed

**Use Long Format** (`references/example-long.md`) when:
- Decision is complex or controversial
- Multiple stakeholders involved
- Detailed analysis needed
- Future reference important

## Validation Checklist

Before finalizing the ADR, verify:

- [ ] ADR number is sequential (no gaps or duplicates)
- [ ] Filename follows project convention
- [ ] All required sections are present
- [ ] Status is set appropriately (usually "proposed" for new ADRs)
- [ ] Date is in YYYY-MM-DD format
- [ ] Context explains the "why" not just the "what"
- [ ] Decision outcome is clear and justified
- [ ] Consequences include both positive and negative
- [ ] Options section shows what was considered
- [ ] YAML frontmatter is valid (if used)
- [ ] Project index is updated (if exists)

## MADR Format Guidelines

### Section Names (MADR Standard)

Use these section names for MADR compliance:

- "Context and Problem Statement" (not "Context" or "Problem")
- "Considered Options" (not "Alternatives" or "Options Considered")
- "Decision Outcome" (not "Decision" or "Solution")
- "Consequences" (not "Positive/Negative Consequences")
- "Pros and Cons of the Options" (not "Alternatives Considered")
- "More Information" (not "Notes" or "References")

### Consequences Format

Use "Good, because..." and "Bad, because..." format:

```markdown
### Consequences

* Good, because tests are more readable
* Good, because easier to write tests
* Bad, because more complicated assertions
```

### YAML Frontmatter

Optional but recommended for metadata:

```yaml
---
status: proposed
date: 2024-03-13
decision-makers: [Alice, Bob]
consulted: [Charlie]
informed: [Team]
---
```

## Tips for Writing Good ADRs

1. **Write when context is fresh** - Don't wait until later
2. **Be specific** - Use actual names, versions, dates
3. **Document alternatives** - This is often the most valuable part
4. **Keep it concise** - One decision per ADR
5. **Update status** - Mark as deprecated or superseded when needed
6. **Link liberally** - Reference related ADRs and documentation
7. **Include confirmation** - Explain how to validate the decision

## Common Mistakes to Avoid

- Skipping the "Considered Options" section (shows what was evaluated)
- Vague context (explain the problem, not just the solution)
- Missing consequences (both positive AND negative)
- Forgetting to update the project index
- Not cross-referencing related ADRs
- Using placeholders instead of actual values
- Mixing multiple decisions in one ADR

## After Creating the ADR

1. Review the ADR with stakeholders if needed
2. Update Status from "proposed" to "accepted" once approved
3. Reference the ADR in relevant documentation
4. Link to the ADR from implementation files/procedures
5. Consider creating an issue for discussion if needed

## Reference Documentation

- `references/madr-template.md` - MADR 4.0 compliant template
- `references/example-short.md` - Minimal ADR example
- `references/example-long.md` - Full ADR example with detailed analysis
- Official MADR documentation: <https://adr.github.io/madr/>
- MADR examples: <https://adr.github.io/madr/examples.html>
