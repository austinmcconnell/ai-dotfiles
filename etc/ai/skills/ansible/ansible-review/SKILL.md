---
name: ansible-review
description: Review Ansible code for anti-patterns, lint compliance, idempotency issues, and variable precedence mistakes. Use when reviewing Ansible roles, playbooks, or task files, or when asked to check Ansible code quality.
---

# Ansible Review

## Workflow

### Step 1: Run ansible-lint

```bash
ansible-lint <file_or_directory>
```

If ansible-lint is not available, perform manual review against the rules below.

### Step 1b: Check for deprecation warnings

If a target host is reachable, run the playbook in check mode and look for deprecation warnings:

```bash
ansible-playbook playbooks/<playbook>.yml --limit <host> --check 2>&1 | grep -i "DEPRECATION WARNING"
```

Deprecation warnings fire based on code patterns, not host state — they appear on every run until
the code is fixed. Treat them as suggestions unless the removal version is imminent.

Common deprecation patterns:

- `{{ ansible_* }}` top-level facts → use `{{ ansible_facts['*'] }}`
- `include:` → use `ansible.builtin.include_tasks:` or `ansible.builtin.import_tasks:`
- Module-specific parameter renames (check the warning text for guidance)

### Step 2: Check for anti-patterns

Review each file against these categories, ordered by severity:

**Blockers:**

- Missing FQCN (`fqcn[action-core]`, `fqcn[action]`)
- `command`/`shell` used when a module exists (`command-instead-of-module`)
- Missing `changed_when` on command/shell tasks (`no-changed-when`)
- Missing task names (`name[missing]`)
- Hardcoded secrets or credentials in plain text
- Non-idempotent operations without guards (`creates:`, `when:`, or `changed_when:`)

**Suggestions:**

- Variables not prefixed with role name (`var-naming[no-role-prefix]`)
- User-configurable values in `vars/main.yml` instead of `defaults/main.yml`
- Missing explicit `mode:` on file/copy/template (`risky-file-permissions`)
- `yaml[truthy]` — using `yes`/`no` instead of `true`/`false`
- `shell` used without shell features (`command-instead-of-shell`)
- Repeated Proxmox API auth instead of `module_defaults`
- Missing tags on roles in playbooks
- Service/package tasks missing `ignore_errors: "{{ ansible_check_mode }}"` (causes false failures
  in `--check` mode when packages aren't installed yet)

**Nits:**

- Jinja2 spacing (`{{ var }}` not `{{var}}`)
- Task name casing (`name[casing]`)
- File naming inconsistency (`.yml` vs `.yaml`)

### Step 3: Check variable precedence

- Are user-facing values in `defaults/main.yml`? (not `vars/main.yml`)
- Are role variables prefixed with the role name?
- Is `set_fact` used only for computed values, not static config?
- Are group_vars organized correctly (all.yml vs group-specific)?

### Step 4: Check idempotency

- Can the playbook be run twice without changes on the second run?
- Do command/shell tasks have proper change detection?
- Are Proxmox operations using fixed `vmid` values?
- Do template/copy tasks only write when content differs? (they do by default)

To verify idempotency in practice:

- **Molecule:** `molecule test` runs converge twice and asserts zero changes on the second run
- **Manual:** Run the playbook twice with `--check --diff` — the second run should report no changes
- **CI:** Use a `test_idempotence` flag that runs the playbook a second time and fails if `changed=`
  is non-zero

### Step 5: Check Proxmox-specific patterns

- API auth via `module_defaults`, not repeated per-task
- `validate_certs: false` set (self-signed certs in homelab)
- Fixed `vmid` for all guests (prevents duplicate creation)
- Correct `state:` values for desired outcome
- `update: true` set when modifying existing guest config

## Output Format

```text
[BLOCKER|SUGGESTION|NIT] file:line — description
```

Group by file. End with summary: lint-clean, needs changes, or needs discussion.
