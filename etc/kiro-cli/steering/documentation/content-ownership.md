# Content Ownership Model

**Purpose**: Detailed guide for understanding and applying the WHAT/HOW/WHY/SPECS separation in documentation repositories.

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

**Why**: Specifications change less frequently than UI. Keeping them separate means UI changes don't require updating specs.

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

**Why**: Procedures reference specifications. When specs change, procedures don't need updating (unless UI changed).

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

**Why**: Decisions explain the "why" behind specifications. Future you will thank you for documenting this.

### components/ = COMPONENT SPECS (Physical/Logical Inventory)

**Purpose**: Document physical/logical components and their capabilities

**Contains**:

- Component specifications and model numbers
- Purchase information and costs (if applicable)
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

**Why**: Component specs are physical/logical facts. Configuration specs are design decisions. Keep them separate.

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
2. Add to configuration/[relevant-config].md if needed
3. Create procedures/[component]-setup.md
4. Create ADR if significant decision
5. Update SUMMARY.md
6. Add cross-references

### Changing Specification

1. Update configuration/[spec].md (single source of truth)
2. Verify procedures/ still reference correctly (don't duplicate)
3. Update affected ADRs if rationale changed

### Adding Procedure

1. Create procedures/[procedure].md
2. Add "Review design: [Configuration: X]" in Prerequisites
3. Reference configuration/ for all specs (don't duplicate)
4. Add verification checklist
5. Add troubleshooting section
6. Update SUMMARY.md

## Anti-Patterns (Never Do This)

### ❌ Duplicating Specifications

**Wrong**: Including full spec table in procedures file
**Right**: "For complete specifications, see [Configuration: X](../configuration/x.md)"

### ❌ Implementation Steps in Configuration

**Wrong**: Step-by-step UI instructions in configuration/system.md
**Right**: "For implementation, see [Procedure: System Configuration](../procedures/system-configuration.md)"

### ❌ Specifications in Multiple Files

**Wrong**: IP assignments in multiple config files and procedures
**Right**: All related specifications in single configuration file only

### ❌ Generic Procedures

**Wrong**: component-setup.md with generic steps
**Right**: switch-setup.md, module-setup.md (component-specific)

### ❌ Planning Files That Duplicate Other Content

**Wrong**: planning/equipment-selection.md duplicating ADRs
**Right**: Use ADRs for decisions, planning/ only for requirements

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
