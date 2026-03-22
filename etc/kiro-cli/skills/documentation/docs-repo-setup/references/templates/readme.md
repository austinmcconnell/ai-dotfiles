# Project README.md Template

This is the repo-level README for GitHub/contributors. It is not included in the book.

````markdown
# [Project Name] Documentation

[One-sentence project description.]

## Overview

[Brief description of what this documentation covers.]

## Getting started

### Local development

This documentation uses [mdBook](https://rust-lang.github.io/mdBook/) for local serving and
building.

#### Install mdBook

```bash
brew install mdbook
```

#### Serve locally

```bash
# Start local server with live reload
mdbook serve

# Then open http://localhost:3000
```

#### Build static site

```bash
# Build to book/ directory
mdbook build
```

### Alternative: View as Markdown

You can also view files directly in any Markdown editor (VS Code, GitHub, etc.)

### Pre-commit hooks

This repository uses pre-commit hooks for quality control:

```bash
# Install pre-commit
pip install pre-commit

# Install the hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```
````
