---
name: create-role
description: Scaffold a new Ansible role with correct directory structure, defaults, meta, molecule tests, and naming conventions. Use when creating a new role, scaffolding role directories, adding a role to the project, adding molecule tests to a role, or creating a molecule scenario.
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
        ansible_docker_host: <role_name>-test

verifier:
  name: ansible

scenario:
  test_sequence:
    - dependency
    - syntax
    - create
    - prepare
    - converge
    - idempotence
    - side_effect
    - verify
    - destroy
```

Key settings explained:

- `role_name_check: 1` — validates role name matches Galaxy conventions
- `override_command: false` — uses image's default CMD (systemd); never use `command: ""`
- `privileged: true` + `cgroupns_mode: host` + cgroup volume — required for systemd in Docker
- `MOLECULE_DISTRO` env var — enables distro switching: `MOLECULE_DISTRO=ubuntu2404 molecule test`
- `ansible_host: 127.0.0.1` — required for roles that make API/HTTP calls to themselves
- `ansible_docker_host: <role_name>-test` — tells the Docker connection plugin which container to
  exec into; without this, setting `ansible_host` breaks container identification
- `ANSIBLE_ROLES_PATH: "../../../../roles"` — resolves from `molecule/default/` back to `roles/`
- `published_ports` with `MOLECULE_PUBLISHED_PORT` env var — for local debugging only; verify runs
  inside the container and does not use published ports
- `test_sequence` — explicit sequence; include `side_effect` only when a `side_effect.yml` exists

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
    - name: Wait for container to be connectable
      ansible.builtin.raw: /bin/true
      register: <role_name>_raw_wait
      until: <role_name>_raw_wait is success
      retries: 10
      delay: 3
      changed_when: false

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

The `raw` task is essential — it doesn't require a temp directory, so it works even when the
container's init process hasn't finished setting up the filesystem. Without it, the `command` module
fails with "Failed to create temporary directory" in CI.

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
        timeout: 30
```

For roles with API endpoints, a TCP port being open does NOT mean the service is ready. Always add
`until`/`retries` on API-dependent tasks:

```yaml
    - name: Login to service API
      ansible.builtin.uri:
        url: "http://127.0.0.1:<port>/api/login"
        method: POST
        body_format: form-urlencoded
        body:
          user: admin
          pass: "{{ <role_name>_admin_password }}"
      register: <role_name>_verify_login
      until: <role_name>_verify_login.json.status | default('') == 'ok'
      retries: 5
      delay: 3
```

Verify playbook rules:

- Prefix all registered variables with the role name (ansible-lint enforces this)
- Reference variables from molecule's inventory instead of hardcoding values
- Use `wait_for` with timeouts for port checks (30s+ for services that download at startup)
- Use `until`/`retries` for assertions that need the service to warm up
- Use the ansible verifier (not testinfra) for ≤15 assertions without complex loops

### Step 9b: Write side_effect.yml (optional)

Add a `side_effect.yml` when the role has an upgrade path or you want to prove it self-heals after
drift. This runs after idempotence but before verify:

```yaml
---
- name: Upgrade <service_name>
  hosts: all
  become: true
  tasks:
    - name: Re-apply role with upgrade enabled
      ansible.builtin.include_role:
        name: <role_name>
      vars:
        <role_name>_upgrade: true
```

Use `side_effect` for:

- Testing upgrade paths (re-run install with upgrade flag)
- Simulating config drift (overwrite a file, stop a service, then re-converge)
- Proving the role is self-healing

Only include `side_effect` in `test_sequence` when a `side_effect.yml` exists.

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
          cache-dependency-path: requirements.txt
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Install Galaxy collections
        run: ansible-galaxy collection install -r requirements.yml
      - name: Cache Docker image
        uses: actions/cache@v4
        with:
          path: /tmp/docker-images
          key: docker-image-<role_name>-${{ hashFiles('roles/<role_name>/molecule/default/molecule.yml') }}
      - name: Load cached Docker image
        run: |
          if [ -f /tmp/docker-images/molecule.tar ]; then
            docker load -i /tmp/docker-images/molecule.tar
          fi
      - name: Run Molecule tests
        run: molecule test
        working-directory: roles/<role_name>
        env:
          PY_COLORS: "1"
          ANSIBLE_FORCE_COLOR: "1"
          MOLECULE_DISTRO: debian12
      - name: Save Docker image to cache
        if: always()
        run: |
          mkdir -p /tmp/docker-images
          docker images --format '{{.Repository}}:{{.Tag}}' | \
            grep geerlingguy | head -1 | while read img; do
              docker save -o /tmp/docker-images/molecule.tar "$img" || true
            done
      - name: Upload Molecule logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: molecule-logs-<role_name>
          path: |
            roles/<role_name>/.cache/molecule/
            ~/.cache/molecule/
```

## Post-Implementation Verification

After lint passes, run the new role in check mode against a reachable host:

```bash
ansible-playbook playbooks/<playbook>.yml --tags <tag> --check --diff 2>&1
```

Report to the user:

1. Whether all tasks pass (note expected skips in check mode, e.g., API-based creation tasks)
1. Any deprecation warnings (with assessment: fixable in our code vs upstream collection issue)
1. Any unexpected changed/failed counts

This applies to all roles — including those without molecule tests (Layer 2 provisioning roles that
require real Proxmox API access).

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

## VM Provisioning Roles

VM provisioning roles (e.g., `vm_haos`) differ from LXC and service roles because they require disk
import via CLI — no Ansible module exists for `qm importdisk`.

### Directory structure

```text
roles/vm_<name>/
├── tasks/main.yml
├── defaults/main.yml
└── meta/main.yml
```

No molecule directory — disk import and UEFI VM creation cannot be tested in Docker containers. Add
integration tests when a test Proxmox node is available.

### Task sequence

1. Create VM via `community.proxmox.proxmox_kvm` (`state: present`, idempotent by `vmid`)
1. Check if disk is already attached (read-only `qm config` via `delegate_to`)
1. Conditionally download, decompress, import, and attach disk (wrapped in `when:` block)
1. Set boot order
1. Start VM (`state: started`)

### Disk import idempotency pattern

Re-importing over an existing disk **fails**. Guard the entire import block:

```yaml
- name: Check VM configuration
  ansible.builtin.command: qm config {{ vm_name_vmid }}
  delegate_to: "{{ vm_name_proxmox_node }}"
  become: true
  check_mode: false
  changed_when: false
  register: vm_name_config

- name: Import and attach disk
  when: "'scsi0' not in vm_name_config.stdout"
  block:
    - name: Download image
      ansible.builtin.get_url:
        url: "{{ vm_name_image_url }}"
        dest: "{{ vm_name_tempdir }}/{{ vm_name_image_filename }}"
        mode: "0644"
      delegate_to: "{{ vm_name_proxmox_node }}"

    - name: Import disk to VM
      ansible.builtin.command:
        cmd: "qm importdisk {{ vm_name_vmid }} {{ vm_name_tempdir }}/{{ vm_name_image_filename }} {{ vm_name_storage }}"
      delegate_to: "{{ vm_name_proxmox_node }}"
      become: true
      changed_when: true

    - name: Attach imported disk
      ansible.builtin.command:
        cmd: "qm set {{ vm_name_vmid }} --scsi0 {{ vm_name_storage }}:vm-{{ vm_name_vmid }}-disk-1"
      delegate_to: "{{ vm_name_proxmox_node }}"
      become: true
      changed_when: true
```

### UEFI boot configuration

VMs requiring UEFI (e.g., HAOS) need these `proxmox_kvm` parameters:

```yaml
bios: ovmf
efidisk0:
  storage: local-zfs
  format: raw
  efitype: 4m
  pre_enrolled_keys: false
machine: q35
scsihw: virtio-scsi-single
boot: "order=scsi0"
```

### When to skip molecule

Skip molecule for roles that:

- Require real Proxmox API access (`proxmox_kvm` module)
- Use `qm`/`pvesr`/`pvecm` CLI commands via `delegate_to`
- Cannot be meaningfully tested in a Docker container

Document this in the role's README and add a `# molecule: skip` comment in `meta/main.yml`.
