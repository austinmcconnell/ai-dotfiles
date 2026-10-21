# Code Comment Guidance

## General Principles

1. **Avoid redundant comments** that merely repeat what the code already clearly communicates
1. **Focus on the "why" not the "what"** when adding comments
1. **Comment complex logic** that isn't immediately obvious
1. **Use docstrings** for functions, classes, and modules to explain purpose, parameters, and return
   values

## When NOT to Comment

- Don't add comments that repeat the function name
- Don't comment obvious operations
- Don't add comments for simple variable assignments
- Don't restate in an inline comment what a nearby docstring already explains — a one-line "why"
  beats a paragraph duplicating the docstring
- Default to no inline comment. A comment is the exception you justify, not the norm — add one only
  when a reader genuinely cannot infer the "why" from the code, and then keep it to a single short
  line
- Don't narrate a change's rationale at the code. The reason a change was made (root cause, the
  problem it fixes, why this approach) belongs in the commit message and PR, not in an inline
  comment duplicating it

## When to Comment

- Explain complex algorithms or business logic
- Document non-obvious side effects
- Explain workarounds or unusual approaches
- Clarify intent when the code might be confusing

## Docstring Guidelines

- Always include docstrings for modules, classes, and public methods/functions
- Include: purpose, parameters with types, return values, exceptions raised
- Follow Google style docstrings

## Code Organization Instead of Comments

- Use descriptive variable and function names instead of comments
- Extract complex logic into well-named helper functions
- Use enums and constants with descriptive names instead of magic numbers
