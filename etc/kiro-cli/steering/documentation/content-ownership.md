# Content Ownership Model

**Purpose**: Detailed guide for understanding and applying the WHAT/HOW/WHY/SPECS separation in
documentation repositories.

## The Content Types

### planning/ = Requirements and Procurement

**Purpose**: Project requirements, constraints, and procurement tracking

**Contains**:

- Project requirements and success criteria
- Constraints (budget, space, power, noise)
- Evaluation frameworks for comparing options

**Format**: Tables, checklists

**Example files**:

- `requirements.md` - Project requirements and constraints

**What NOT to include**:

- ❌ Component specifications (belongs in components/)
- ❌ Decision rationale (belongs in decisions/)
- ❌ Bill of materials (belongs in components/)

**Why**: Planning tracks what the project needs. Requirements define needs, research explores
options.

### research/ or RESEARCH.md = REFERENCE (External Research)

**Purpose**: Curated external resources, product evaluations, and comparison research that inform
decisions

**Contains**:

- External links with purpose and key concepts
- Product and technology evaluations
- Comparison tables assessing options against requirements
- Assessment sections with opinionated conclusions
- Community resources and references

**Format**: Curated link entries (URL, Purpose, Key Concepts), comparison tables, assessments

**Two formats** — choose based on scope:

| Criteria                  | Single `RESEARCH.md`             | `research/` directory                   |
| ------------------------- | -------------------------------- | --------------------------------------- |
| Number of research topics | One to four topics               | Five or more topics                     |
| Total content size        | Under ~300 lines                 | Over ~300 lines                         |
| Research depth per topic  | Link collection with brief notes | Deep evaluations with comparison tables |
| SUMMARY.md placement      | Below `---` separator (appendix) | Top-level section with children         |

**Single-file format** (`RESEARCH.md` at project root):

- Best for projects with a handful of research topics
- Entries numbered sequentially across all sections for easy reference
- Includes project-specific context section and quick reference
- Listed in SUMMARY.md below a `---` separator as reference material

**Directory format** (`research/` with topic files):

- Best for projects with deep, multi-product evaluations across many topics
- `research/README.md` serves as the index with getting started and topic links
- Each topic file is self-contained with comparison table, findings, and deep-dives
- Listed in SUMMARY.md as a top-level section with children

**When to migrate** from single file to directory:

- The file exceeds ~300 lines
- Five or more distinct topic areas exist
- Individual topics need comparison tables or multi-product evaluations
- Multiple ADRs reference different sections of the same research file

**What NOT to include**:

- ❌ Specifications (belongs in configuration/)
- ❌ Decision rationale (belongs in decisions/)
- ❌ Implementation steps (belongs in procedures/)
- ❌ Component specs or purchase data (belongs in components/)

**Why**: Research is reference material that informs decisions. It sits outside the
WHAT/HOW/WHY/SPECS hierarchy as curated input. Centralizing external links prevents link rot and
scattered references.

### decisions/ = WHY (Rationale)

**Purpose**: Document architectural decisions and trade-offs

**Contains**:

- Decision context and problem statement
- Alternatives considered
- Decision made and rationale
- Consequences (positive and negative)

**Format**: ADR template (MADR format recommended)

**Example files**:

- `adr-001-use-platform-x.md` - Why this platform
- `adr-002-component-selection.md` - Why this component
- `adr-003-security-strategy.md` - Why this approach

**What NOT to include**:

- ❌ Implementation details (link to procedures/)
- ❌ Detailed specifications (link to configuration/)

**Why**: Decisions explain the "why" behind specifications. Future you will thank you for
documenting this.

### components/ = COMPONENT SPECS (Physical/Logical Inventory)

**Purpose**: Document physical/logical components and their capabilities

**Contains**:

- Component specifications and model numbers
- Purchase information (authoritative source for price, date, quantity)
- Physical/logical setup details
- Performance metrics (actual measurements)
- Upgrade paths
- Bill of materials — procurement ledger linking to component files

**Format**: Specifications, measurements, reference links

**Example files**:

- `gateway.md` - Gateway device specs (hardware example)
- `auth-module.md` - Authentication module specs (software example)
- `sensors.md` - Sensor specs and capabilities (IoT example)
- `bom.md` - Bill of materials (procurement ledger linking to component files)

**What NOT to include**:

- ❌ Configuration specifications (link to configuration/)
- ❌ Implementation procedures (link to procedures/)
- ❌ Network/system assignments (belongs in configuration/)

**Why**: Component specs are physical/logical facts. Configuration specs are design decisions. Keep
them separate. The BOM lives here because every BOM entry corresponds to a component file — it is a
procurement ledger of the directory's contents.

### configuration/ = WHAT (Specifications)

**Purpose**: Single source of truth for all specifications

**Contains**:

- System design and architecture
- Configuration schemas and policies
- Specifications and requirements
- Design rationale and trade-offs

**Format**: Tables, diagrams, reference documentation

**Example files**:

- `system-configuration.md` - System specs and settings
- `security-rules.md` - Security policies and rules
- `network-topology.md` - Network/system layout and assignments

**What NOT to include**:

- ❌ Step-by-step implementation instructions
- ❌ UI navigation steps
- ❌ "Click here, then click there" procedures

**Why**: Specifications change less frequently than UI. Keeping them separate means UI changes don't
require updating specs.

### procedures/ = HOW (Implementation)

**Purpose**: Step-by-step instructions to implement the configuration

**Contains**:

- UI navigation steps
- Field-by-field configuration instructions
- Verification checklists
- Testing procedures
- Troubleshooting steps

**Format**: Numbered steps, checklists, screenshots

**Example files**:

- `system-configuration.md` - How to configure system in UI
- `security-configuration.md` - How to create security rules in UI
- `initial-setup.md` - Sequential setup workflow

**What NOT to include**:

- ❌ Detailed specifications (reference configuration/ instead)
- ❌ Design rationale (reference decisions/ instead)
- ❌ Duplicate tables from configuration/

**Why**: Procedures reference specifications. When specs change, procedures don't need updating
(unless UI changed).

### Relationship between research and decisions

Research feeds into ADRs. When research findings are significant enough to drive a choice, create an
ADR that references the relevant research entries. ADRs should link back to research for supporting
evidence. Research files should cross-reference the ADRs they informed.

## Relationship between content types

```text
planning/  →  research/  →  decisions/  →  components/  →  configuration/  →  procedures/
(NEEDS)       (OPTIONS)     (WHY)          (SPECS)         (WHAT)             (HOW)

Cross-reference and link between all sections.
Research informs decisions. Decisions drive component selection.
Components feed into configuration. Configuration is implemented by procedures.
```

## File Naming Conventions

- Use kebab-case: `system-configuration.md` not `System_Configuration.md`
- Be specific: `gateway-controller-setup.md` not `setup.md`
- Match content type: `security-rules.md` (specs) vs `security-configuration.md` (steps)

## Cross-Referencing Standards

- Always use descriptive link text: `[Configuration: System](../configuration/system.md)`
- Add "Related Documentation" section at end of major files
- Reference, never duplicate specifications

## Common Patterns

### Adding New Component

1. Create components/[component].md with specifications
1. Add to configuration/[relevant-config].md if needed
1. Create procedures/[component]-setup.md
1. Create ADR if significant decision
1. Update SUMMARY.md
1. Add cross-references
1. Update components/bom.md if project uses a bill of materials

### Changing Specification

1. Update configuration/[spec].md (single source of truth)
1. Verify procedures/ still reference correctly (don't duplicate)
1. Update affected ADRs if rationale changed

### Adding Procedure

1. Create procedures/[procedure].md
1. Add "Review design: [Configuration: X]" in Prerequisites
1. Reference configuration/ for all specs (don't duplicate)
1. Add verification checklist
1. Add troubleshooting section
1. Update SUMMARY.md

## Anti-Patterns (Never Do This)

### ❌ Duplicating Specifications

**Wrong**: Including full spec table in procedures file **Right**: "For complete specifications, see
[Configuration: X](../configuration/x.md)"

### ❌ Implementation Steps in Configuration

**Wrong**: Step-by-step UI instructions in configuration/system.md **Right**: "For implementation,
see [Procedure: System Configuration](../procedures/system-configuration.md)"

### ❌ Specifications in Multiple Files

**Wrong**: IP assignments in multiple config files and procedures **Right**: All related
specifications in single configuration file only

### ❌ Generic Procedures

**Wrong**: component-setup.md with generic steps **Right**: switch-setup.md, module-setup.md
(component-specific)

### ❌ Planning Files That Duplicate Other Content

**Wrong**: planning/equipment-selection.md duplicating ADRs **Right**: Use ADRs for decisions,
planning/ only for requirements

## README.md Files

Every subdirectory must have README.md with:

- Purpose statement
- Content ownership (WHAT/HOW/WHY/SPECS)
- What belongs here vs elsewhere
- Links to key files

## Quality Standards

### Before Committing

- [ ] No duplicate specifications across files
- [ ] Configuration files contain no implementation steps
- [ ] Procedure files reference (not duplicate) specifications
- [ ] All cross-references use descriptive link text
- [ ] README.md exists in each subdirectory
- [ ] SUMMARY.md updated if new files added
- [ ] Pre-commit hooks pass (linting, links, spelling)

### File Structure

- [ ] HTML comments explain WHAT vs HOW in templates
- [ ] "Related Documentation" section at end of major files
- [ ] Consistent heading hierarchy (H1 → H2 → H3)
- [ ] Tables for structured data
- [ ] Numbered lists for procedures
- [ ] Bullet lists for specifications

## Pricing Conventions

### Authoritative location

Component files in components/ are the single source of truth for purchase data (price, date,
quantity). The BOM in components/bom.md is a procurement ledger that records actual per-unit costs
and links to component files — it does not duplicate specifications but must reflect the real prices
from component files. The BOM is an intentional exception to the no-duplication rule: it repeats
unit prices from component files for at-a-glance procurement totals, but component files remain
authoritative. When prices conflict, component files win.

### Standard fields for component files

| Field         | Required    | Description                          |
| ------------- | ----------- | ------------------------------------ |
| Unit price    | Yes         | Pre-tax, pre-shipping price per unit |
| Quantity      | Yes         | Number purchased or needed           |
| Purchase date | When bought | ISO 8601 format (YYYY-MM-DD)         |
| Status        | Yes         | Bought / Needed / On order           |

### Price normalization

Record prices as pre-tax, pre-shipping unit prices. This is the canonical price field.

**Why pre-tax**: Tax varies by jurisdiction and changes over time. It is not a property of the
component.

**Why pre-shipping**: Shipping is per-order, not per-component. Splitting shipping across items is
arbitrary and produces misleading per-unit costs.

**Why unit price**: The comparable number when evaluating alternatives or checking current pricing.

### BOM requirements

Required when the project includes purchasable or acquirable components. Controlled by `include_bom`
during cookiecutter project creation.

- Every component in components/ should have a corresponding BOM entry
- BOM links to component files for details — does not duplicate specifications
- Status tracking should be kept current (Bought / Needed / On order)
