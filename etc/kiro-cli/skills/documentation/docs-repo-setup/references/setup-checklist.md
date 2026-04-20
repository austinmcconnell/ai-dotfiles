# Day 1 Setup Checklist

## Project context (5 minutes)

- [ ] Project name and one-sentence description
- [ ] Key requirements or goals (bullet list)
- [ ] Known constraints (optional)

## Repository (10 minutes)

- [ ] Initialize git, create .gitignore
- [ ] Create README.md with repo-level getting started guide
- [ ] Create INTRODUCTION.md with book introduction
- [ ] Choose mdBook, create book.toml

## Directories (5 minutes)

- [ ] Create planning/, research/, decisions/, components/, configuration/, procedures/
- [ ] Create README.md in each subdirectory
- [ ] Create SUMMARY.md

## Core Files (15 minutes)

- [ ] Create AGENTS.md with content ownership model
- [ ] Create research/README.md for external links
- [ ] Create glossary.md for terminology

## Templates (20 minutes)

- [ ] Create decisions/adr-template.md
- [ ] Create components/component-template.md
- [ ] Create configuration/config-template.md
- [ ] Create procedures/procedure-template.md
- [ ] Add HTML comments explaining WHAT vs HOW

## Quality Gates (15 minutes)

- [ ] Create .pre-commit-config.yaml
- [ ] Run `pre-commit install`
- [ ] Add validation scripts
- [ ] Test `mdbook serve` and `mdbook build`
