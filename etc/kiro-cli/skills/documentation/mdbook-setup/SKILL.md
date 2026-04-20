---
name: mdbook-setup
description: Guide for setting up and configuring mdBook for technical documentation. Use when installing mdBook, configuring book.toml, troubleshooting builds, or deploying documentation.
---

# mdBook Setup

## Overview

mdBook is a command-line tool for creating books from Markdown files. It's ideal for technical
documentation with features like live reload, search, and GitHub integration.

[Official docs](https://rust-lang.github.io/mdBook/)

## When to Use This Skill

- Installing and initializing mdBook
- Configuring book.toml
- Setting up SUMMARY.md navigation
- Troubleshooting build issues
- Deploying to GitHub Pages or Netlify
- Understanding mdBook architecture

## Quick Start

### Installation

```bash
# macOS via Homebrew
brew install mdbook

# Or via Cargo (Rust package manager)
cargo install mdbook

# Verify
mdbook --version
```

### Initialize New Book

```bash
# In current directory
mdbook init

# Or specific directory
mdbook init my-book

# Creates:
# - book.toml (configuration)
# - src/ directory
# - src/SUMMARY.md (table of contents)
# - src/chapter_1.md (example)
```

### Common Commands

```bash
mdbook serve              # Live reload at localhost:3000
mdbook serve --port 8080  # Custom port
mdbook build              # Build to book/ directory
mdbook watch              # Watch and rebuild
mdbook test               # Test code examples
mdbook clean              # Clean build artifacts
```

## Required Files

### book.toml

Configuration file in project root.

**Minimal:**

```toml
[book]
title = "Your Documentation"
authors = ["Your Name"]
language = "en"
src = "."

[build]
build-dir = "book"

[output.html]
git-repository-url = "https://github.com/username/repo"
git-repository-icon = "fab-github"
```

### SUMMARY.md

Defines table of contents and navigation.

**Location:** Root of the source directory (set by `src` in book.toml).

**Format:**

```markdown
# Table of Contents

- [Introduction](INTRODUCTION.md)
- [Chapter 1](chapter1/README.md)
  - [Section 1.1](chapter1/section1.md)
- [Chapter 2](chapter2/README.md)
```

**Important:**

- Only files in SUMMARY.md are included in the book.
- Use a flat list under `# Table of Contents`. Do not use `# Section` headers as sidebar dividers.
- SUMMARY.md requires `README.md` paths for navigation, but cross-references in content files should
  link to directories instead (e.g., `../chapter1/` not `../chapter1/README.md`) because mdBook
  compiles README.md to index.html.

### .gitignore

```gitignore
book/
.DS_Store
*.swp
*.swo
*~
.vscode/
.idea/
```

## Configuration Patterns

### Recommended book.toml

```toml
[book]
title = "Your Project Documentation"
authors = ["Your Name"]
description = "Brief description"
language = "en"
src = "."

[build]
build-dir = "book"
create-missing = false

[output.html]
default-theme = "light"
preferred-dark-theme = "navy"
smart-punctuation = true
definition-lists = true
admonitions = true
git-repository-url = "https://github.com/username/repo"
git-repository-icon = "fab-github"
edit-url-template = "https://github.com/username/repo/edit/main/{path}"

[output.html.search]
enable = true
limit-results = 30
use-boolean-and = true
boost-title = 2
boost-hierarchy = 2

[output.html.fold]
enable = true
level = 0

[output.html.print]
enable = true
page-break = true
```

### Custom Styling

Create `custom.css`:

```css
/* Wider content area */
.content {
  max-width: 900px;
}

/* Better code blocks */
pre {
  padding: 1em;
}

/* Table styling */
table {
  width: 100%;
  border-collapse: collapse;
}

table th,
table td {
  padding: 0.5em;
  border: 1px solid #ddd;
}
```

## SUMMARY.md Best Practices

### Nesting Levels

**Limit to 2-3 levels maximum:**

```markdown
- [Level 1](level1.md)
  - [Level 2](level2.md)
    - [Level 3](level3.md) # Maximum recommended
```

Deep nesting makes navigation difficult.

### Using Separators

```markdown
- [Introduction](INTRODUCTION.md)
- [Main Content](content/README.md)

---

- [Glossary](glossary.md)
- [References](research/README.md)
```

Separates primary content from reference material.

### Link Format

**Always use relative paths:**

```markdown
# Good

- [Chapter 1](chapter1.md)
- [Section](folder/section.md)

# Bad

- [Chapter 1](/chapter1.md) # Absolute path
- [Chapter 1](./chapter1.md) # Unnecessary ./
```

### README.md as Section Index

```markdown
- [Hardware](hardware/README.md) # Overview
  - [Gateway](hardware/gateway.md)
  - [Switches](hardware/switches.md)
```

Provides context before diving into subsections.

## Common Pitfalls

### 1. Forgetting to Update SUMMARY.md

**Problem:** New file doesn't appear in navigation

**Solution:** Add to SUMMARY.md immediately after creating file

### 2. Broken Relative Links

**Problem:** Links work in editor but break in mdBook

**Solution:** Use paths relative to file's location

```markdown
# In src/chapter1/section1.md

# Wrong

[Config](configuration/config.md) # Looks in chapter1/configuration/

# Right

[Config](../configuration/config.md) # Goes up one level first
```

### 3. Case-Sensitive File Names

**Problem:** Works on macOS/Windows, breaks on Linux CI/CD

**Solution:** Match case exactly in links and file names

**Best practice:** Use lowercase with hyphens: `chapter-1.md`

### 4. Missing Files in SUMMARY.md

**Problem:** `mdbook build` fails with "file not found"

**Solution:** Create file or remove from SUMMARY.md

### 5. Not Gitignoring book/

**Problem:** Hundreds of generated HTML files committed

**Solution:** Add `book/` to .gitignore immediately

### 6. Circular References

**Problem:** Infinite loop or build errors

**Solution:** Avoid circular references in SUMMARY.md structure

## Troubleshooting Checklist

When mdBook isn't working:

- [ ] Is file referenced in SUMMARY.md?
- [ ] Do file names match exactly (case-sensitive)?
- [ ] Are relative links correct from file's location?
- [ ] Does the file actually exist?
- [ ] Is `book/` in .gitignore?
- [ ] Did you run `mdbook build` after changes?
- [ ] Are there any circular references?

## Deployment

### GitHub Pages (GitHub Actions)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy mdBook

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - name: Setup mdBook
        uses: peaceiris/actions-mdbook@v1
        with:
          mdbook-version: "latest"

      - name: Build book
        run: mdbook build

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./book
```

**Setup:**

1. Create workflow file
1. Push to GitHub
1. Enable GitHub Pages in settings
1. Select `gh-pages` branch

### Netlify

Create `netlify.toml`:

```toml
[build]
  command = "mdbook build"
  publish = "book"

[build.environment]
  MDBOOK_VERSION = "0.4.36"
```

Or configure in Netlify UI:

- Build command: `mdbook build`
- Publish directory: `book`

### Custom Domain

**GitHub Pages:**

1. Add `CNAME` file: `docs.yourdomain.com`
1. Configure DNS: `CNAME docs.yourdomain.com -> username.github.io`
1. Enable HTTPS in settings

**Netlify:**

1. Add domain in dashboard
1. Configure DNS as instructed
1. HTTPS automatic

## Quick Reference

### Typical Workflow

```bash
# 1. Initialize
mdbook init my-docs
cd my-docs

# 2. Edit SUMMARY.md to define structure
# 3. Create markdown files
# 4. Serve locally
mdbook serve

# 5. Build for deployment
mdbook build
```

### Configuration Locations

- `book.toml` - Project root
- `SUMMARY.md` - Root of source directory (set by `src` in book.toml)
- `custom.css` - Project root
- `book/` - Generated output (gitignore)

### Common Issues

**Build fails:** Check SUMMARY.md references existing files

**Links broken:** Verify relative paths from file location

**Navigation missing:** File not in SUMMARY.md

**Styling not applied:** Check `additional-css` in book.toml

## Advanced Features

### Preprocessors

Extend mdBook functionality:

- **mdbook-toc** - Auto-generate table of contents
- **mdbook-mermaid** - Render Mermaid diagrams
- **mdbook-linkcheck** - Validate links during build
- **mdbook-admonish** - Add callout boxes

**Installation:**

```bash
cargo install mdbook-toc
```

**Configuration:**

```toml
[preprocessor.toc]
command = "mdbook-toc"
renderer = ["html"]
```

### Multiple Output Formats

```toml
[output.html]
# HTML configuration

[output.pdf]
command = "mdbook-pdf"

[output.epub]
command = "mdbook-epub"
```

Build all: `mdbook build`

## Success Criteria

After setup:

- [ ] mdBook installed and verified
- [ ] book.toml configured
- [ ] SUMMARY.md created
- [ ] `mdbook serve` works
- [ ] `mdbook build` completes
- [ ] Navigation works correctly
- [ ] All links resolve
- [ ] book/ in .gitignore

## Further Reading

- [Official docs](https://rust-lang.github.io/mdBook/)
- [Preprocessors](https://rust-lang.github.io/mdBook/format/configuration/preprocessors.html)
- [Themes](https://rust-lang.github.io/mdBook/format/theme/)
- [Community plugins](https://github.com/topics/mdbook-plugin)
