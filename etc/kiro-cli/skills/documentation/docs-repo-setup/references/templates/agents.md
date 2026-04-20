# AGENTS.md Template

```markdown
# Content ownership

This document defines the content ownership model for this documentation. Each content type has a
single home — reference, don't duplicate.

## Content types

### planning/ — Requirements

- Project requirements and constraints
- Research criteria and evaluation frameworks
- Budget and timeline considerations

### research/ — Reference Material

- External links with purpose and key concepts
- Product and technology evaluations
- Comparison tables and assessments

**Not here:** Specifications (use configuration/). Decision rationale (use decisions/).

### components/ — SPECS (physical/logical inventory)

- Component specifications and model numbers
- Purchase information and costs (authoritative source for price, vendor, date)
- Physical setup details and measurements
- Performance metrics
- Bill of materials — summary view linking to component files (not a source of truth for prices)

**Not here:** Configuration specifications (use configuration/). Implementation steps (use
procedures/).

### configuration/ — WHAT (specifications)

- System design and architecture
- Configuration schemas and policies
- Network topology and assignments
- Security policies

**Not here:** Step-by-step instructions (use procedures/). Decision rationale (use decisions/).

### procedures/ — HOW (implementation)

- Step-by-step setup instructions
- Verification checklists
- Troubleshooting steps

**Not here:** Specifications or design (reference configuration/). Component specs (reference
components/).

### decisions/ — WHY (rationale)

- Architecture Decision Records (ADRs)
- Context, alternatives considered, and consequences
- Trade-off analysis

**Not here:** Implementation details (link to procedures/). Specifications (link to configuration/).

## Key rules

1. Each specification exists in exactly one place
1. Reference, don't duplicate
1. Procedures reference configuration/ for specs — never copy them inline
1. ADRs link to related configuration/ and procedures/ files
```
