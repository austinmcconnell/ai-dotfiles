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
   - Layer 2+3 (guest provision + config): `lxc_*` or `vm_*` or `guest_*` prefix
1. Determine if the role needs templates, files, handlers, or just tasks

### Step 2: Create directory structure

Create only the directories the role needs:

```text
roles/<role_name>/
├── tasks/main.yml
├── handlers/main.yml       # Only if tasks use notify
├── defaults/main.yml       # Only if role has configurable values
├── vars/main.yml           # Only if role has internal constants
├── vars/<OS_family>.yml    # Only if role supports multiple platforms
├── templates/              # Only if role deploys Jinja2 templates
├── files/                  # Only if role deploys static files
├── meta/main.yml
└── molecule/default/       # Add when role will be tested in CI
    ├── molecule.yml
    ├── prepare.yml
    ├── converge.yml
    ├── verify.yml
    └── README.md
```

If the role supports multiple platforms, add `vars/<OS_family>.yml` files with `__` prefixed
internal variables (see role-conventions.md Platform-Specific Variables section).

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

### Step 6: Write molecule.yml

```yaml
---
role_name_check: 1

dependency:
  name: galaxy

driver:
  name: docker

platforms:
  - name: <role_name>-test
    image: "geerlingguy/docker-${MOLECULE_DISTRO:-debian12}-ansible:latest"
    pre_build_image: true
    override_command: false
    privileged: true
    cgroupns_mode: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    tmpfs:
      - /run
      - /tmp
    published_ports:
      - "0.0.0.0:${MOLECULE_PUBLISHED_PORT:-<service_port>}:<service_port>/tcp"

provisioner:
  name: ansible
  env:
    ANSIBLE_ROLES_PATH: "../../../../roles"
  inventory:
    host_vars:
      <role_name>-test:
        ansible_host: 127.0.0.1

verifier:
  name: ansible
```

Key settings explained:

- `role_name_check: 1` — validates role name matches Galaxy conventions
- `override_command: false` — uses image's default CMD (systemd); never use `command: ""`
- `privileged: true` + `cgroupns_mode: host` + cgroup volume — required for systemd in Docker
- `tmpfs: [/run, /tmp]` — systemd expects these as tmpfs
- `MOLECULE_DISTRO` env var — enables distro switching: `MOLECULE_DISTRO=ubuntu2404 molecule test`
- `ansible_host: 127.0.0.1` — required for roles that make API/HTTP calls to themselves
- `ANSIBLE_ROLES_PATH: "../../../../roles"` — resolves from `molecule/default/` back to `roles/`
- `published_ports` with `MOLECULE_PUBLISHED_PORT` env var — enables local debugging

Omit `published_ports` if the role doesn't expose a network service.

### Step 7: Write prepare.yml

Always include a prepare.yml that waits for systemd to finish booting:

```yaml
---
- name: Prepare
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Wait for systemd to complete initialization
      ansible.builtin.command: systemctl is-system-running  # noqa command-instead-of-module
      register: <role_name>_systemctl_status
      until: >
        'running' in <role_name>_systemctl_status.stdout or
        'degraded' in <role_name>_systemctl_status.stdout
      retries: 30
      delay: 5
      changed_when: false
      failed_when: <role_name>_systemctl_status.rc > 1
```

Without this, systemd service tasks fail intermittently in Docker containers.

### Step 8: Write converge.yml

```yaml
---
- name: Converge
  hosts: all
  become: true
  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 600
      when: ansible_facts.os_family == 'Debian'
  tasks:
    - name: Apply <role_name> role
      ansible.builtin.include_role:
        name: <role_name>
```

The `pre_tasks` apt cache update prevents stale package list failures. Use `include_role` in tasks
(not the `roles:` key) for consistency with how playbooks invoke roles.

### Step 9: Write verify.yml

Test observable outcomes — service state, listening ports, API responses, file contents:

```yaml
---
- name: Verify
  hosts: all
  become: true
  gather_facts: false
  tasks:
    - name: Check service is running
      ansible.builtin.systemd:
        name: <service_name>
      register: <role_name>_verify_service

    - name: Assert service is active and enabled
      ansible.builtin.assert:
        that:
          - <role_name>_verify_service.status.ActiveState == "active"
          - <role_name>_verify_service.status.UnitFileState == "enabled"

    - name: Check service port is listening
      ansible.builtin.wait_for:
        port: <port>
        timeout: 10
```

Verify playbook rules:

- Prefix all registered variables with the role name (ansible-lint enforces this)
- Reference variables from molecule's inventory instead of hardcoding values
- Use `wait_for` with timeouts for port checks
- Use `until`/`retries` for assertions that need the service to warm up
- Use the ansible verifier (not testinfra) for ≤15 assertions without complex loops

### Step 10: Write molecule/default/README.md

Document network dependencies and local usage:

````markdown
# Molecule Tests — <role_name>

## Network Dependencies

[List any URLs the role downloads from during converge]

## Running Locally

\```bash
cd roles/<role_name>
molecule test

## Different distro

MOLECULE_DISTRO=ubuntu2404 molecule test

## Local debugging (service available at localhost:<port>)

molecule converge
\```

### What's Tested

- [List what the verify playbook checks]

### What's NOT Tested

- [List features that require full inventory or external services]
````

### Step 11: Update playbook

Add the role to the appropriate playbook with tags:

```yaml
- hosts: <target_group>
  roles:
    - role: <role_name>
      tags: [<tag>]
```

### Step 12: Add to CI workflow

Add the role to `.github/workflows/molecule.yml`. If this is the first role with Molecule tests,
create the workflow with a lint job and a molecule job per role:

```yaml
  <role_name>:
    needs: lint
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Install Galaxy collections
        run: ansible-galaxy collection install -r requirements.yml
      - name: Run Molecule tests
        run: molecule test
        working-directory: roles/<role_name>
        env:
          PY_COLORS: "1"
          ANSIBLE_FORCE_COLOR: "1"
          MOLECULE_DISTRO: debian12
      - name: Upload Molecule logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: molecule-logs-<role_name>
          path: |
            roles/<role_name>/.cache/molecule/
            ~/.cache/molecule/
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
- [ ] molecule.yml has `role_name_check: 1` and `override_command: false`
- [ ] prepare.yml waits for systemd
- [ ] converge.yml has apt cache pre_task
- [ ] verify.yml uses role-prefixed variables and references inventory vars
- [ ] Network dependencies documented in README.md
- [ ] Role added to CI workflow with timeout and artifact upload
