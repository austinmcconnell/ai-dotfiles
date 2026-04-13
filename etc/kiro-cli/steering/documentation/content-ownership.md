# Content Ownership Model

**Purpose**: Detailed guide for understanding and applying the WHAT/HOW/WHY/SPECS separation in
documentation repositories.

## The Four Content Types

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

**Format**: Specifications, measurements, reference links

**Example files**:

- `gateway.md` - Gateway device specs (hardware example)
- `auth-module.md` - Authentication module specs (software example)
- `sensors.md` - Sensor specs and capabilities (IoT example)

**What NOT to include**:

- ❌ Configuration specifications (link to configuration/)
- ❌ Implementation procedures (link to procedures/)
- ❌ Network/system assignments (belongs in configuration/)

**Why**: Component specs are physical/logical facts. Configuration specs are design decisions. Keep
them separate.

### planning/ = Requirements and Procurement

**Purpose**: Project requirements, constraints, and procurement tracking

**Contains**:

- Project requirements and success criteria
- Constraints (budget, space, power, noise)
- Evaluation frameworks for comparing options
- Bill of materials — consolidated procurement tracker

**Format**: Tables, checklists

**Example files**:

- `requirements.md` - Project requirements and constraints
- `bom.md` - Bill of materials linking to components/

**What NOT to include**:

- ❌ Component specifications (belongs in components/)
- ❌ Decision rationale (belongs in decisions/)
- ❌ Duplicate purchase data from components/ (BOM links, not copies)

**Why**: Planning tracks what the project needs and where procurement stands. The BOM is a summary
view — detailed specs and purchase data stay in components/.

## Relationship Between Content Types

```text
WHY (decisions/)  →  WHAT (configuration/)  →  HOW (procedures/)
     ↑                        ↑                          ↑
     │                        │                          │
     └────────────────────────┴──────────────────────────┘
              Cross-reference and link between all

                    COMPONENT SPECS (components/)
                            ↓
                References configuration/ and procedures/
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
1. Update planning/bom.md if project uses a bill of materials

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
quantity). The BOM in planning/bom.md is a summary view that links to component files — it does not
duplicate or override purchase details.

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
