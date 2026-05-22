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

## Platform-Specific Variables

For roles that support multiple distributions, use platform-specific vars files with a
double-underscore prefix (`__`) for internal values:

```text
roles/<role_name>/
└── vars/
    ├── Debian.yml
    ├── RedHat.yml
    └── main.yml        # Empty or shared constants
```

```yaml
# vars/Debian.yml
__rolename_package: ntp
__rolename_service: ntp
__rolename_config_file: /etc/ntp.conf

# vars/RedHat.yml
__rolename_package: chrony
__rolename_service: chronyd
__rolename_config_file: /etc/chrony.conf
```

Load with `include_vars` and a `first_found` fallback chain at the top of `tasks/main.yml`:

```yaml
- name: Include OS-specific variables
  ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - "{{ ansible_facts.distribution }}-{{ ansible_facts['distribution_version'] }}.yml"
    - "{{ ansible_facts.os_family }}.yml"
    - main.yml
```

Promote `__` vars to public names via `set_fact` so users can override from `group_vars`:

```yaml
- name: Set platform-specific defaults
  ansible.builtin.set_fact:
    rolename_package: "{{ __rolename_package }}"
  when: rolename_package is not defined
```

## Defaults Documentation Style

Document `defaults/main.yml` with inline comments. Group related variables with blank lines as
separators. Use flat YAML (no nested dicts for configuration groups):

```yaml
---
# Service control
rolename_enabled: true
rolename_manage_config: true

# Network configuration
rolename_port: 8080
rolename_bind_address: "0.0.0.0"

# Package version (empty string = latest)
rolename_version: ""

# Platform-specific values — set dynamically from vars/ files.
# Override in group_vars to force a specific value.
# rolename_package: [varies by OS]
# rolename_service: [varies by OS]
```

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

## Handler Conventions

Handler names must be globally unique, start with a capitalized verb, and describe the action:
`Restart nginx`, `Reload systemd`, `Update GRUB`.

Use variables for service names so handlers work with platform-specific values:

```yaml
# handlers/main.yml
- name: Restart ntp
  ansible.builtin.service:
    name: "{{ rolename_service }}"
    state: "{{ rolename_restart_handler_state }}"
  when: rolename_enabled | bool
  ignore_errors: "{{ ansible_check_mode }}"
```

Expose handler state as a default so users can suppress restarts during maintenance:

```yaml
# defaults/main.yml
rolename_restart_handler_state: restarted
```

## Service Tasks and Check Mode

Service and package tasks may fail during `--check` mode because the package isn't actually
installed yet. Use `ignore_errors: "{{ ansible_check_mode }}"` to prevent false failures:

```yaml
- name: Ensure service is running and enabled
  ansible.builtin.service:
    name: "{{ rolename_service }}"
    state: started
    enabled: true
  when: rolename_enabled | bool
  ignore_errors: "{{ ansible_check_mode }}"
```

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
