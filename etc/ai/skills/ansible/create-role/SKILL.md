---
name: create-role
description: Scaffold a new Ansible role with correct directory structure, defaults, meta, and naming conventions. Use when creating a new role, scaffolding role directories, or adding a role to the project.
---

# Create Role

## Workflow

### Step 1: Determine role name and purpose

1. Confirm the role name follows naming rules: lowercase alphanumeric + underscores, starts with
   alpha (e.g., `proxmox_base`, `lxc_technitium`)
1. Identify which layer the role belongs to:
   - Layer 1 (host config): `proxmox_*` prefix
   - Layer 2+3 (guest provision + config): `lxc_*` or `vm_*` prefix
1. Determine if the role needs templates, files, handlers, or just tasks

### Step 2: Create directory structure

Create only the directories the role needs:

```text
roles/<role_name>/
├── tasks/main.yml
├── handlers/main.yml       # Only if tasks use notify
├── defaults/main.yml       # Only if role has configurable values
├── vars/main.yml           # Only if role has internal constants
├── templates/              # Only if role deploys Jinja2 templates
├── files/                  # Only if role deploys static files
├── meta/main.yml
└── molecule/default/       # Optional — add if role will be tested in CI
    ├── molecule.yml
    ├── converge.yml
    └── verify.yml
```

### Step 3: Write meta/main.yml

```yaml
---
dependencies: []

galaxy_info:
  role_name: <role_name>
  author: austinmcconnell
  description: <one-line description>
  license: MIT
  min_ansible_version: "2.16"
  platforms:
    - name: Debian
      versions:
        - bookworm
```

### Step 4: Write defaults/main.yml

- Prefix every variable with the role name: `<role_name>_<variable>`
- Include only values users should override
- Add a comment header explaining the role's purpose

```yaml
---
# Defaults for <role_name>
<role_name>_enabled: true
```

### Step 5: Write tasks/main.yml

- Every task must have a `name:` starting with an uppercase letter
- Use FQCN for all modules
- Set explicit `mode:` on file/copy/template tasks
- Add `changed_when` to any command/shell tasks
- Split into included files if the role manages multiple concerns

### Step 6: Update playbook

Add the role to the appropriate playbook with tags:

```yaml
- hosts: <target_group>
  roles:
    - role: <role_name>
      tags: [<tag>]
```

## Validation Checklist

- [ ] Role name matches `[a-z][a-z0-9_]*` pattern
- [ ] All variables prefixed with role name
- [ ] `meta/main.yml` has dependencies and galaxy_info
- [ ] `defaults/main.yml` for user-configurable values only
- [ ] `vars/main.yml` for internal constants only (if present)
- [ ] Every task has a name starting with uppercase
- [ ] All modules use FQCN
- [ ] File/copy/template tasks have explicit `mode:`
- [ ] Command/shell tasks have `changed_when`
- [ ] No empty directories in the role
- [ ] Role added to appropriate playbook with tags
