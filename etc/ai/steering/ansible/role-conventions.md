---
paths:
  - roles/**
  - '**/roles/**'
---

# Role Conventions

## Standard Directory Structure

```text
roles/<role_name>/
├── tasks/main.yml          # Entry point (can include/import other files)
├── handlers/main.yml       # Triggered by notify
├── defaults/main.yml       # User-overridable defaults (lowest precedence)
├── vars/main.yml           # Internal constants (high precedence)
├── files/                  # Static files for copy/script modules
├── templates/              # Jinja2 templates (*.j2)
├── meta/main.yml           # Dependencies and metadata
└── molecule/default/       # Test scenario
    ├── molecule.yml
    ├── converge.yml
    └── verify.yml
```

Only include directories the role actually uses. Omit empty directories.

## When to Create a Role

Create a role when:

- Logic is reused across multiple playbooks
- The component has its own variables, templates, and handlers as a cohesive unit
- Complexity exceeds ~30 lines of tasks
- You want isolated molecule tests

Use inline tasks when:

- Tasks are specific to a single playbook and won't be reused
- Simple orchestration or glue code between roles
- Prototyping before committing to a role structure

## defaults/ vs vars/

| Directory           | Precedence       | Use for                                           |
| ------------------- | ---------------- | ------------------------------------------------- |
| `defaults/main.yml` | Level 2 (lowest) | User-facing configuration that consumers override |
| `vars/main.yml`     | Level 15 (high)  | Internal constants that should NOT be overridden  |

```yaml
# defaults/main.yml — users SHOULD override these
proxmox_base_ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
proxmox_base_timezone: America/Chicago

# vars/main.yml — internal constants
proxmox_base_enterprise_repo_file: /etc/apt/sources.list.d/pve-enterprise.list
proxmox_base_service_name: pve-cluster
```

Rule: if a user should be able to override it → `defaults/`. If changing it would break the role →
`vars/`.

## meta/main.yml

```yaml
---
dependencies: []

galaxy_info:
  role_name: proxmox_base
  author: austinmcconnell
  description: Base Proxmox VE host configuration
  license: MIT
  min_ansible_version: "2.16"
  platforms:
    - name: Debian
      versions:
        - bookworm
```

- Keep `dependencies: []` unless the role truly cannot function without another role running first
- Prefer explicit `include_role` in playbooks over implicit dependencies for loose coupling

## Task File Organization

Split `tasks/main.yml` into focused files when the role manages multiple concerns:

```yaml
# tasks/main.yml
- name: Include repository configuration
  ansible.builtin.include_tasks: repositories.yml

- name: Include kernel parameters
  ansible.builtin.include_tasks: kernel_params.yml

- name: Include ZFS configuration
  ansible.builtin.include_tasks: zfs.yml
  when: proxmox_base_zfs_enabled
```

## Role Naming

- Lowercase alphanumeric and underscores only: `[a-z][a-z0-9_]*`
- No hyphens, dots, or uppercase (ansible-lint `role-name` rule)
- Valid: `proxmox_base`, `lxc_technitium`, `vm_haos`
- Invalid: `proxmox-base`, `LXC_Technitium`
