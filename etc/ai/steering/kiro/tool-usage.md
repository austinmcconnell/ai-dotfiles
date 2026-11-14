# Tool Usage

Conventions for kiro-cli's built-in tools. The tool-neutral rules they apply live in
`code/shell-conventions.md` and `code/research-sourcing.md`.

## Shell

- Use the `working_dir` parameter instead of prefixing commands with `cd`. Write
  `cat file.md > out.md` with `working_dir` set, not `cd /path && cat file.md > out.md`.

## Web Fetch

- On a large doc site, call `web_fetch` in selective mode with tight `search_terms` rather than
  fetching the full page.
