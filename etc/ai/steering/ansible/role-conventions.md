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

## Molecule Test Conventions

### Directory Structure

```text
roles/<role_name>/molecule/default/
├── molecule.yml        # Driver, platforms, provisioner config
├── prepare.yml         # One-time setup (systemd wait)
├── converge.yml        # Applies the role under test
├── side_effect.yml     # Optional: simulate drift or test upgrade path
├── verify.yml          # Assertions over converged state
└── README.md           # Document network deps and local usage
```

### molecule.yml — Docker Driver Template

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

Key settings:

- `role_name_check: 1` — validates role name matches Galaxy conventions
- `override_command: false` — uses image's default CMD (systemd)
- `privileged: true` + `cgroupns_mode: host` + cgroup volume — required for systemd
- `MOLECULE_DISTRO` env var — enables distro switching without editing the file
- `ansible_host: 127.0.0.1` — required for roles that make API calls to themselves
- `ansible_docker_host` — tells the Docker connection plugin which container to exec into; without
  this, setting `ansible_host` breaks container identification
- `ANSIBLE_ROLES_PATH` — resolves role from `molecule/default/` back to `roles/`
- `published_ports` with env var — for local debugging only (`molecule converge`); the verify
  playbook runs inside the container and does not use published ports
- `test_sequence` — explicit sequence; include `side_effect` only when a `side_effect.yml` exists

### prepare.yml — Systemd Readiness Wait

Always include a prepare.yml that waits for systemd to finish booting inside the container:

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

### converge.yml — Role Application

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

### verify.yml — Assertion Patterns

- Use the ansible verifier (not testinfra) for ≤15 assertions without complex loops
- Prefix all registered variables with the role name (ansible-lint enforces this)
- Reference variables from molecule's inventory (e.g., `guest_technitium_admin_password`) instead of
  hardcoding values
- Test observable outcomes: service state, listening ports, API responses, file contents
- Use `wait_for` with timeouts for port checks (30s+ for services that download at startup)
- Use `until`/`retries` for assertions that may need the service to warm up

Race condition prevention — a TCP port being open does NOT mean the service is ready to handle
requests. For API-dependent verify tasks, always add `until`/`retries`:

```yaml
- name: Login to service API
  ansible.builtin.uri:
    url: "http://127.0.0.1:{{ port }}/api/login"
    method: POST
    body_format: form-urlencoded
    body:
      user: admin
      pass: "{{ role_name_admin_password }}"
  register: role_name_verify_login
  until: role_name_verify_login.json.status | default('') == 'ok'
  retries: 5
  delay: 3
```

### Network-Dependent Roles

For roles that download from the internet during converge:

- Set `timeout-minutes: 30` (or appropriate) on the CI job
- Document network dependencies in `molecule/default/README.md`
- Add `timeout:` to long-running download tasks in the role itself
- Accept that these tests will fail if the external service is down

## Role Naming

- Lowercase alphanumeric and underscores only: `[a-z][a-z0-9_]*`
- No hyphens, dots, or uppercase (ansible-lint `role-name` rule)
- Valid: `proxmox_base`, `lxc_technitium`, `vm_haos`
- Invalid: `proxmox-base`, `LXC_Technitium`
