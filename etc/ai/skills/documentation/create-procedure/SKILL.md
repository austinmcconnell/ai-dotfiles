---
name: create-procedure
description: Create procedure files in documentation repositories. Use when writing step-by-step instructions, setup guides, or when asked to create a procedure file.
---

# Create Procedure

## Workflow

### Step 1: Check for existing procedure

1. List files in `procedures/` directory
1. Verify no file already covers this procedure
1. If it exists, update the existing file instead of creating a new one

### Step 2: Identify the configuration spec

Every procedure implements a configuration. Before writing steps:

1. Find the corresponding file in `configuration/`
1. If no configuration spec exists, create one first (see `create-configuration` skill)
1. Reference the configuration spec — never duplicate its values inline

### Step 3: Create procedure file

1. Generate filename: `procedures/[procedure-name].md` (kebab-case, component-specific)
1. Use `references/procedure-template.md` as the starting structure
1. Write steps that reference `configuration/` for all specification values

**Use component-specific names**, not generic ones:

- ✅ `switch-setup.md`, `gateway-configuration.md`, `proxmox-installation.md`
- ❌ `device-setup.md`, `network-configuration.md`, `initial-setup.md` (too generic)

Exception: `initial-setup.md` is acceptable when it's a sequential workflow that orchestrates
multiple component-specific procedures.

### Step 4: Update SUMMARY.md

Add the new procedure under the Procedures section:

```markdown
- [Procedures](procedures/README.md)
  - [Procedure Name](procedures/procedure-name.md)
```

### Step 5: Cross-reference related files

1. Link to configuration spec in Prerequisites: `[Configuration: XXX](../configuration/xxx.md)`
1. Link to related component: `[Component: XXX](../components/xxx.md)`
1. Link to related ADR if relevant: `[ADR-NNN: Title](../decisions/adr-nnn-title.md)`

## Validation Checklist

- [ ] File is in `procedures/` directory with kebab-case, component-specific name
- [ ] Prerequisites link to the configuration spec
- [ ] No specification values duplicated from `configuration/` — referenced instead
- [ ] Steps use imperative mood ("Navigate to", "Click", "Configure")
- [ ] Verification section with checkboxes
- [ ] Troubleshooting section (at least one common problem)
- [ ] Cross-references use descriptive link text
- [ ] SUMMARY.md updated
- [ ] `mdbook build` succeeds

## Common Mistakes

- Duplicating specification tables from `configuration/` — reference instead
- Using generic filenames (`setup.md`) instead of component-specific ones (`switch-setup.md`)
- Forgetting the Prerequisites section with a link to the configuration spec
- Omitting the Verification section — readers need to confirm success
- Omitting the Troubleshooting section — readers will hit problems
