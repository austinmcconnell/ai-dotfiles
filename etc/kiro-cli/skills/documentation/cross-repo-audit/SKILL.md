---
name: cross-repo-audit
description: Audit shared resource assignments across multiple documentation repositories for conflicts and stale cross-references. Use when checking cross-repo consistency, validating shared resource assignments (rack slots, switch ports, PDU ports, IP addresses), or before committing changes that affect resources shared between repos. Also use when adding a new device to shared infrastructure, checking if a port or IP is available, or looking for inconsistencies across documentation repositories.
---

# Cross-Repo Audit Skill

## Overview

Audit shared resource assignments across documentation repositories to detect conflicts, stale
cross-references, and inconsistencies. Shared resources are physical or logical assignments (rack
slots, switch ports, PDU ports, IP addresses) that appear in multiple repos because one repo owns
the resource and others reference it.

## When to Use This Skill

- Before committing changes that touch shared resources (ports, IPs, rack slots)
- After adding a new device that connects to shared infrastructure
- Periodically as a consistency check across repos
- When resolving "Available" vs assigned discrepancies between repos

## Repositories and Source Files

### tiny-lab (compute rack owner)

Owns: PDU port assignments, compute rack switch port assignments, rack unit assignments, Proxmox
node IPs.

| Resource              | File                           | Table/section to check        |
| --------------------- | ------------------------------ | ----------------------------- |
| PDU port assignments  | `components/pdu.md`            | Port assignments table        |
| Switch ports          | `configuration/network.md`     | Switch port assignments table |
| Rack unit assignments | `configuration/rack-layout.md` | Unit assignments table        |
| Proxmox node IPs      | `configuration/network.md`     | IP assignments table          |
| Power budget          | `configuration/rack-layout.md` | Total rack power budget table |

### truenas-server (NAS owner)

Owns: TrueNAS device specs, storage configuration. References: tiny-lab for rack/PDU/switch
assignments.

| Resource           | File                           | Table/section to check      |
| ------------------ | ------------------------------ | --------------------------- |
| Physical placement | `components/rackmount-case.md` | Physical setup section      |
| Network interfaces | `configuration/network.md`     | Interfaces table, IP config |

### ubiquiti-network-stack (network owner)

Owns: IP address assignments (all VLANs), VLAN definitions, DNS architecture, gateway port
assignments, main switch port assignments.

| Resource            | File                                | Table/section to check                          |
| ------------------- | ----------------------------------- | ----------------------------------------------- |
| Gateway ports       | `configuration/network-topology.md` | Cloud Gateway Fiber port table                  |
| Main switch ports   | `configuration/network-topology.md` | Switch Flex 2.5G 8 PoE port table               |
| Management VLAN IPs | `configuration/network-topology.md` | Management VLAN DHCP reservations               |
| Main VLAN IPs       | `configuration/network-topology.md` | Main VLAN DHCP reservations                     |
| VLAN definitions    | `configuration/vlans.md`            | VLAN table (ID, name, subnet)                   |
| DNS architecture    | `configuration/network-topology.md` | DNS servers per VLAN, Pi-hole local DNS records |
| Physical topology   | `configuration/network-topology.md` | Text diagram and mermaid diagram                |

## Audit Workflow

### Step 1: Read all source files

Read every file listed in the tables above. Do not skip files — partial reads cause missed
conflicts.

### Step 2: Check rack unit assignments

**Owner**: tiny-lab `configuration/rack-layout.md`

Verify:

- [ ] No U slot assigned to more than one device
- [ ] Devices claiming rack placement in other repos match tiny-lab's assignments
- [ ] truenas-server `components/rackmount-case.md` location matches tiny-lab U assignment
- [ ] Total U usage does not exceed rack capacity (8U for RackMate T1)

### Step 3: Check PDU port assignments

**Owner**: tiny-lab `components/pdu.md`

Verify:

- [ ] No PDU port assigned to more than one device
- [ ] Voltage per port matches the connected device's requirements
- [ ] Devices referencing PDU power in other repos match tiny-lab's port table
- [ ] Total estimated power draw does not exceed PSU capacity (check rack-layout.md power budget)

### Step 4: Check switch port assignments

**Owner**: tiny-lab `configuration/network.md` (compute rack switch)

**Owner**: ubiquiti-network-stack `configuration/network-topology.md` (main switch, gateway)

Verify:

- [ ] No switch port assigned to more than one device (per switch)
- [ ] Compute rack switch ports in tiny-lab match any references in truenas-server
- [ ] Gateway uplink port in ubiquiti repo matches tiny-lab's stated uplink target
- [ ] Main switch ports do not list devices that moved to the compute rack switch
- [ ] Port speeds are consistent (e.g., 1 GbE device not assigned to 2.5 GbE-only description)

### Step 5: Check DNS and hostname assignments

**Owner**: ubiquiti-network-stack `configuration/network-topology.md` (DNS architecture, Pi-hole
local DNS records, VLAN DNS settings)

Verify:

- [ ] Pi-hole local DNS records use `.lan` suffix (not `.local` — Apple devices hardcode `.local` to
  mDNS, which breaks VPN and standard DNS resolution)
- [ ] Hostnames in other repos match the DNS records in ubiquiti-network-stack
- [ ] DNS server assignments per VLAN are current (no stale fallback entries)
- [ ] Devices with static IPs in other repos have corresponding Pi-hole local DNS records

### Step 6: Check IP address assignments

**Owner**: ubiquiti-network-stack `configuration/network-topology.md` (authoritative for all VLANs)

**Secondary**: tiny-lab `configuration/network.md` (Proxmox node IPs)

Verify:

- [ ] No IP address assigned to more than one device
- [ ] Proxmox node IPs in tiny-lab match the ubiquiti repo's Main VLAN table
- [ ] TrueNAS IP (when assigned) matches across truenas-server and ubiquiti repo
- [ ] Compute rack switch management IP in ubiquiti repo's Management VLAN table exists
- [ ] IP assignments fall within their designated range (Servers, Austin's devices, etc.)

### Step 7: Check cross-references between repos

Verify that links between repos are valid and consistent:

- [ ] tiny-lab links to truenas-server GitHub URL are correct
- [ ] tiny-lab links to ubiquiti-network-stack GitHub URL are correct (if any)
- [ ] truenas-server links to tiny-lab GitHub URL are correct
- [ ] ubiquiti-network-stack links to tiny-lab GitHub URL are correct
- [ ] No repo duplicates specifications owned by another repo (reference only)

### Step 8: Generate audit report

Report findings in this format:

```markdown
# Cross-Repo Audit Report

## Summary
- Repos audited: X
- Conflicts found: Y
- Stale references: Z

## Conflicts

### [Resource type]: [Description]
- **Owner**: [repo] `[file]`
- **Conflict**: [repo] `[file]` says X, but owner says Y
- **Resolution**: Update [repo] to match owner

## Stale References

### [Repo]: [file]
- Link to [URL] — [issue description]

## Verified (no issues)
- [ ] Rack unit assignments consistent
- [ ] PDU port assignments consistent
- [ ] Switch port assignments consistent
- [ ] IP address assignments consistent
- [ ] Cross-references valid
```

### Step 9: Verify skill accuracy

After completing the audit, check whether this skill itself needs updating:

- [ ] All file paths in the "Repositories and Source Files" tables still exist
- [ ] No new files contain shared resource assignments that are not listed
- [ ] No new repos have been added that share resources with existing repos
- [ ] Ownership rules still reflect the current repo responsibilities
- [ ] If rack assignments now span three or more repos, or a device has moved between racks,
  consider whether a dedicated rack infrastructure repo would reduce cross-repo coordination
  overhead (see "Scaling: Dedicated rack infrastructure repo" below)

If any of these are stale, suggest specific updates to this skill file.

## Ownership Rules

When a conflict is found, the **owner** repo is authoritative:

| Resource                | Owner repo             | Others reference, never duplicate |
| ----------------------- | ---------------------- | --------------------------------- |
| PDU ports, rack layout  | tiny-lab               | truenas-server                    |
| Compute switch ports    | tiny-lab               | truenas-server                    |
| Proxmox node specs/IPs  | tiny-lab               | ubiquiti-network-stack            |
| Gateway and main switch | ubiquiti-network-stack | tiny-lab                          |
| All VLAN IP assignments | ubiquiti-network-stack | tiny-lab, truenas-server          |
| VLAN definitions        | ubiquiti-network-stack | tiny-lab, truenas-server          |
| DNS and hostnames       | ubiquiti-network-stack | tiny-lab, truenas-server          |
| TrueNAS device specs    | truenas-server         | tiny-lab                          |

**Resolution principle**: Update the non-owner repo to match the owner. If the owner is wrong, fix
the owner first, then update references.

## Common Issues

### "Available" in owner, assigned in referencing repo

A device was added to a referencing repo but the owner's port/slot table was not updated. Fix the
owner first.

### IP collision after expanding a service

Adding nodes (e.g., single Proxmox → three-node cluster) can collide with IPs previously assigned to
other devices. Check the full IP range in the ubiquiti repo.

### Stale "future" labels

Devices marked as "future" in one repo may already be documented in another. Replace "future" with
the actual device name and a cross-reference.

### Topology diagram drift

Text and mermaid diagrams in the ubiquiti repo can fall out of sync with port tables in the same
file, or with the actual topology described across repos. Check diagrams against tables.

### `.local` vs `.lan` hostname suffix

Apple devices hardcode `.local` to mDNS (Bonjour), which prevents standard DNS resolution and breaks
VPN access. The ubiquiti-network-stack repo uses `.lan` for Pi-hole local DNS records. Other repos
should use `.lan` for FQDNs, not `.local`. If a repo uses `.local`, flag it for correction.

## Scaling: Dedicated rack infrastructure repo

If the audit repeatedly surfaces rack-related conflicts, or the infrastructure grows beyond the
current two-active-rack setup, consider extracting all physical rack assignments (U-slots, PDU
ports, inter-rack cabling) into a dedicated repo. Device repos would reference it for physical
placement.

**Indicators that extraction is warranted:**

- Three or more repos have devices in the same rack
- Devices move between racks, requiring coordinated multi-repo updates
- A new rack is added with devices from multiple existing repos
- Cross-rack inventory questions come up regularly (e.g., "which U slots are free?")

**Current state:** Two active racks with clear single owners (ubiquiti-network-stack → T0, tiny-lab
→ T1). This structure works at current scale.
