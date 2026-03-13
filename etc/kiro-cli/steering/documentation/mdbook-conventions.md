# mdBook Conventions

**Purpose**: Project-specific conventions for mdBook documentation repositories. Complements the mdbook-setup skill (installation and configuration) with patterns for consistent content organization.

## SUMMARY.md Structure

### Section Organization

Organize SUMMARY.md by content type following the stage-based architecture:

```markdown
# Summary

[Introduction](README.md)

# Planning

- [Requirements](planning/requirements.md)
- [Constraints](planning/constraints.md)

# Components

- [Component Overview](components/README.md)
  - [Gateway](components/gateway.md)
  - [Switch](components/switch.md)

# Configuration

- [Configuration Overview](configuration/README.md)
  - [Network Topology](configuration/network-topology.md)
  - [Security Rules](configuration/security-rules.md)

# Procedures

- [Procedures Overview](procedures/README.md)
  - [Initial Setup](procedures/initial-setup.md)
  - [Gateway Setup](procedures/gateway-setup.md)

# Decisions

- [Decisions Overview](decisions/README.md)
  - [ADR-001: Platform Selection](decisions/adr-001-platform-selection.md)
  - [ADR-002: Security Strategy](decisions/adr-002-security-strategy.md)
```

### Ordering Conventions

**Between sections:**

1. Introduction/README
2. Planning (if exists)
3. Components
4. Configuration
5. Procedures
6. Decisions

**Within sections:**

- Alphabetical by default
- Logical progression when order matters (e.g., initial-setup before advanced-setup)
- ADRs by number (ascending)

### Indentation

- Use 2-space indentation for nested items
- Maximum 3 levels of nesting
- Use README.md as section overview (parent item)

```markdown
# Section Title

- [Section Overview](section/README.md)
  - [Subsection](section/subsection.md)
    - [Detail](section/subsection/detail.md)
```

### Section Headers

Use `# Header` (H1 with space) for SUMMARY.md section dividers:

```markdown
# Configuration

- [Network Topology](configuration/network-topology.md)

# Procedures

- [Initial Setup](procedures/initial-setup.md)
```

These render as sidebar section headers in mdBook.

## File Organization

### Directory Structure

```text
src/
├── README.md              # Book introduction
├── SUMMARY.md             # Table of contents
├── planning/
│   ├── README.md          # Planning overview
│   └── *.md               # Planning documents
├── components/
│   ├── README.md          # Components overview
│   └── *.md               # Component specs
├── configuration/
│   ├── README.md          # Configuration overview
│   └── *.md               # Configuration specs
├── procedures/
│   ├── README.md          # Procedures overview
│   └── *.md               # Procedure docs
├── decisions/
│   ├── README.md          # Decisions overview
│   └── adr-*.md           # ADR files
└── images/                # Shared images
    └── *.png
```

### File Naming

- Use kebab-case: `network-topology.md`
- Be descriptive: `gateway-setup.md` not `setup.md`
- ADRs: `adr-NNN-title-with-dashes.md`
- README.md for directory overviews (always capitalized)

### Image Organization

- Store images in `src/images/` or alongside their document
- Use descriptive filenames: `network-topology-diagram.png`
- Reference with relative paths: `![Alt text](../images/diagram.png)`

## Heading Hierarchy

### Within Documents

- H1 (`#`) - Document title (one per file, matches SUMMARY.md entry)
- H2 (`##`) - Major sections
- H3 (`###`) - Subsections
- H4 (`####`) - Sub-subsections (use sparingly)

**Never skip heading levels:**

```markdown
<!-- Good -->

# Title

## Section

### Subsection

<!-- Bad -->

# Title

### Subsection (skipped H2)
```

### Heading and SUMMARY.md Alignment

The H1 heading in each file should match its SUMMARY.md entry:

```markdown
<!-- SUMMARY.md -->

- [Network Topology](configuration/network-topology.md)

<!-- configuration/network-topology.md -->

# Network Topology
```

## book.toml Configuration

### Standard Configuration

```toml
[book]
title = "Project Documentation"
authors = ["Author Name"]
language = "en"
multilingual = false
src = "src"

[build]
build-dir = "book"
create-missing = false

[output.html]
default-theme = "light"
preferred-dark-theme = "navy"
git-repository-url = "https://github.com/user/repo"
edit-url-template = "https://github.com/user/repo/edit/main/{path}"

[output.html.search]
enable = true
limit-results = 30
use-hierarchical-headings = true
```

### Recommended Settings

**`create-missing = false`** - Prevents mdBook from creating empty files for SUMMARY.md entries. Forces you to create files intentionally.

**`edit-url-template`** - Enables "Edit this page" links for collaborative documentation.

**`use-hierarchical-headings = true`** - Improves search results by showing heading context.

### Preprocessors

Common preprocessors for documentation projects:

```toml
# Table of contents within pages
[preprocessor.toc]
command = "mdbook-toc"
renderer = ["html"]

# Mermaid diagrams
[preprocessor.mermaid]
command = "mdbook-mermaid"

# Link checking
[output.linkcheck]
follow-web-links = false
exclude = ["^http://localhost"]
```

## Cross-Reference Patterns

### Internal Links

Use relative paths from the current file:

```markdown
<!-- From procedures/gateway-setup.md -->

See [Configuration: Network Topology](../configuration/network-topology.md).

<!-- From configuration/network-topology.md -->

For implementation, see [Procedure: Gateway Setup](../procedures/gateway-setup.md).
```

### Section Links

Link to specific sections using anchors:

```markdown
[Configuration: Network Topology - VLAN Assignments](../configuration/network-topology.md#vlan-assignments)
```

mdBook generates anchors from headings automatically:

- `## VLAN Assignments` → `#vlan-assignments`
- `### Step 1: Configure Gateway` → `#step-1-configure-gateway`

### Link Text Patterns

Follow link-conventions.md standards:

- `[Configuration: Title](path)` for WHAT files
- `[Procedure: Title](path)` for HOW files
- `[ADR-NNN: Title](path)` for WHY files
- `[Component: Name](path)` for SPECS files

## Admonitions and Callouts

### mdBook Built-in

mdBook doesn't have native admonitions. Use HTML or a preprocessor:

**Using blockquotes (simple):**

```markdown
> **Note:** This is important information.

> **Warning:** This action cannot be undone.
```

**Using mdbook-admonish preprocessor:**

````markdown
```admonish warning
This action cannot be undone. Back up your configuration first.
```
````

### Conventions

- **Note** - Additional helpful information
- **Warning** - Potential issues or data loss
- **Tip** - Best practices or shortcuts
- **Important** - Critical information for success

## Code Blocks

### Language Specification

Always specify language for syntax highlighting:

````markdown
```bash
mdbook build
```

```toml
[book]
title = "My Book"
```

```yaml
status: proposed
date: 2024-03-13
```
````

### Command Examples

Show commands with expected output when helpful:

````markdown
```bash
$ mdbook build
2024-03-13 10:00:00 [INFO] (mdbook::book): Book building has started
2024-03-13 10:00:01 [INFO] (mdbook::book): Running the html backend
```
````

### File Path References

When showing file contents, indicate the filename:

````markdown
```toml
# book.toml
[book]
title = "My Documentation"
```
````

## Tables

### Formatting

Use consistent table formatting:

```markdown
| Setting     | Value         | Description     |
| ----------- | ------------- | --------------- |
| IP Address  | 192.168.1.1   | Gateway address |
| Subnet Mask | 255.255.255.0 | Network subnet  |
| VLAN        | 10            | Management VLAN |
```

**Conventions:**

- Align pipes for readability
- Include header separator row
- Use consistent column widths within a table
- Left-align text, right-align numbers (when possible)

### When to Use Tables

- Specification data (configuration files)
- Comparison of options (ADRs)
- Parameter lists
- Status tracking

### When Not to Use Tables

- Sequential steps (use numbered lists)
- Simple key-value pairs (use definition lists or bold)
- Long text content (use sections)

## Pre-commit Integration

### Recommended Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.12.1
    hooks:
      - id: markdownlint-cli2
        args: ["--config", ".markdownlint.yaml"]

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
        files: '\.md$'
      - id: end-of-file-fixer
        files: '\.md$'
      - id: check-yaml
```

### Markdownlint Configuration

```yaml
# .markdownlint.yaml
default: true
MD013: false # Line length (disabled for docs)
MD033: false # Inline HTML (needed for mdBook)
MD041: false # First line heading (frontmatter conflicts)
```

## Quality Checklist

Before committing documentation changes:

- [ ] SUMMARY.md updated with new/moved files
- [ ] Heading hierarchy is correct (no skipped levels)
- [ ] H1 matches SUMMARY.md entry
- [ ] Cross-references use relative paths
- [ ] Link text follows conventions
- [ ] Code blocks specify language
- [ ] Tables are properly formatted
- [ ] Images have alt text
- [ ] `mdbook build` succeeds without errors
- [ ] Pre-commit hooks pass
