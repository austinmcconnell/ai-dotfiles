---
paths:
  - '**/group_vars/**'
  - '**/host_vars/**'
  - '**/defaults/**'
  - '**/vars/**'
---

# Variable Precedence

Ansible has 22 precedence levels. Getting placement wrong causes subtle bugs where values silently
override each other.

## Where to Define Variables

| Use case                | Location                    | Precedence   |
| ----------------------- | --------------------------- | ------------ |
| Role sensible defaults  | `roles/x/defaults/main.yml` | 2 (lowest)   |
| Site-wide settings      | `group_vars/all.yml`        | 4–5          |
| Group-specific config   | `group_vars/<group>.yml`    | 6–7          |
| Host-specific overrides | `host_vars/<host>.yml`      | 9–10         |
| Play-specific settings  | `vars:` or `vars_files:`    | 12/14        |
| Internal role constants | `roles/x/vars/main.yml`     | 15           |
| Runtime-computed values | `set_fact`                  | 19           |
| Emergency/CI overrides  | `-e` extra vars             | 22 (highest) |

## Placement Rules for This Project

1. **Maximize `group_vars/`, minimize `host_vars/`** — identical nodes share values in
   `group_vars/proxmox.yml`. Only truly unique values (IP, node ID) go in `host_vars/`.
1. **Role defaults for tunables** — ports, feature flags, package versions go in `defaults/main.yml`
   so they're overridable per-group or per-host.
1. **Role vars for constants only** — package names, fixed paths, systemd unit names that never
   change.
1. **Derive from inventory when possible** — use `{{ ansible_host }}` and `{{ inventory_hostname }}`
   instead of hardcoding per-host values.
1. **Extra vars for one-off overrides only** — never rely on `-e` for normal operation.

## Common Pitfalls

### vars/main.yml overrides group_vars

Role `vars/main.yml` (level 15) beats `group_vars/` (levels 4–7). Never put user-configurable values
in `vars/main.yml`.

```yaml
# ❌ WRONG — users cannot override from group_vars
# roles/webserver/vars/main.yml
http_port: 80

# ✅ CORRECT — put in defaults/main.yml instead
# roles/webserver/defaults/main.yml
webserver_port: 80
```

### set_fact persists across plays

`set_fact` variables (level 19) persist for the entire playbook run on that host. They override
group_vars AND role vars in subsequent plays.

```yaml
# ❌ DANGEROUS — bleeds into later plays
- ansible.builtin.set_fact:
    http_port: 9090
```

Use `set_fact` only for genuinely computed runtime values, not static configuration.

### Variable scope leaks between roles

Variables from one role's `vars/main.yml` are visible to subsequent roles in the same play. Always
prefix variables with the role name to prevent collisions.

```yaml
# ❌ Generic name — collides across roles
packages:
  - nginx

# ✅ Prefixed — no collision
proxmox_base_packages:
  - proxmox-ve
```

## Precedence Hierarchy (Full Reference)

From lowest to highest:

1. Command-line values (`-u`, `-b` — NOT `-e`)
1. Role defaults (`defaults/main.yml`)
1. Inventory file group vars
1. Inventory `group_vars/all`
1. Playbook `group_vars/all`
1. Inventory `group_vars/*`
1. Playbook `group_vars/*`
1. Inventory file host vars
1. Inventory `host_vars/*`
1. Playbook `host_vars/*`
1. Host facts / cached `set_facts`
1. Play `vars:`
1. Play `vars_prompt`
1. Play `vars_files`
1. Role vars (`vars/main.yml`)
1. Block vars
1. Task vars
1. `include_vars`
1. `set_facts` / registered vars
1. Role params (via `include_role`)
1. `include` params
1. Extra vars (`-e`) — always wins
