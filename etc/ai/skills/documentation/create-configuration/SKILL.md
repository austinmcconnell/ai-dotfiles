---
name: create-configuration
description: Create configuration specification files in documentation repositories. Use when adding a new configuration spec, documenting system design, or when asked to create a configuration file.
---

# Create Configuration

## Workflow

### Step 1: Check for existing configuration

1. List files in `configuration/` directory
1. Verify no file already covers this topic
1. If it exists, update the existing file instead of creating a new one

### Step 2: Create configuration file

1. Generate filename: `configuration/[topic-name].md` (kebab-case)
1. Use `references/configuration-template.md` as the starting structure
1. Fill in specifications — this is WHAT, not HOW

### Step 3: Update SUMMARY.md

Add the new configuration under the Configuration section:

```markdown
- [Configuration](configuration/README.md)
  - [Topic Name](configuration/topic-name.md)
```

### Step 4: Cross-reference related files

1. Link to implementation procedure: `[Procedure: XXX](../procedures/xxx-configuration.md)`
1. Link to relevant ADR: `[ADR-NNN: Title](../decisions/adr-nnn-title.md)`
1. Link to relevant components: `[Component: XXX](../components/xxx.md)`

### Step 5: Check cross-repo impact

If this configuration defines shared resources (IP addresses, switch ports, rack slots, PDU ports,
VLAN assignments), verify assignments don't conflict. See the `cross-repo-audit` skill for ownership
rules.

## Validation Checklist

- [ ] File is in `configuration/` directory with kebab-case name
- [ ] Contains specifications only (WHAT, not HOW)
- [ ] No step-by-step instructions (those belong in `procedures/`)
- [ ] No component specs (those belong in `components/`)
- [ ] Links to implementation procedure
- [ ] Cross-references use descriptive link text
- [ ] SUMMARY.md updated
- [ ] `mdbook build` succeeds

## Common Mistakes

- Including step-by-step UI instructions — those belong in `procedures/`
- Duplicating component specs from `components/` — reference instead
- Creating a configuration file that mixes specs and procedures (the most common refactoring cause)
- Forgetting to link to the corresponding procedure file
