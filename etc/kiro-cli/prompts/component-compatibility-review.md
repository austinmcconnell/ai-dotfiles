# Component Compatibility Review

Review all selected components for compatibility, conflicts, and documentation gaps.

## 1. Compatibility check

Read all component specs in `components/` and decisions in `decisions/`. Check for:

- Physical fit issues (dimensions, clearances, mounting compatibility)
- Power delivery (PSU wattage headroom, connector compatibility)
- Thermal constraints (TDP vs cooling capacity, airflow conflicts)
- Interface compatibility (RAM speed/XMP support, PCIe lane versions, M.2 lane sharing)
- Any bottlenecks between components for the stated use cases

For each issue found, classify as: ❌ conflict, ⚠️ concern to monitor, or ✅ verified compatible.

## 2. Documentation gaps

After the compatibility review, identify:

- Missing specs in component docs (e.g., physical dimensions, confirmed mounting compatibility)
- Specs that are speculative or unverified — research and confirm them
- Cross-references that should exist but don't
- Use cases mentioned in decisions/ but missing from planning/requirements
- Configuration specs that should exist based on the component selections
- BOM completeness: verify all components in components/ appear in planning/bom.md (if it exists),
  flag missing entries or stale prices/status

## 3. Future-proofing assessment

Based on the stated requirements and use cases in `planning/`:

- Platform upgrade path (socket longevity, future CPU options)
- Key component upgrade headroom (GPU clearance, PSU wattage, RAM expandability, storage slots)
- How long the build stays relevant for the stated use cases

## 4. Propose fixes

For every gap or issue found, recommend specific changes but wait for approval before making them:

- Component docs that need confirmed specs or cross-references
- Configuration specs that should be created in `configuration/`
- ADRs that should be created in `decisions/` for undocumented design decisions
- SUMMARY.md updates needed for any new files

Follow the content ownership model: specs in `configuration/`, procedures in `procedures/`,
rationale in `decisions/`. Reference, don't duplicate.
