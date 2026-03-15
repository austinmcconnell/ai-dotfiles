# Link Conventions

**Purpose**: Standards for cross-referencing and linking in documentation repositories to support the "reference, don't duplicate" principle.

## Core Principles

1. **Descriptive link text** - Never use "click here" or bare URLs
1. **Relative paths** - Use relative paths for internal links
1. **Consistent patterns** - Follow established link text patterns
1. **Verify links** - Use link checkers to prevent broken references

## Link Text Patterns

### Internal Cross-References

Use descriptive patterns that indicate content type:

```markdown
[Configuration: System Settings](../configuration/system-settings.md)
[Procedure: Initial Setup](../procedures/initial-setup.md)
[ADR-001: Platform Selection](../decisions/adr-001-platform-selection.md)
[Component: Gateway](../components/gateway.md)
```

**Pattern**: `[ContentType: Title](path)`

**Why**: Immediately clear what type of content is being referenced

### Section Links

Link to specific sections when referencing part of a document:

```markdown
[Configuration: Network Topology - VLAN Assignments](../configuration/network-topology.md#vlan-assignments)
```

**Pattern**: `[ContentType: Document - Section](path#anchor)`

### External Links

Use descriptive text that indicates the resource:

```markdown
[mdBook Documentation](https://rust-lang.github.io/mdBook/)
[MADR Template](https://adr.github.io/madr/)
[RFC 2119: Key words for RFCs](https://www.ietf.org/rfc/rfc2119.txt)
```

**Pattern**: `[Resource Name](URL)`

**Never**: `[here](URL)` or `[link](URL)` or bare URLs

## Relative vs Absolute Paths

### Use Relative Paths For

- Internal documentation files
- Cross-references within the same repository
- Links in SUMMARY.md

```markdown
<!-- From procedures/system-setup.md -->
[Configuration: System](../configuration/system.md)

<!-- From SUMMARY.md -->
- [System Configuration](configuration/system.md)
```

**Why**: Works in local builds, GitHub, and deployed sites

### Use Absolute Paths For

- External resources
- Links to other repositories
- API endpoints or web services

```markdown
[Project Repository](https://github.com/user/project)
[API Documentation](https://api.example.com/docs)
```

## Link Placement

### Prerequisites Section

Always link to specifications that must be reviewed first:

```markdown
## Prerequisites

Before proceeding, review:

- [Configuration: System Settings](../configuration/system-settings.md)
- [ADR-003: Security Strategy](../decisions/adr-003-security-strategy.md)
```

### Inline References

Reference specifications inline instead of duplicating:

```markdown
<!-- Bad: Duplicating specification -->
Configure the gateway with IP 192.168.1.1 and subnet mask 255.255.255.0.

<!-- Good: Referencing specification -->
Configure the gateway according to [Configuration: Network Topology](../configuration/network-topology.md#gateway-settings).
```

### Related Documentation Section

Add at the end of major files:

```markdown
## Related Documentation

- [Configuration: System Settings](../configuration/system-settings.md) - System specifications
- [Procedure: Initial Setup](../procedures/initial-setup.md) - Implementation steps
- [ADR-002: Component Selection](../decisions/adr-002-component-selection.md) - Decision rationale
```

## Link Verification

### Pre-commit Hooks

Use mdbook-linkcheck or similar tools:

```toml
# book.toml
[output.linkcheck]
follow-web-links = false
exclude = ["^http://localhost"]
```

### Manual Verification

Before committing:

```bash
# Check for broken internal links
mdbook build

# Or use linkcheck directly
mdbook-linkcheck
```

## Common Patterns

### Referencing Specifications

```markdown
<!-- In procedures/ file -->
For complete specifications, see [Configuration: System](../configuration/system.md).

<!-- When referencing specific values -->
Use the IP addresses defined in [Configuration: Network Topology - IP Assignments](../configuration/network-topology.md#ip-assignments).
```

### Linking Between ADRs

```markdown
<!-- In decisions/ file -->
This decision supersedes [ADR-001: Initial Platform Selection](adr-001-platform-selection.md).

Related decisions:
- [ADR-003: Security Strategy](adr-003-security-strategy.md)
- [ADR-005: Component Selection](adr-005-component-selection.md)
```

### Component to Configuration

```markdown
<!-- In components/ file -->
For network configuration using this component, see [Configuration: Network Topology](../configuration/network-topology.md).
```

## Anti-Patterns

### ❌ Vague Link Text

```markdown
<!-- Bad -->
Click [here](../configuration/system.md) for more information.
See [this document](../procedures/setup.md).

<!-- Good -->
See [Configuration: System Settings](../configuration/system.md) for specifications.
Follow [Procedure: Initial Setup](../procedures/setup.md) for implementation.
```

### ❌ Bare URLs

```markdown
<!-- Bad -->
See https://adr.github.io/madr/ for MADR documentation.

<!-- Good -->
See [MADR Documentation](https://adr.github.io/madr/) for template details.
```

### ❌ Absolute Paths for Internal Links

```markdown
<!-- Bad -->
[System Config](/configuration/system.md)

<!-- Good -->
[Configuration: System](../configuration/system.md)
```

### ❌ Duplicating Instead of Linking

```markdown
<!-- Bad: Duplicating specification -->
## Network Configuration

| Device  | IP Address    | Subnet        |
|---------|---------------|---------------|
| Gateway | 192.168.1.1   | 255.255.255.0 |

<!-- Good: Referencing specification -->
## Network Configuration

Configure devices according to [Configuration: Network Topology](../configuration/network-topology.md#ip-assignments).
```

## Link Text for Different Content Types

### Configuration Files (WHAT)

```markdown
[Configuration: {Topic}](path)
[Config: {Topic}](path)  # Shorter alternative
```

Examples:
- `[Configuration: System Settings](../configuration/system-settings.md)`
- `[Config: Security Rules](../configuration/security-rules.md)`

### Procedure Files (HOW)

```markdown
[Procedure: {Action}](path)
[Setup: {Component}](path)  # For setup procedures
```

Examples:
- `[Procedure: Initial Setup](../procedures/initial-setup.md)`
- `[Setup: Gateway Configuration](../procedures/gateway-setup.md)`

### Decision Files (WHY)

```markdown
[ADR-{NNN}: {Title}](path)
```

Examples:
- `[ADR-001: Platform Selection](../decisions/adr-001-platform-selection.md)`
- `[ADR-003: Security Strategy](../decisions/adr-003-security-strategy.md)`

### Component Files (SPECS)

```markdown
[Component: {Name}](path)
[{Component Name} Specs](path)  # Alternative
```

Examples:
- `[Component: Gateway](../components/gateway.md)`
- `[Gateway Specifications](../components/gateway.md)`

## Accessibility Considerations

- Link text should make sense out of context
- Avoid "click here" or "read more" without context
- Screen readers announce link text, so make it descriptive
- Don't rely on surrounding text for link meaning

```markdown
<!-- Bad: Requires context -->
For more information, click here.

<!-- Good: Self-contained -->
See [Configuration: System Settings](../configuration/system-settings.md) for complete specifications.
```

## Quality Checklist

Before committing, verify:

- [ ] All links use descriptive text (no "here" or "click here")
- [ ] Internal links use relative paths
- [ ] External links use absolute URLs
- [ ] Link text follows content type patterns
- [ ] No bare URLs in documentation
- [ ] Links verified with mdbook-linkcheck
- [ ] Cross-references exist instead of duplicated content
