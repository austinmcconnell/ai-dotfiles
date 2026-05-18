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
