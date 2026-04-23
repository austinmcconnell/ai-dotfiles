# Content Ownership Model

**Purpose**: Guide for applying the WHAT/HOW/WHY/SPECS separation in documentation repositories.

## Content Types

**planning/** — Project requirements, constraints, and procurement tracking. Contains: requirements,
success criteria, constraints, evaluation frameworks. Not: component specs, decision rationale,
BOMs.

**research/** — Curated external resources, product evaluations, and comparisons that inform
decisions. Contains: external links, product evaluations, comparison tables, assessments. Not:
specifications, decision rationale, implementation steps, component specs.

**decisions/** — Architectural decisions and trade-offs (ADR/MADR format). Contains: decision
context, alternatives considered, rationale, consequences. Not: implementation details, detailed
specifications, market conditions or procurement timing.

**components/** — Physical/logical component inventory and capabilities. Contains: specs, model
numbers, purchase info (price/date/quantity), performance metrics, upgrade paths, BOM. Not:
configuration specifications, implementation procedures, system assignments.

**configuration/** — Single source of truth for all specifications (WHAT). Contains: system design,
configuration schemas, policies, specifications. Not: step-by-step instructions, UI navigation,
"click here" procedures.

**procedures/** — Step-by-step implementation instructions (HOW). Contains: UI navigation,
field-by-field instructions, verification checklists, troubleshooting. Not: detailed specifications,
design rationale, duplicate tables from configuration/.

## Relationship Between Content Types

```text
planning/  →  research/  →  decisions/  →  components/  →  configuration/  →  procedures/
(NEEDS)       (OPTIONS)     (WHY)          (SPECS)         (WHAT)             (HOW)

Cross-reference and link between all sections.
Research informs decisions. Decisions drive component selection.
Components feed into configuration. Configuration is implemented by procedures.
```

## Anti-Patterns

- **Duplicating Specifications** — Don't include spec tables in procedures; reference configuration/
- **Implementation Steps in Configuration** — Don't put UI steps in configuration/; link to
  procedures/
- **Specifications in Multiple Files** — Keep all related specs in a single configuration/ file
- **Generic Procedures** — Use component-specific names (switch-setup.md), not generic
  (component-setup.md)
- **Planning Files That Duplicate Other Content** — Use ADRs for decisions; planning/ only for
  requirements

## File Naming Conventions

- Use kebab-case: `system-configuration.md` not `System_Configuration.md`
- Be specific: `gateway-controller-setup.md` not `setup.md`
- Match content type: `security-rules.md` (specs) vs `security-configuration.md` (steps)

## Cross-Referencing Standards

- Use descriptive link text: `[Configuration: System](../configuration/system.md)`
- Add "Related Documentation" section at end of major files

## Pricing Conventions

Component files are the single source of truth for purchase data. BOM is a procurement ledger that
intentionally repeats unit prices for at-a-glance totals — component files win on conflicts.

**Required fields:** Unit price (pre-tax, pre-shipping), Quantity, Purchase date (YYYY-MM-DD),
Status (Bought / Needed / On order).

**Price normalization:** Always record pre-tax, pre-shipping unit prices. Tax varies by
jurisdiction; shipping is per-order, not per-component.

## Subdirectory READMEs

Every content subdirectory must have README.md with: purpose, content ownership, what belongs here
vs elsewhere, links to key files.
