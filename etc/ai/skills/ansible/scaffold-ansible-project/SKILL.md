---
name: scaffold-ansible-project
description: Create new ansible projects from the cookiecutter-ansible template or update existing ones. Use when creating a new ansible project, scaffolding ansible infrastructure, running cruft create, or updating a project from the ansible template.
---

# Scaffold Ansible Project

## Workflow 1: Create New Project

### Step 1: Generate from template

```bash
cruft create https://github.com/austinmcconnell/cookiecutter-ansible
```

Or from local path during development:

```bash
cruft create ~/projects/austinmcconnell/cookiecutter-ansible
```

Provide values for: `project_name`, `project_slug`, `author_name`, `github_username`.

### Step 2: Initialize the environment

```bash
cd <project_slug>
make venv
make install-deps
```

Verify setup:

```bash
make lint
```

### Step 3: Scaffold project-specific structure

Ask the user about their infrastructure target:

1. **Topology**: single-host, multi-host, or multi-layer (Proxmox-style)?
1. **Target hosts**: hostnames or IPs?
1. **Connection method**: SSH, API (Proxmox), or both?
1. **What are you automating?** (brief description to determine collections needed)

### Step 4: Generate inventory

**Single-host:**

```yaml
# inventory/production/hosts.yml
---
all:
  hosts:
    <hostname>:
      ansible_host: <ip_or_hostname>
```

**Multi-host (flat groups):**

```yaml
# inventory/production/hosts.yml
---
all:
  children:
    <group_name>:
      hosts:
        <host1>:
          ansible_host: <ip>
        <host2>:
          ansible_host: <ip>
```

**Multi-layer (Proxmox pattern):**

```yaml
# inventory/production/hosts.yml
---
all:
  children:
    proxmox:
      hosts:
        <node1>:
          ansible_host: <ip>
    vms:
      hosts: {}
    lxc:
      hosts: {}
```

### Step 5: Generate playbooks

**Single-host / multi-host:**

```yaml
# playbooks/site.yml
---
- name: Configure <target>
  hosts: all
  become: true
  roles: []
```

**Multi-layer:**

```yaml
# playbooks/site.yml
---
- name: Configure hosts
  ansible.builtin.import_playbook: host-config.yml

- name: Provision guests
  ansible.builtin.import_playbook: provision-guests.yml

- name: Configure guests
  ansible.builtin.import_playbook: guest-config.yml
```

Create the corresponding playbook files with appropriate `hosts:`, `connection:`, and
`module_defaults:` settings per layer.

### Step 6: Update requirements.yml

Add collections relevant to the target. Common mappings:

| Target                | Collections                          |
| --------------------- | ------------------------------------ |
| Proxmox               | `community.general`                  |
| Docker-based services | `community.docker`                   |
| General Linux         | `community.general`, `ansible.posix` |
| Network devices       | `ansible.netcommon`                  |

Pin version ranges: `version: ">=9.0.0,<10.0.0"`

### Step 7: Install collections and verify

```bash
make install-deps
make lint
```

## Workflow 2: Update Existing Project from Template

### Step 1: Check for updates

```bash
cruft check
```

If exit code 0, the project is up-to-date. Done.

### Step 2: Review changes

```bash
cruft diff
```

Show the diff to the user. Explain what changed in the template (new lint rules, version bumps, CI
improvements, etc).

### Step 3: Apply updates

Only after user approval:

```bash
cruft update
```

Review any merge conflicts. The `.cruft.json` skip list can exclude files the user has customized
beyond the template's scope.

## Notes

- Use `cruft create` instead of `cookiecutter` — the template is compatible with both, but cruft
  adds a `.cruft.json` tracking file that enables `cruft check`/`cruft update` to pull in template
  improvements later. Use plain `cookiecutter` only if cruft is unavailable.
- The template generates only invariant tooling files — lint config, CI, Makefile, gitignore
- All project-specific content (inventory, playbooks, roles, variables) is created in Steps 3–6
- For role scaffolding within an existing project, use the `create-role` skill instead
- For playbook creation within an existing project, use the `create-playbook` skill instead
