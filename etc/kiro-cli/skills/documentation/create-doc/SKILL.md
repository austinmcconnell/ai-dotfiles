---
name: create-doc
description: Create new documentation files with proper content type separation and templates. Use when creating configuration specs, procedures, component docs, or README files in documentation repositories.
---

# Create Documentation File Skill

## Overview

Streamline documentation creation by prompting for content type, using appropriate templates, and automatically updating SUMMARY.md with proper cross-references.

## When to Use This Skill

- Creating new configuration specification files (WHAT)
- Creating new procedure files (HOW)
- Creating new component specification files (SPECS)
- Creating README.md files for directories
- Ensuring proper content type separation from the start

## Document Creation Workflow

### Step 1: Determine Content Type

Ask the user what type of content they want to create:

**Options:**

1. **Configuration (WHAT)** - Specifications, design, requirements
1. **Procedure (HOW)** - Step-by-step implementation instructions
1. **Component (SPECS)** - Component specifications and capabilities
1. **README** - Directory overview and purpose

**Questions to ask:**

- What are you documenting?
- Is this a specification (WHAT) or implementation steps (HOW)?
- Is this about a physical/logical component (SPECS)?
- Are you creating a directory overview (README)?

### Step 2: Determine Directory and Filename

Based on content type, determine location:

**Configuration (WHAT):**

- Directory: `configuration/` or `src/configuration/`
- Filename pattern: `{topic}-{subtopic}.md` (e.g., `network-topology.md`, `security-rules.md`)
- Use kebab-case

**Procedure (HOW):**

- Directory: `procedures/` or `src/procedures/`
- Filename pattern: `{component}-{action}.md` (e.g., `gateway-setup.md`, `security-configuration.md`)
- Use kebab-case
- Be specific, not generic

**Component (SPECS):**

- Directory: `components/` or `src/components/`
- Filename pattern: `{component-name}.md` (e.g., `gateway.md`, `auth-module.md`)
- Use kebab-case

**README:**

- Directory: User-specified directory
- Filename: `README.md` (always)

**Check for project conventions:**

1. Look for `AGENTS.md` for naming patterns
1. Check existing files in target directory
1. Verify `src/` prefix usage (mdBook projects)

### Step 3: Select Template

Use appropriate template from `references/templates/`:

- **Configuration** → `configuration-template.md`
- **Procedure** → `procedure-template.md`
- **Component** → `component-template.md`
- **README** → `README-template.md`

**Check for project-specific templates:**

1. Look for templates in project root or `.kiro/` directory
1. Check `AGENTS.md` for template locations
1. Fall back to skill templates if none exist

### Step 4: Gather Content Information

Prompt user for content based on type:

**For Configuration (WHAT):**

- **Title**: What is being specified?
- **Purpose**: Why does this specification exist?
- **Specifications**: Tables, lists, or structured data
- **Design Rationale**: Key design decisions (or link to ADR)
- **Related Procedures**: Links to implementation procedures
- **Related Components**: Links to components used

**For Procedure (HOW):**

- **Title**: What is being implemented?
- **Purpose**: What does this procedure accomplish?
- **Prerequisites**: What must be reviewed/completed first?
  - Links to relevant configuration files
  - Links to related ADRs
- **Steps**: Numbered implementation steps
- **Verification**: How to confirm success
- **Troubleshooting**: Common issues and fixes
- **Related Documentation**: Links to configuration and components

**For Component (SPECS):**

- **Title**: Component name
- **Purpose**: What is this component?
- **Specifications**: Model, version, capabilities
- **Performance**: Metrics and measurements
- **Configuration**: Link to where component is configured
- **Procedures**: Link to setup/maintenance procedures
- **Vendor Documentation**: External links

**For README:**

- **Directory Purpose**: What does this directory contain?
- **Content Ownership**: WHAT/HOW/WHY/SPECS designation
- **What Belongs Here**: Criteria for file placement
- **What Belongs Elsewhere**: Common mistakes to avoid
- **Key Files**: Links to important files in directory

### Step 5: Create File with Content

1. Use selected template
1. Replace all placeholders with gathered information
1. Add proper cross-references using link conventions:
   - `[Configuration: Title](../configuration/file.md)`
   - `[Procedure: Title](../procedures/file.md)`
   - `[Component: Name](../components/file.md)`
   - `[ADR-NNN: Title](../decisions/adr-nnn-title.md)`
1. Ensure relative paths are correct
1. Create the file in determined location

### Step 6: Update SUMMARY.md

If project uses mdBook with `SUMMARY.md`:

1. Locate `SUMMARY.md` (usually `src/SUMMARY.md`)
1. Find appropriate section for content type
1. Add entry in correct location:

```markdown
# Configuration

- [Network Topology](configuration/network-topology.md)
- [Security Rules](configuration/security-rules.md)

* [New Configuration](configuration/new-config.md)

# Procedures

- [Gateway Setup](procedures/gateway-setup.md)

* [New Procedure](procedures/new-procedure.md)
```

1. Maintain alphabetical or logical ordering
1. Use proper indentation for hierarchy

**If SUMMARY.md doesn't exist:**

- Note that file was created but SUMMARY.md needs manual creation
- Suggest running docs-repo-setup skill if starting new project

### Step 7: Suggest Cross-References

Based on content type, suggest adding cross-references to related files:

**For Configuration files:**

- Suggest adding link from related procedures to this configuration
- Suggest adding link from related ADRs to this configuration

**For Procedure files:**

- Suggest adding link from related configuration to this procedure
- Suggest adding link from component specs to this procedure

**For Component files:**

- Suggest adding link from configuration where component is used
- Suggest adding link from procedures that set up this component

## Content Type Decision Guide

Help users determine correct content type:

### Is it Configuration (WHAT)?

**Yes if:**

- Defines specifications or requirements
- Contains design decisions
- Has tables of values, settings, or assignments
- Describes system architecture
- Documents policies or rules

**No if:**

- Contains step-by-step instructions
- Has "Step 1, Step 2" format
- Includes UI navigation
- Shows how to implement something

### Is it Procedure (HOW)?

**Yes if:**

- Step-by-step implementation instructions
- UI navigation steps
- Field-by-field configuration guide
- Verification checklist
- Troubleshooting steps

**No if:**

- Defines what should be configured (that's WHAT)
- Explains why decisions were made (that's WHY)
- Documents component capabilities (that's SPECS)

### Is it Component (SPECS)?

**Yes if:**

- Physical device specifications
- Software module capabilities
- Model numbers and versions
- Performance metrics
- Component-specific details

**No if:**

- Network assignments or system design (that's WHAT)
- Setup instructions (that's HOW)
- Decision rationale (that's WHY)

### Is it README?

**Yes if:**

- Explaining directory purpose
- Documenting content ownership
- Providing navigation for directory

## Template Placeholders

Templates use these placeholder patterns:

- `{placeholder}` - Required information
- `[optional]` - Optional sections
- `<!-- comment -->` - Guidance comments

**Common placeholders:**

- `{title}` - Document title
- `{purpose}` - Why this document exists
- `{description}` - Detailed description
- `{specifications}` - Spec tables or lists
- `{steps}` - Numbered procedure steps

## Validation Checklist

Before finalizing the document, verify:

- [ ] Content type is correct (WHAT/HOW/WHY/SPECS)
- [ ] Filename follows kebab-case convention
- [ ] File is in correct directory
- [ ] All template placeholders replaced
- [ ] Cross-references use proper link text patterns
- [ ] Relative paths are correct
- [ ] SUMMARY.md updated (if applicable)
- [ ] No duplicate specifications from other files
- [ ] Prerequisites section links to relevant files (for procedures)
- [ ] Related Documentation section added

## Common Mistakes to Avoid

### ❌ Wrong Content Type

**Problem:** Creating procedure in configuration/ or vice versa

**Prevention:** Ask clarifying questions in Step 1

### ❌ Generic Filenames

**Problem:** `setup.md` instead of `gateway-setup.md`

**Prevention:** Be specific in Step 2

### ❌ Missing Cross-References

**Problem:** Procedure doesn't link to configuration

**Prevention:** Always add Prerequisites section with links

### ❌ Duplicate Specifications

**Problem:** Copying spec tables from configuration/ into procedure

**Prevention:** Reference, don't duplicate - use links

### ❌ Forgetting SUMMARY.md

**Problem:** File created but not accessible in mdBook

**Prevention:** Always check for and update SUMMARY.md

## After Creating Document

1. **Review content type separation** - Ensure no mixing of WHAT/HOW/WHY/SPECS
1. **Verify cross-references** - Check that links work and use proper patterns
1. **Test mdBook build** - Run `mdbook build` to verify no errors
1. **Add to git** - Stage and commit the new file
1. **Consider related updates** - Update related files with cross-references

## Examples

### Example 1: Creating Configuration File

**User request:** "I need to document our network topology"

**Workflow:**

1. Content type: Configuration (WHAT)
1. Location: `src/configuration/network-topology.md`
1. Template: `configuration-template.md`
1. Gather: VLANs, IP assignments, network segments
1. Create file with specifications in tables
1. Update SUMMARY.md under "Configuration" section
1. Suggest: Add link from `procedures/network-configuration.md`

### Example 2: Creating Procedure File

**User request:** "I need to document how to set up the gateway"

**Workflow:**

1. Content type: Procedure (HOW)
1. Location: `src/procedures/gateway-setup.md`
1. Template: `procedure-template.md`
1. Gather: Prerequisites, steps, verification, troubleshooting
1. Create file with:
   - Prerequisites linking to `configuration/network-topology.md`
   - Steps referencing specs (not duplicating)
   - Verification checklist
1. Update SUMMARY.md under "Procedures" section
1. Suggest: Add link from `configuration/network-topology.md`

### Example 3: Creating Component File

**User request:** "I need to document the gateway device specs"

**Workflow:**

1. Content type: Component (SPECS)
1. Location: `src/components/gateway.md`
1. Template: `component-template.md`
1. Gather: Model, specs, performance, vendor links
1. Create file with component details
1. Update SUMMARY.md under "Components" section
1. Suggest: Link from `configuration/network-topology.md` and `procedures/gateway-setup.md`

## Reference Documentation

- `references/templates/configuration-template.md` - Configuration file template
- `references/templates/procedure-template.md` - Procedure file template
- `references/templates/component-template.md` - Component file template
- `references/templates/README-template.md` - README file template
- `steering/documentation/content-ownership.md` - Content type principles
- `steering/documentation/link-conventions.md` - Cross-reference standards
