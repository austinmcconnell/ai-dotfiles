---
paths:
  - '**/*.yml'
  - '**/*.yaml'
  - '**/ansible*'
---

# Naming Conventions

## Task Names

Every task must have a `name:` (ansible-lint `name[missing]`). Names must:

- Start with an uppercase letter (`name[casing]`)
- Not use Jinja2 templating (`name[template]`)
- Be descriptive of what the task does

```yaml
# ❌ Bad
- name: do thing
  ansible.builtin.apt:
    name: nginx

# ❌ Bad — templated name
- name: "Install {{ package_name }}"
  ansible.builtin.apt:
    name: "{{ package_name }}"

# ✅ Good
- name: Install nginx web server
  ansible.builtin.apt:
    name: nginx
```

## Variable Names

- `snake_case` only: `^[a-z_][a-z0-9_]*$` (ansible-lint `var-naming[pattern]`)
- Prefix with role name in roles: `proxmox_base_ntp_servers` not `ntp_servers`
  (`var-naming[no-role-prefix]`)
- No Python keywords, Ansible reserved names, or Jinja2 templating in names
- No uppercase, hyphens, or dots

```yaml
# ❌ Bad
NTP_Servers: []
my-variable: true

# ✅ Good
proxmox_base_ntp_servers: []
proxmox_base_enable_firewall: true
```

## Tag Conventions

Tags enable selective execution. Use them on roles and logical task groups:

```yaml
# Playbook-level tags
- hosts: proxmox_nodes
  roles:
    - role: proxmox_base
      tags: [base]
    - role: proxmox_cluster
      tags: [cluster]

# Task-level tags for granular control
- name: Configure APT repositories
  ansible.builtin.include_tasks: repositories.yml
  tags: [repositories]
```

Tag naming rules:

- Lowercase, single-word or hyphenated: `base`, `networking`, `igpu-passthrough`
- Use `never` tag for tasks that should only run when explicitly requested
- Use `always` tag sparingly — only for tasks that must run regardless of tag filtering

## File Naming

- All YAML files use `.yml` extension (not `.yaml`) for consistency
- Task files: descriptive kebab or snake case — `repositories.yml`, `kernel_params.yml`
- Template files: match the target filename with `.j2` suffix — `interfaces.j2`, `sysctl.conf.j2`
- Variable files: `main.yml` for primary, OS-family names for platform-specific (`Debian.yml`,
  `RedHat.yml`)

## Playbook Naming

- Use descriptive names matching the purpose: `site.yml`, `hosts.yml`, `provision.yml`
- Service-specific playbooks in subdirectory: `playbooks/services/technitium.yml`
- Prefix with layer when helpful: `host-config.yml`, `guest-provision.yml`

## Handler Names

- Must be globally unique across all roles in a play
- Descriptive of the action: `Restart nginx`, `Reload systemd`, `Update GRUB`
- Start with a verb (capitalized)

```yaml
# handlers/main.yml
- name: Restart pveproxy
  ansible.builtin.systemd:
    name: pveproxy
    state: restarted

- name: Update initramfs
  ansible.builtin.command: update-initramfs -u -k all
  changed_when: true
```

## Jinja2 Spacing

Ansible-lint enforces consistent spacing in Jinja2 expressions:

```yaml
# ❌ Bad — no spaces
- name: Set hostname
  ansible.builtin.hostname:
    name: "{{inventory_hostname}}"

# ✅ Good — spaces inside braces
- name: Set hostname
  ansible.builtin.hostname:
    name: "{{ inventory_hostname }}"
```

## ansible-lint Profile

Use the `shared` profile as baseline. Key rules enforced:

| Rule                         | What it checks                               |
| ---------------------------- | -------------------------------------------- |
| `name[missing]`              | All tasks have names                         |
| `name[casing]`               | Task names start uppercase                   |
| `name[template]`             | No Jinja2 in task names                      |
| `var-naming[pattern]`        | snake_case variables                         |
| `var-naming[no-role-prefix]` | Role variables are prefixed                  |
| `fqcn[action-core]`          | FQCN for builtin modules                     |
| `yaml[truthy]`               | Use `true`/`false` not `yes`/`no`            |
| `risky-file-permissions`     | Explicit file mode on file/copy/template     |
| `no-changed-when`            | command/shell tasks declare change detection |
| `role-name`                  | Lowercase alphanumeric + underscore          |
