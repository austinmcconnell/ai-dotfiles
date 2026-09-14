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

### home-infrastructure (cross-cutting authority)

Owns: the Main-VLAN IP registry (multi-claimed `10.10.10.0/24` reservations), DNS-of-record, rack
unit assignments (all racks), PDU port assignments, power budget. Referenced by:
ubiquiti-network-stack, tiny-lab, truenas-server, home-assistant-server, and future consumers (ARM,
family-dashboard). The IP-ownership rule is by claim count, not by VLAN: home-infrastructure owns IP
facts more than one system claims; single-claimant reservations (Management `10.10.1.x`, IoT
`10.10.30.x`) stay with ubiquiti-network-stack.

| Resource              | File                                      | Table/section to check        |
| --------------------- | ----------------------------------------- | ----------------------------- |
| IP reservations       | `configuration/ip-reservations.sops.yaml` | reservations (SOPS-encrypted) |
| IP registry view      | `configuration/ip-registry.md`            | Reservation table (Main VLAN) |
| DNS-of-record         | `decisions/adr-001-dns-of-record.md`      | Decision section              |
| Rack unit assignments | `configuration/rack-layout.md`            | Unit assignments per rack     |
| PDU ports + power     | `configuration/power-budget.md`           | Port assignments, draw totals |

### tiny-lab (compute rack owner)

Owns: compute rack switch port assignments, Proxmox node specifications. References
home-infrastructure for rack unit assignments, PDU port assignments, power budget, and Main-VLAN IP
addresses.

| Resource           | File                       | Table/section to check        |
| ------------------ | -------------------------- | ----------------------------- |
| Switch ports       | `configuration/network.md` | Switch port assignments table |
| Proxmox node specs | `components/m920x.md`      | Node specifications           |

### truenas-server (NAS owner)

Owns: TrueNAS device specs, storage configuration. References: home-infrastructure for
rack/PDU/power and Main-VLAN IP addresses; tiny-lab for compute switch ports.

| Resource           | File                           | Table/section to check      |
| ------------------ | ------------------------------ | --------------------------- |
| Physical placement | `components/rackmount-case.md` | Physical setup section      |
| Network interfaces | `configuration/network.md`     | Interfaces table, IP config |

### ubiquiti-network-stack (network owner)

Owns: VLAN definitions, gateway port assignments, main switch port assignments, and the
single-claimant Management (`10.10.1.x`) and IoT (`10.10.30.x`) IP reservations. References
home-infrastructure for the Main-VLAN IP registry and DNS-of-record.

| Resource                | File                                | Table/section to check             |
| ----------------------- | ----------------------------------- | ---------------------------------- |
| Gateway ports           | `configuration/network-topology.md` | Cloud Gateway Fiber port table     |
| Main switch ports       | `configuration/network-topology.md` | Switch Flex 2.5G 8 PoE port table  |
| Management/IoT VLAN IPs | `configuration/network-topology.md` | Management + IoT DHCP reservations |
| VLAN definitions        | `configuration/vlans.md`            | VLAN table (ID, name, subnet)      |
| Physical topology       | `configuration/network-topology.md` | Text diagram and mermaid diagram   |

## Audit Workflow

### Step 1: Read all source files

Read every file listed in the tables above. Do not skip files — partial reads cause missed
conflicts.

### Step 2: Check rack unit assignments

**Owner**: home-infrastructure `configuration/rack-layout.md`

Verify:

- [ ] No U slot assigned to more than one device
- [ ] Devices claiming rack placement in device repos (tiny-lab, truenas-server, ubiquiti) match
  home-infrastructure's assignments
- [ ] truenas-server `components/rackmount-case.md` location matches the home-infrastructure U
  assignment
- [ ] Total U usage does not exceed rack capacity (8U for RackMate T1)

### Step 3: Check PDU port assignments

**Owner**: home-infrastructure `configuration/power-budget.md`

Verify:

- [ ] No PDU port assigned to more than one device
- [ ] Voltage per port matches the connected device's requirements
- [ ] Devices referencing PDU power in device repos match home-infrastructure's port table
- [ ] Total estimated power draw does not exceed PSU capacity (check home-infrastructure
  power-budget.md). The ShrikeLab PDU **device spec** stays in tiny-lab `components/pdu.md`; only
  the port assignments and draw totals live in home-infrastructure

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

**Owner**: home-infrastructure `decisions/adr-001-dns-of-record.md` (resolver of record, suffix)

The resolver of record is the Technitium DNS container at `10.10.10.30` with the `home.arpa` suffix
(`lab.home.arpa` for lab hosts/guests). Pi-hole is **out of both the resolver and the ad-block
paths** — Technitium serves the blocklists directly. Do not treat Pi-hole `.lan` as the current DNS
architecture anywhere.

Verify:

- [ ] The resolver of record is Technitium `10.10.10.30` (not Pi-hole `10.10.10.11`), suffix
  `home.arpa` (per home-infrastructure ADR-001)
- [ ] `.lan` appears only as the Technitium conditional-forwarder zone delegating transient DHCP
  hostnames to the UniFi gateway — never as the suffix of record
- [ ] The `lab.home.arpa` zone (and `10.10.10.in-addr.arpa` reverse zone) are auto-generated by
  `tiny-lab-ansible`; the `home.arpa` household zone is hand-maintained
- [ ] Hostnames in other repos match the `home.arpa` records; no repo asserts Pi-hole as the
  resolver or ad-blocker
- [ ] DNS server assignments per VLAN point at `10.10.10.30` (no stale `.11`/Pi-hole entries)

### Step 6: Check IP address assignments

**Owner**: home-infrastructure `configuration/ip-registry.md` (Main VLAN `10.10.10.0/24`
reservations — the multi-claimed block)

**Owner**: ubiquiti-network-stack `configuration/network-topology.md` (Management `10.10.1.x` and
IoT `10.10.30.x` reservations — single-claimant, stay with ubiquiti)

The IP-ownership rule is by claim count, not by VLAN: home-infrastructure owns IP facts more than
one system claims (the Main VLAN, co-claimed by UniFi + `tiny-lab-ansible`); single-claimant
Management/IoT reservations stay with ubiquiti.

Verify:

- [ ] No IP address assigned to more than one device
- [ ] Proxmox node IPs in tiny-lab match the home-infrastructure Main-VLAN registry (tinylab1 `.20`;
  tinylab1-amt `.21` planned)
- [ ] TrueNAS IP matches across truenas-server and the home-infrastructure registry (`.15`, planned
  until the box is deployed)
- [ ] Management/IoT device IPs referenced in other repos match ubiquiti's Management/IoT tables
- [ ] IP assignments fall within their designated range (Servers `.10-.19`, Proxmox `.20-.29`,
  guests `.30-.49`, personal `.50-.69`)

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

| Resource                       | Owner repo             | Others reference, never duplicate                              |
| ------------------------------ | ---------------------- | -------------------------------------------------------------- |
| IP registry (Main VLAN)        | home-infrastructure    | ubiquiti, tiny-lab, truenas-server, home-assistant-server      |
| Management/IoT IP reservations | ubiquiti-network-stack | (single-claimant — stays with sole owner)                      |
| DNS-of-record                  | home-infrastructure    | ubiquiti, tiny-lab, truenas-server                             |
| Rack layout (all racks)        | home-infrastructure    | tiny-lab, truenas-server, ubiquiti                             |
| PDU ports, power budget        | home-infrastructure    | tiny-lab, truenas-server                                       |
| Compute switch ports           | tiny-lab               | truenas-server                                                 |
| Gateway and main switch        | ubiquiti-network-stack | tiny-lab                                                       |
| VLAN definitions               | ubiquiti-network-stack | tiny-lab, truenas-server (home-infrastructure is pointer only) |
| Proxmox node specs             | tiny-lab               | ubiquiti-network-stack                                         |
| TrueNAS device specs           | truenas-server         | tiny-lab                                                       |

The IP-ownership rule is **by claim count, not by VLAN**: home-infrastructure owns IP facts that
more than one system claims (the Main VLAN, co-claimed by UniFi + `tiny-lab-ansible`);
single-claimant facts (Management/IoT reservations) stay with their sole owner. VLAN definitions
stay in ubiquiti-network-stack (home-infrastructure only points at them, it does not own them).

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

### `.local` vs `home.arpa` hostname suffix

Apple devices hardcode `.local` to mDNS (Bonjour), which prevents standard DNS resolution and breaks
VPN access. The resolver of record (Technitium at `10.10.10.30`, per home-infrastructure ADR-001)
uses `home.arpa` — the RFC 8375 special-use domain designed to resolve correctly for the split
home/VPN case. Other repos should use `home.arpa` (or `lab.home.arpa` for lab hosts) for FQDNs, not
`.local` and not the retired `.lan` suffix. `.lan` survives only as a Technitium
conditional-forwarder zone, not the suffix of record. If a repo uses `.local`, or still asserts
Pi-hole `.lan` as the DNS architecture, flag it for correction.

## Scaling: Dedicated rack infrastructure repo

The extraction described below **has happened.** A dedicated `home-infrastructure` repo now owns the
cross-cutting facts (Main-VLAN IP registry, DNS-of-record, rack layout across all racks, PDU port
assignments, power budget). Device repos reference it for physical placement and IP/DNS rather than
duplicating those tables. The indicators below are retained as the **historical rationale** that
triggered the extraction.

**Indicators that warranted extraction (historical):**

- Three or more repos have devices in the same rack
- Devices move between racks, requiring coordinated multi-repo updates
- A new rack is added with devices from multiple existing repos
- Cross-rack inventory questions come up regularly (e.g., "which U slots are free?")

**Current state:** `home-infrastructure` is the authoritative owner of cross-rack and multi-claimed
facts. ubiquiti-network-stack retains VLAN definitions, gateway/main switch ports, and
single-claimant Management/IoT IP reservations; tiny-lab retains compute switch ports and Proxmox
node specs; truenas-server retains storage/device specs. Each device repo links up to
home-infrastructure for the moved facts.
