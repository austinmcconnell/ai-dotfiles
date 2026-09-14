# Cross-Repo Resource Awareness

## Principle

When creating or modifying docs that reference shared resources, check the authoritative source
before finalizing changes.

## Shared Resources and Owners

| Resource                                | Authoritative Repo     |
| --------------------------------------- | ---------------------- |
| IP addresses (Main VLAN, multi-claimed) | home-infrastructure    |
| Management/IoT IP reservations          | ubiquiti-network-stack |
| DNS-of-record (resolver, suffix)        | home-infrastructure    |
| Rack unit positions (all racks)         | home-infrastructure    |
| PDU port assignments                    | home-infrastructure    |
| Power budget                            | home-infrastructure    |
| VLAN definitions                        | ubiquiti-network-stack |
| Main switch ports, gateway ports        | ubiquiti-network-stack |
| Compute switch ports                    | tiny-lab               |
| Storage pools/datasets                  | truenas-server         |

The split rule: **home-infrastructure owns IP facts that more than one system claims;
single-claimant facts stay with their sole owner.** The Main VLAN (`10.10.10.0/24`) reservations
were co-claimed by the UniFi controller and `tiny-lab-ansible`, so they moved to
home-infrastructure. Management (`10.10.1.x`) and IoT (`10.10.30.x`) reservations are
single-claimant UniFi-native facts and stay with ubiquiti-network-stack. VLAN definitions
(ID/name/subnet) stay with ubiquiti-network-stack; home-infrastructure is only a cross-repo pointer
for them.

## When to Check

- Adding or moving a component with a rack position, IP, or port
- Modifying network configuration or VLAN assignments
- Creating procedures that reference resources owned by another repo

## Resolution

- Non-owner repos reference the owner — never contradict it
- If the owner appears wrong, fix the owner first
- For full audit workflow, load the `cross-repo-audit` skill
