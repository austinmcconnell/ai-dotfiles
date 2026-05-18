---
name: create-playbook
description: Create Ansible playbooks following project conventions for layered Proxmox automation. Use when creating a new playbook, adding a service playbook, or structuring play execution order.
---

# Create Playbook

## Workflow

### Step 1: Determine playbook type and placement

| Type    | Location                        | Purpose                       |
| ------- | ------------------------------- | ----------------------------- |
| Master  | `playbooks/site.yml`            | Full convergence (all layers) |
| Layer 1 | `playbooks/hosts.yml`           | Host-level config only        |
| Layer 2 | `playbooks/provision.yml`       | Guest provisioning only       |
| Layer 3 | `playbooks/services/<name>.yml` | Per-service config            |

### Step 2: Choose the correct play structure

**Layer 1 — Direct SSH to hosts:**

```yaml
---
- name: Configure Proxmox VE hosts
  hosts: proxmox
  become: true
  roles:
    - role: proxmox_base
      tags: [base]
```

**Layer 2 — API calls from localhost:**

```yaml
---
- name: Provision guests via Proxmox API
  hosts: localhost
  connection: local
  gather_facts: false
  module_defaults:
    group/community.general.proxmox:
      api_host: "{{ proxmox_api_host }}"
      api_user: "{{ proxmox_api_user }}"
      api_token_id: "{{ proxmox_token_id }}"
      api_token_secret: "{{ proxmox_token_secret }}"
      validate_certs: false
  roles:
    - role: lxc_technitium
      tags: [technitium]
```

**Layer 3 — SSH into guests:**

```yaml
---
- name: Configure Technitium DNS
  hosts: dns
  become: true
  roles:
    - role: technitium_config
      tags: [technitium]
```

### Step 3: Apply conventions

- Start file with `---`
- Every play must have a `name:`
- Use `become: true` for privilege escalation (not per-task)
- Use `serial: 1` for rolling updates across cluster nodes
- Use `module_defaults` for Proxmox API auth (never repeat per-task)
- Add tags at the role level for selective execution
- Use `gather_facts: false` for API-only plays (localhost)

### Step 4: Wire into site.yml

If creating a new service playbook, import it from `site.yml`:

```yaml
# playbooks/site.yml
---
- name: Configure hosts
  ansible.builtin.import_playbook: hosts.yml

- name: Provision guests
  ansible.builtin.import_playbook: provision.yml

- name: Configure Technitium DNS
  ansible.builtin.import_playbook: services/technitium.yml
```

## Validation Checklist

- [ ] File starts with `---`
- [ ] Every play has a descriptive `name:`
- [ ] Correct `hosts:` target for the layer
- [ ] `connection: local` and `gather_facts: false` for API plays
- [ ] `module_defaults` used for Proxmox auth (not repeated per-task)
- [ ] Roles have tags for selective execution
- [ ] Playbook imported from `site.yml` if applicable
- [ ] `ansible-lint` passes on the new file
