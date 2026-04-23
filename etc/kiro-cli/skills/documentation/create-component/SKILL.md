---
name: create-component
description: Create component specification files in documentation repositories. Use when adding a new component, documenting hardware or software specs, or when asked to create a component file.
---

# Create Component

## Workflow

### Step 1: Check for existing component

1. List files in `components/` directory
1. Verify no file already covers this component
1. If it exists, update the existing file instead of creating a new one

### Step 2: Create component file

1. Generate filename: `components/[component-name].md` (kebab-case)
1. Use `references/component-template.md` as the starting structure
1. Fill in specifications from available information

### Step 3: Update BOM (if project uses one)

If `components/bom.md` exists:

1. Add a row for each purchasable item in the new component
1. Link to the component file
1. Use specific product names, not generic categories
1. Match the unit price from the component file

### Step 4: Update SUMMARY.md

Add the new component under the Components section:

```markdown
- [Components](components/README.md)
  - [Component Name](components/component-name.md)
```

Keep entries alphabetical unless logical ordering is more appropriate.

### Step 5: Cross-reference related files

1. Link to relevant configuration specs: `[Configuration: XXX](../configuration/xxx.md)`
1. Link to setup procedure if one exists: `[Procedure: XXX Setup](../procedures/xxx-setup.md)`
1. Link to selection ADR if one exists: `[ADR-NNN: Title](../decisions/adr-nnn-title.md)`

### Step 6: Check cross-repo impact

If this component uses shared resources (IP addresses, switch ports, rack slots, PDU ports), verify
assignments don't conflict. See the `cross-repo-audit` skill for ownership rules.

## Validation Checklist

- [ ] File is in `components/` directory with kebab-case name
- [ ] Specifications are factual (not configuration or procedures)
- [ ] Purchase information uses pre-tax, pre-shipping unit prices
- [ ] Purchase info includes all required fields: unit price, quantity, purchase date, status
- [ ] No configuration specs included (those belong in `configuration/`)
- [ ] No implementation steps included (those belong in `procedures/`)
- [ ] Cross-references use descriptive link text
- [ ] BOM updated (if project uses one)
- [ ] SUMMARY.md updated
- [ ] `mdbook build` succeeds

## Common Mistakes

- Including configuration specs (IP addresses, VLAN assignments) — those belong in `configuration/`
- Including setup steps — those belong in `procedures/`
- Using generic names in BOM ("Case fans") instead of specific products ("Noctua NF-A12x25 PWM")
- Forgetting to update BOM and SUMMARY.md
