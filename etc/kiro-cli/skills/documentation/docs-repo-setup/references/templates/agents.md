# AGENTS.md Template

```markdown
# AI Agent Instructions

## Project Overview

[Brief description of what this documentation covers]

## Documentation Structure
```

planning/ # Requirements, constraints, and BOM components/ # Physical/logical component
specifications configuration/ # System specifications (WHAT) procedures/ # Implementation steps
(HOW) decisions/ # Architecture decisions (WHY)

```markdown
## Content Ownership Model

### configuration/ = WHAT (Specifications)

**Purpose**: Single source of truth for all specifications

**Contains**: Design, schemas, policies, specifications

**Format**: Tables, diagrams, reference docs

**Update when**: Design changes, specs modified

**What NOT to include**: Implementation steps (belongs in procedures/)

### procedures/ = HOW (Implementation)

**Purpose**: Step-by-step instructions to implement configuration

**Contains**: UI navigation, field-by-field instructions, verification

**Format**: Numbered steps, checklists

**Update when**: UI changes, process improves

**What NOT to include**: Specifications (belongs in configuration/)

### decisions/ = WHY (Rationale)

**Purpose**: Document architectural decisions and trade-offs

**Contains**: Decision context, alternatives, rationale, consequences

**Format**: ADR template

**Update when**: Significant decisions made

### components/ = COMPONENT SPECS (Physical/Logical Inventory)

**Purpose**: Document components and capabilities

**Contains**: Component specs, setup details, performance

**Format**: Specifications, measurements

**Update when**: New components added, performance measured

## Common Mistakes to Avoid

### ❌ Duplicating Specs in Procedures

**Wrong**: Including full spec table in procedures file

**Right**: "For complete specifications, see [Configuration: X](../configuration/x.md)"

### ❌ Adding Implementation Steps to Configuration

**Wrong**: Step-by-step UI instructions in configuration files

**Right**: "For implementation steps, see [Procedure: X](../procedures/x.md)"

### ❌ Forgetting Single Source of Truth

**Wrong**: Specifications in multiple files

**Right**: All related specifications in single configuration file only

## File Naming Conventions

- Use kebab-case: `system-configuration.md` not `System_Configuration.md`
- Be specific: `gateway-controller-setup.md` not `setup.md`
- Match content: `security-rules.md` (specs) vs `security-configuration.md` (steps)

## Cross-Referencing Standards

- Always link to canonical source
- Use descriptive link text: `[Configuration: X](../configuration/x.md)`
- Add "Related Documentation" section at end of major files

## Common Tasks

### Adding New Component

1. Create components/[component].md with specifications
2. Add to configuration/[relevant-config].md if needed
3. Create procedures/[component]-setup.md
4. Create ADR if significant decision
5. Update SUMMARY.md
6. Add cross-references
7. Update planning/bom.md if project uses a bill of materials

### Changing Specification

1. Update configuration/[spec].md (single source of truth)
2. Verify procedures/ still reference correctly
3. Update any affected ADRs

## Questions to Ask

- Is this WHAT (configuration/) or HOW (procedures/)?
- Does this specification already exist elsewhere?
- Am I duplicating content that should be referenced?
- Is there a related ADR that should be referenced?
```
