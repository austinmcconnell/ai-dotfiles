# Cross-Repo Resource Awareness

## Principle

When creating or modifying docs that reference shared resources, check the authoritative source
before finalizing changes.

## Shared Resources and Owners

| Resource                         | Authoritative Repo     |
| -------------------------------- | ---------------------- |
| IP addresses, VLANs, DNS         | ubiquiti-network-stack |
| Main switch ports, gateway ports | ubiquiti-network-stack |
| Rack unit positions              | tiny-lab               |
| PDU port assignments             | tiny-lab               |
| Compute switch ports             | tiny-lab               |
| Storage pools/datasets           | truenas-server         |

## When to Check

- Adding or moving a component with a rack position, IP, or port
- Modifying network configuration or VLAN assignments
- Creating procedures that reference resources owned by another repo

## Resolution

- Non-owner repos reference the owner — never contradict it
- If the owner appears wrong, fix the owner first
- For full audit workflow, load the `cross-repo-audit` skill
