# Formatting Conventions

Rules aligned with pre-commit hooks (mdformat, markdownlint, yamllint, prettier) shared across
documentation repositories.

## Markdown

- Use `-` for unordered list markers (not `*` or `+`)
- Use `1.` for ALL ordered list items (not incrementing `1. 2. 3.`)
- Use ATX-style headings (`#`)
- Use fenced code blocks (triple backtick), never indented code blocks
- Add blank lines before and after headings, lists, code blocks, and blockquotes
- Max line length: 100 characters (excluding code blocks and tables)

## YAML

- 2-space indentation
- Spaces inside braces: `{ key: value }` not `{key: value}`
- No spaces inside brackets: `[item1, item2]` not `[ item1, item2 ]`
- Max line length: 100 characters

## JSON

- 4-space indentation
- Max line length: 100 characters
