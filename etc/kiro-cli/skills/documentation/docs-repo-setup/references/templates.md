# Documentation Templates

**Purpose**: Ready-to-use templates for documentation repository files.

## Directory Structure Template

```text
project-root/
├── AGENTS.md              # Content ownership model
├── README.md              # Project overview
├── SUMMARY.md             # mdBook navigation
├── INTRODUCTION.md        # Book introduction
├── RESEARCH.md            # External references
├── glossary.md            # Terminology
├── planning/
│   ├── README.md          # Planning overview
│   └── requirements.md    # Requirements only
├── components/            # Hardware, software, or system components
│   ├── README.md
│   └── [component].md     # One file per component
├── configuration/
│   ├── README.md
│   └── [config].md        # One file per config area
├── procedures/
│   ├── README.md
│   ├── initial-setup.md   # Sequential setup guide
│   └── [procedure].md     # One file per procedure
└── decisions/
    ├── README.md
    ├── adr-template.md
    └── adr-NNN-*.md       # Numbered ADRs
```

## AGENTS.md Template

```markdown
# AI Agent Instructions

## Project Overview

[Brief description of what this documentation covers]

## Documentation Structure
```

planning/ # Requirements and constraints components/ # Physical/logical component specifications
configuration/ # System specifications (WHAT) procedures/ # Implementation steps (HOW) decisions/ #
Architecture decisions (WHY)

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

## Subdirectory README.md Template

```markdown
# [Directory Name]

## Purpose

[One sentence explaining what this directory contains]

## Content Ownership

This directory contains [WHAT/HOW/WHY/SPECS]. See [AGENTS.md](../AGENTS.md) for details.

## What Belongs Here

- [Type of content 1]
- [Type of content 2]
- [Type of content 3]

## What Does NOT Belong Here

- [Type of content that belongs elsewhere] → See [other directory]
- [Type of content that belongs elsewhere] → See [other directory]

## Key Files

- **[file1.md]** - [Brief description]
- **[file2.md]** - [Brief description]
- **[file3.md]** - [Brief description]

## Related Documentation

- [Link to related directory]
- [Link to related directory]
```

## Configuration File Template

```markdown
# [Configuration Name]

<!-- This file is the SINGLE SOURCE OF TRUTH for [config] specifications -->
<!-- For implementation steps, see procedures/[procedure].md -->

## Overview

[Brief description of what this configuration covers]

## Specifications

[Detailed specs - this is WHAT, not HOW]

### [Section 1]

| Field   | Value   | Description   |
| ------- | ------- | ------------- |
| [field] | [value] | [description] |

### [Section 2]

[More specifications]

<!-- DO NOT add implementation steps here -->
<!-- Implementation steps belong in procedures/ -->

## Design Rationale

[Brief explanation of design choices, or link to ADR]

## Implementation

For step-by-step instructions, see [Procedure: XXX](../procedures/xxx-configuration.md).

## Related Documentation

### Configuration

- [Related Config 1](config1.md) - [Description]
- [Related Config 2](config2.md) - [Description]

### Procedures

- [Procedure: XXX](../procedures/xxx-configuration.md) - Implementation steps

### Decisions

- [ADR-NNN](../decisions/adr-nnn-xxx.md) - [Decision description]

### Components

- [Component](../components/component.md) - [Component description]
```

## Procedure File Template

```markdown
# [Procedure Name]

<!-- This file contains HOW to implement the configuration -->
<!-- For specifications, see configuration/ -->

## Prerequisites

- [Prerequisite 1]
- **Review design**: [Configuration: XXX](../configuration/xxx.md)
- [Prerequisite 3]
- Estimated time: [X] minutes

## Overview

This procedure implements [brief description]. For complete specifications, see [Configuration: XXX](../configuration/xxx.md).

<!-- DO NOT duplicate specs here -->
<!-- Reference configuration/ for all specifications -->

## Step 1: [Action]

1. Navigate to **XXX**
2. Click **YYY**
3. Configure:
   - **Field 1**: [value - reference config if complex]
   - **Field 2**: [value]
   - **Field 3**: [value]

> [!NOTE]
> For complete [spec details], see [Configuration: XXX](../configuration/xxx.md).

## Step 2: [Action]

1. [Step]
2. [Step]

## Verification

Check the following to confirm successful setup:

- [ ] [Check 1]
- [ ] [Check 2]
- [ ] [Check 3]

## Troubleshooting

### [Problem 1]

**Symptoms**: [Description]

**Solutions**:

- [Solution 1]
- [Solution 2]

### [Problem 2]

**Symptoms**: [Description]

**Solutions**:

- [Solution 1]

## Related Documentation

- [Configuration: XXX](../configuration/xxx.md) - Specifications
- [Procedure: YYY](yyy.md) - Related procedure
- [ADR-NNN](../decisions/adr-nnn.md) - Rationale
```

## Component File Template

```markdown
# [Component Name]

<!-- This file is the SINGLE SOURCE OF TRUTH for [component] specifications -->
<!-- For configuration, see configuration/ -->
<!-- For implementation steps, see procedures/[component]-setup.md -->

## Overview

[Brief description of the component]

## Specifications

### Hardware/Software Details

| Specification | Value   | Notes   |
| ------------- | ------- | ------- |
| Model/Version | [value] | [notes] |
| [Spec 2]      | [value] | [notes] |
| [Spec 3]      | [value] | [notes] |

### Performance

- **[Metric 1]**: [value]
- **[Metric 2]**: [value]

### Physical/Logical Setup

[Description of physical location, mounting, power, or logical architecture]

<!-- DO NOT add configuration specs here -->
<!-- Configuration specs belong in configuration/ -->

## Configuration

For system configuration details, see [Configuration: XXX](../configuration/xxx.md).

## Implementation

For step-by-step setup instructions, see [Procedure: XXX Setup](../procedures/xxx-setup.md).

## Related Documentation

### Components

- [Related Component 1](component1.md) - [Description]

### Configuration

- [Config](../configuration/config.md) - Configuration details

### Procedures

- [Setup](../procedures/component-setup.md) - Setup procedure

### Decisions

- [ADR-NNN](../decisions/adr-nnn.md) - Selection rationale
```

## SUMMARY.md Template

```markdown
# Table of Contents

- [Introduction](INTRODUCTION.md)

- [Planning](planning/README.md)

  - [Requirements](planning/requirements.md)

- [Components](components/README.md)

  - [Component 1](components/component1.md)
  - [Component 2](components/component2.md)

- [Configuration](configuration/README.md)

  - [Config 1](configuration/config1.md)
  - [Config 2](configuration/config2.md)

- [Procedures](procedures/README.md)

  - [Initial Setup](procedures/initial-setup.md)
  - [Procedure 1](procedures/procedure1.md)
  - [Troubleshooting](procedures/troubleshooting.md)

- [Architecture Decisions](decisions/README.md)
  - [ADR Template](decisions/adr-template.md)
  - [ADR-001: Decision Title](decisions/adr-001-decision-title.md)

---

- [Glossary](glossary.md)
- [Research & References](RESEARCH.md)
```

## Day 1 Setup Checklist

### Repository (10 minutes)

- [ ] Initialize git, create .gitignore
- [ ] Create README.md with project overview
- [ ] Choose mdBook, create book.toml

### Directories (5 minutes)

- [ ] Create planning/, components/, configuration/, procedures/, decisions/
- [ ] Create README.md in each subdirectory
- [ ] Create SUMMARY.md

### Core Files (15 minutes)

- [ ] Create AGENTS.md with content ownership model
- [ ] Create RESEARCH.md for external links
- [ ] Create glossary.md for terminology
- [ ] Create INTRODUCTION.md for book overview

### Templates (20 minutes)

- [ ] Create decisions/adr-template.md
- [ ] Create components/component-template.md
- [ ] Create configuration/config-template.md
- [ ] Create procedures/procedure-template.md
- [ ] Add HTML comments explaining WHAT vs HOW

### Quality Gates (15 minutes)

- [ ] Create .pre-commit-config.yaml
- [ ] Run `pre-commit install`
- [ ] Add validation scripts
- [ ] Test `mdbook serve` and `mdbook build`
