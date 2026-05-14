# Component File Template

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

### Purchase information

| Field         | Value                        |
| ------------- | ---------------------------- |
| Unit price    | $0.00                        |
| Quantity      | 0                            |
| Purchase date | YYYY-MM-DD                   |
| Status        | [Bought / Needed / On order] |

<!-- Prices are pre-tax, pre-shipping unit prices. -->
<!-- See content-ownership.md for pricing conventions. -->

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
