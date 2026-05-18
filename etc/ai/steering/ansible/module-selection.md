---
paths:
  - '**/tasks/**'
  - '**/playbooks/**'
---

# Module Selection

## FQCN Requirement

Always use Fully Qualified Collection Names. Short module names trigger ansible-lint `fqcn` rules.

```yaml
# ❌ Triggers fqcn[action-core]
- name: Install package
  apt:
    name: nginx

# ✅ Correct
- name: Install package
  ansible.builtin.apt:
    name: nginx
```

Do not use the `collections:` keyword — use FQCN directly in each task.

## Module Preference Hierarchy

```text
ansible.builtin.<specific_module>  →  always preferred
ansible.builtin.command            →  when no module exists, no shell features needed
ansible.builtin.shell              →  only when pipes, redirects, or env vars required
ansible.builtin.raw                →  only for pre-Python bootstrap
```

Using `command`/`shell` when a module exists triggers `command-instead-of-module`. Using `shell`
without shell features triggers `command-instead-of-shell`.

## changed_when for Command Tasks

All `command`, `shell`, `raw`, and `script` tasks must declare change detection (`no-changed-when`
rule):

```yaml
# Read-only command — never changes state
- name: Check disk space
  ansible.builtin.command: df -h /
  changed_when: false

# Determine change from output
- name: Run migration
  ansible.builtin.command: /opt/app/migrate
  register: migrate_result
  changed_when: "'Applied' in migrate_result.stdout"

# Use creates/removes as alternative
- name: Initialize database
  ansible.builtin.command: /opt/app/init-db
  args:
    creates: /var/lib/app/db.sqlite
```

## Common Module Mappings

| Short name       | FQCN                             |
| ---------------- | -------------------------------- |
| `apt`            | `ansible.builtin.apt`            |
| `apt_repository` | `ansible.builtin.apt_repository` |
| `copy`           | `ansible.builtin.copy`           |
| `template`       | `ansible.builtin.template`       |
| `file`           | `ansible.builtin.file`           |
| `lineinfile`     | `ansible.builtin.lineinfile`     |
| `blockinfile`    | `ansible.builtin.blockinfile`    |
| `service`        | `ansible.builtin.service`        |
| `systemd`        | `ansible.builtin.systemd`        |
| `user`           | `ansible.builtin.user`           |
| `group`          | `ansible.builtin.group`          |
| `sysctl`         | `ansible.builtin.sysctl`         |
| `mount`          | `ansible.builtin.mount`          |
| `reboot`         | `ansible.builtin.reboot`         |
| `get_url`        | `ansible.builtin.get_url`        |
| `uri`            | `ansible.builtin.uri`            |
| `stat`           | `ansible.builtin.stat`           |
| `debug`          | `ansible.builtin.debug`          |
| `set_fact`       | `ansible.builtin.set_fact`       |
| `assert`         | `ansible.builtin.assert`         |
| `include_tasks`  | `ansible.builtin.include_tasks`  |
| `import_tasks`   | `ansible.builtin.import_tasks`   |
| `include_role`   | `ansible.builtin.include_role`   |
| `wait_for`       | `ansible.builtin.wait_for`       |

## Proxmox Modules

| Module                          | Purpose                 |
| ------------------------------- | ----------------------- |
| `community.general.proxmox`     | LXC container lifecycle |
| `community.general.proxmox_kvm` | KVM/QEMU VM lifecycle   |

Use `module_defaults` to avoid repeating API auth on every task:

```yaml
- hosts: localhost
  connection: local
  module_defaults:
    group/community.general.proxmox:
      api_host: "{{ proxmox_api_host }}"
      api_user: "{{ proxmox_api_user }}"
      api_token_id: "{{ proxmox_token_id }}"
      api_token_secret: "{{ proxmox_token_secret }}"
      validate_certs: false
```

## Collection Dependencies

Pin versions in `requirements.yml`:

```yaml
---
collections:
  - name: community.general
    version: ">=9.0.0,<10.0.0"
  - name: ansible.posix
    version: ">=1.5.0,<2.0.0"
```
