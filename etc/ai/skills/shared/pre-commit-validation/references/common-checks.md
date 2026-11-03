# Common Pre-commit Check Rules

Detailed formatting rules by language. Reference this when fixing validation failures.

## Markdown

- Line length limited to 100 characters (except tables)
- Words should not begin before the 100-character limit and extend beyond it
- Headers must be surrounded by blank lines
- Lists must be surrounded by blank lines
- Ordered lists should use consistent item prefixes (all 1.)
- Code blocks must specify a language and be surrounded by blank lines

## Python

- Imports are sorted using isort
- Code is formatted according to autopep8 and yapf standards
- Line length typically limited to 100 characters
- Double quotes are converted to single quotes where appropriate
- Trailing whitespace is removed
- Unused imports are removed

## YAML/Docker Compose

- Docker Compose files must be sorted according to the custom sorter
- YAML files must be valid

## JSON

- JSON files must be valid and properly formatted with 4-space indentation
