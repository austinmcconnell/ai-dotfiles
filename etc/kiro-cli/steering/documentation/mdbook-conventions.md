# mdBook Conventions

**Purpose**: Project-specific conventions for mdBook documentation repositories. Complements the
mdbook-setup skill (installation and configuration) with patterns for consistent content
organization.

## SUMMARY.md structure

### Format

Use a flat list under `# Table of Contents`. Do not use `# Section` headers as sidebar dividers.

The introduction links to INTRODUCTION.md (the book intro), not README.md (the repo-level intro).
AGENTS.md is not included in the book — it is AI agent guidance, not reader content.

```markdown
# Table of Contents

- [Introduction](INTRODUCTION.md)
- [Planning](planning/README.md)
  - [Requirements](planning/requirements.md)
- [Components](components/README.md)
  - [Component A](components/component-a.md)
  - [Component B](components/component-b.md)
- [Configuration](configuration/README.md)
  - [Config Topic A](configuration/config-topic-a.md)
  - [Config Topic B](configuration/config-topic-b.md)
- [Procedures](procedures/README.md)
  - [Procedure A](procedures/procedure-a.md)
  - [Procedure B](procedures/procedure-b.md)
- [Decisions](decisions/README.md)
  - [ADR-001: Decision Title](decisions/adr-001-decision-title.md)
  - [ADR-002: Decision Title](decisions/adr-002-decision-title.md)
```

### Ordering conventions

**Between sections:**

1. Introduction/README
1. Planning (if exists)
1. Components
1. Configuration
1. Procedures
1. Decisions

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

## File Organization

### Directory Structure

```text
src/
├── INTRODUCTION.md        # Book introduction
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

- Use kebab-case: `config-topic-a.md`
- Be descriptive: `component-setup.md` not `setup.md`
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

- [Component A](components/component-a.md)

<!-- components/component-a.md -->

# Component A
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

**`create-missing = false`** - Prevents mdBook from creating empty files for SUMMARY.md entries.
Forces you to create files intentionally.

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
<!-- From procedures/procedure-a.md -->

See [Configuration: Config Topic A](../configuration/config-topic-a.md).

<!-- From configuration/config-topic-a.md -->

For implementation, see [Procedure: Procedure A](../procedures/procedure-a.md).
```

### Section Links

Link to specific sections using anchors:

```markdown
[Configuration: Config Topic A - Section Name](../configuration/config-topic-a.md#section-name)
```

mdBook generates anchors from headings automatically:

- `## Section Name` → `#section-name`
- `### Step 1: Configure component` → `#step-1-configure-component`

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
| Setting | Value       | Description     |
| ------- | ----------- | --------------- |
| Key A   | value-1     | First setting   |
| Key B   | value-2     | Second setting  |
| Key C   | value-3     | Third setting   |
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
