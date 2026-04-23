# Link Conventions

**Purpose**: Standards for cross-referencing and linking to support "reference, don't duplicate."

## Core Principles

1. **Descriptive link text** - Never "click here" or bare URLs
1. **Relative paths** - For all internal links
1. **Consistent patterns** - Follow content-type link text patterns
1. **Verify links** - Use link checkers to prevent broken references

## Link Patterns

**Internal** — `[ContentType: Title](relative-path)`:

- `[Configuration: System Settings](../configuration/system-settings.md)`
- `[Procedure: Initial Setup](../procedures/initial-setup.md)`
- `[ADR-001: Platform Selection](../decisions/adr-001-platform-selection.md)`
- `[Component: Gateway](../components/gateway.md)`

**Section** — `[ContentType: Document - Section](path#anchor)`

**External** — `[Resource Name](URL)`

## Key Rules

- Relative paths for internal; absolute URLs for external
- Never bare URLs or vague text ("click here", "read more")
- Reference specs instead of duplicating content
- Link text must make sense out of context

Full reference: `skills/documentation/docs-review/references/link-conventions-reference.md`
