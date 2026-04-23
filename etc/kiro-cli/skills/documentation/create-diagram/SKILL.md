---
name: create-diagram
description: Create and manage diagrams in documentation using Mermaid and diagram-as-code tools. Use when creating diagrams, adding Mermaid charts, updating network topology diagrams, or troubleshooting diagram rendering.
---

# Create Diagram Skill

## Overview

Create diagrams as code using Mermaid, stored in version control alongside documentation. This
approach enables text diffs, consistent styling, searchable content, and no external tools for
viewing.

## When to Use This Skill

- Creating new diagrams for documentation
- Adding Mermaid charts to existing docs
- Updating network topology or architecture diagrams
- Troubleshooting diagram rendering issues
- Converting image-based diagrams to diagram-as-code

## Workflow

### Step 1: Determine Diagram Type

Choose the appropriate Mermaid diagram type for the content:

| Content                       | Diagram Type     | Mermaid Keyword   |
| ----------------------------- | ---------------- | ----------------- |
| System architecture, topology | Flowchart        | `graph TB` / `LR` |
| Request/response flows        | Sequence diagram | `sequenceDiagram` |
| Step-by-step processes        | Flowchart        | `flowchart TD`    |
| Decision trees                | Flowchart        | `flowchart TD`    |
| Lifecycle states              | State diagram    | `stateDiagram-v2` |
| Component relationships       | Flowchart        | `graph LR`        |

### Step 2: Choose Placement

Place the diagram in the correct file type based on WHAT/HOW/WHY separation:

- **Configuration files (WHAT):** Architecture diagrams, network topology, system design, component
  relationships
- **Procedure files (HOW):** Workflow diagrams, decision trees, step sequences, troubleshooting
  flowcharts
- **Decision files (WHY):** Option comparisons, trade-off visualizations, impact diagrams

Place diagrams near related content with a brief description before the diagram.

### Step 3: Create the Diagram

1. Write the Mermaid code block using the chosen diagram type
1. Use descriptive labels (not abbreviations)
1. Include IP addresses in network diagrams
1. Group related nodes with subgraphs
1. Match terminology used in surrounding documentation

### Step 4: Validate Rendering

1. Build the project (`mdbook build`) and verify the diagram renders
1. Run through the validation checklist below
1. If rendering fails, check the troubleshooting section in the reference

## Conventions

### Naming and Labels

- Use descriptive labels: `A[Gateway Device<br/>192.168.1.1]` not `A[GW]`
- Include IP addresses in network diagrams
- Match terms used in documentation and configuration files

### Styling Rules

- Use subgraphs for grouping related nodes
- Use colors sparingly — only for success/error distinction
- Keep diagrams simple — one concept per diagram
- Break complex diagrams into multiple focused diagrams

### Arrow Styles

- Solid arrows (`-->`) for primary flow
- Dashed arrows (`-.->`) for optional/fallback paths
- Thick arrows (`==>`) for emphasis

## Validation Checklist

Before committing:

- [ ] Diagram renders correctly (`mdbook build`)
- [ ] Labels are accurate and current
- [ ] Matches current configuration
- [ ] Terminology consistent with docs
- [ ] Appropriate diagram type for content
- [ ] Placed near related text
- [ ] Syntax validated (use [Mermaid live editor](https://mermaid.live/) if needed)
- [ ] No outdated information
- [ ] Follows styling conventions

## Common Mistakes

- Using abbreviations instead of descriptive labels
- Putting too many concepts in a single diagram
- Placing diagrams in the wrong file type (e.g., architecture in a procedure file)
- Forgetting to update diagrams when related configuration changes
- Committing diagram changes separately from related text changes

## References

See `references/diagram-reference.md` for the complete Mermaid syntax guide, diagram type examples,
image file guidelines, and troubleshooting steps.
