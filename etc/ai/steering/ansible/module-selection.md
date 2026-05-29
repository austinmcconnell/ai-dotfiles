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

## check_mode and failed_when for Command Tasks

For read-only commands that register variables used in later `when:` conditions, add
`check_mode: false` to ensure they execute during `--check` mode:

```yaml
# Runs even in --check mode so the registered variable is available
- name: Check current application version
  ansible.builtin.command: /opt/app/version
  register: app_version
  check_mode: false
  changed_when: false
  failed_when: false
```

Use `failed_when: false` when a command might legitimately fail (e.g., checking if a binary exists
before installation):

```yaml
# Binary may not exist yet — that's expected
- name: Check if docker-compose is installed
  ansible.builtin.command: docker-compose --version
  register: compose_check
  check_mode: false
  changed_when: false
  failed_when: false

- name: Install docker-compose
  ansible.builtin.get_url:
    url: "{{ docker_compose_url }}"
    dest: /usr/local/bin/docker-compose
    mode: "0755"
  when: compose_check.rc != 0
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

| Module                                   | Purpose                   |
| ---------------------------------------- | ------------------------- |
| `community.proxmox.proxmox`              | LXC container lifecycle   |
| `community.proxmox.proxmox_kvm`          | KVM/QEMU VM lifecycle     |
| `community.proxmox.proxmox_vm_info`      | Query VM/CT information   |
| `community.proxmox.proxmox_storage_info` | Query storage information |

Use `module_defaults` to avoid repeating API auth on every task:

```yaml
- hosts: localhost
  connection: local
  module_defaults:
    group/community.proxmox.proxmox:
      api_host: "{{ proxmox_api_host }}"
      api_user: "{{ proxmox_api_user }}"
      api_token_id: "{{ proxmox_token_id }}"
      api_token_secret: "{{ proxmox_token_secret }}"
      validate_certs: false
```

## Proxmox CLI Operations

Some Proxmox operations have no module equivalent and require `command`/`shell` with `delegate_to`:

| Command          | Purpose                            | Why no module                        |
| ---------------- | ---------------------------------- | ------------------------------------ |
| `qm disk import` | Import disk image to VM            | No module for disk import            |
| `qm set`         | Attach unused disk, set boot order | No module for post-import attachment |
| `pvesr`          | ZFS replication job management     | No module exists                     |
| `pvecm`          | Cluster create/join/status         | No module exists                     |
| `pvesh`          | Generic API access from CLI        | Fallback for uncovered endpoints     |

Additionally, some operations that the module *supports syntactically* are **restricted to
`root@pam` by the Proxmox API** — any non-root token (even with `PVEAdmin` role) gets
`403 Forbidden`. Use `pct set`/`qm set` via CLI as root instead:

| Operation                       | Module parameter | Why CLI required                         |
| ------------------------------- | ---------------- | ---------------------------------------- |
| LXC bind mount (host path)      | `mount_volumes`  | `root@pam` only — host filesystem access |
| LXC device passthrough (`dev0`) | Not supported    | `root@pam` only — host device access     |
| Custom LXC config options       | N/A              | `root@pam` only — arbitrary config risk  |

```yaml
# Pattern: create container via API (token auth), then configure
# privileged options via CLI (root SSH)
- name: Create LXC container
  community.proxmox.proxmox:
    vmid: "{{ container_vmid }}"
    state: present
    # ... standard options work fine with token auth

- name: Check container configuration
  ansible.builtin.command: /usr/sbin/pct config {{ container_vmid }}
  delegate_to: "{{ proxmox_node }}"
  vars:
    ansible_connection: ssh
  check_mode: false
  changed_when: false
  failed_when: false
  register: container_config

- name: Configure bind mount (requires root)
  ansible.builtin.command: >-
    /usr/sbin/pct set {{ container_vmid }}
    --mp0 /mnt/data,mp=/mnt/data
  delegate_to: "{{ proxmox_node }}"
  vars:
    ansible_connection: ssh
  changed_when: true
  when: "container_config.rc == 0 and 'mp0' not in container_config.stdout"
```

Pattern: check state first, then conditionally execute with proper guards:

```yaml
- name: Check current VM configuration
  ansible.builtin.command: /usr/sbin/qm config {{ vm_vmid }}
  delegate_to: "{{ proxmox_node }}"
  vars:
    ansible_connection: ssh
  check_mode: false
  changed_when: false
  register: vm_config

- name: Import disk to VM
  ansible.builtin.command:
    cmd: "/usr/sbin/qm disk import {{ vm_vmid }} /tmp/image.qcow2 local-zfs"
  delegate_to: "{{ proxmox_node }}"
  vars:
    ansible_connection: ssh
  changed_when: true
  when: "'scsi0' not in vm_config.stdout"
```

Key requirements for delegated CLI tasks:

- **`vars: {ansible_connection: ssh}`** is mandatory — without it, `delegate_to` from a
  `connection: local` play silently runs tasks locally (known Ansible behavior, not a bug)
- **Full path** (`/usr/sbin/qm`, `/usr/sbin/pvesr`) — delegated SSH sessions may not have
  `/usr/sbin` in PATH
- **`become: true` is NOT needed** when the Proxmox node's `ansible_user` is `root` (the typical
  configuration for this project)
- The delegated host must be in inventory with SSH access configured

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
