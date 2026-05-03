---
created: YYYY-MM-DD
last_updated: YYYY-MM-DD
last_verified: YYYY-MM-DD
update_summary: Initial research
sources:
  source-key:
    url: https://example.com/docs
    verified: YYYY-MM-DD
---

# Technology / Protocol Name

## Overview

What is this technology? What problem does it solve? Key architecture concepts and how the pieces
fit together. Enough context for someone unfamiliar to understand the rest of the document.

## Requirements

Protocols, ports, dependencies, hardware/software prerequisites. Use tables for port lists or
protocol summaries. This section is platform-independent — it describes what the technology needs
from any network/system, not how to configure a specific platform.

## Platform-Specific Configuration

### [Platform Name]

Step-by-step configuration for the target platform. Use numbered `##` subsections for each
configuration area (e.g., `### 1. Firewall Rules`, `### 2. DNS Settings`). For each area include:

- **What to configure** and **where** (specific UI path or config file)
- **Why** this setting matters (link back to Requirements section)
- **Expected state** (what "correct" looks like)
- **Known gotchas** (settings that interact, features that silently override each other)

If the technology works on multiple platforms, use one file per platform and keep this section
focused on a single platform. Cross-reference the Requirements file for protocol-level details
rather than repeating them.

## Troubleshooting

### [Symptom Description]

Use decision-tree format for each common failure mode:

1. **Check [thing]** — where to look, what the correct state is
   - **If wrong:** how to fix it, then how to confirm the fix worked
   - **If correct:** proceed to next step
1. **Check [next thing]** — same pattern

Include a "how to confirm this was the fix" test after each fix — not just "it should work now" but
a specific command or observation.

Cross-reference configuration details to the Platform Configuration section rather than repeating
settings. The troubleshooting section tells you *what* to check and *why*; the configuration section
tells you *how* to set it.

### Fallback Approaches

When fine-grained configuration doesn't resolve the issue, present broader approaches with
structured tradeoff assessment:

| Approach   | Complexity | Reliability | Security | When to Use |
| ---------- | ---------- | ----------- | -------- | ----------- |
| Approach A | ...        | ...         | ...      | ...         |
| Approach B | ...        | ...         | ...      | ...         |

## Known Issues

Firmware/version-specific bugs, vendor-acknowledged problems, and community-reported regressions.
Include dates and version numbers. Distinguish between confirmed bugs (vendor-acknowledged) and
community-reported issues (may be environment-specific).

## References

Links to official documentation, community-maintained resources, and diagnostic tools. Supplement
the YAML `sources` frontmatter — this section is for resources that are broadly useful but not cited
inline (e.g., a GitHub repo with community configs, an official troubleshooting guide).
