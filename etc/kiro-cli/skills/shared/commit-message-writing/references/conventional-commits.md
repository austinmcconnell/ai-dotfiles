# Conventional Commits Specification

Based on [Conventional Commits v1.0.0](https://www.conventionalcommits.org/)

## Format

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Type

Must be one of:

- **feat** - A new feature
- **fix** - A bug fix
- **docs** - Documentation only changes
- **style** - Changes that don't affect code meaning (whitespace, formatting)
- **refactor** - Code change that neither fixes a bug nor adds a feature
- **perf** - Code change that improves performance
- **test** - Adding missing tests or correcting existing tests
- **build** - Changes to build system or external dependencies
- **ci** - Changes to CI configuration files and scripts
- **chore** - Other changes that don't modify src or test files
- **revert** - Reverts a previous commit

## Scope

Optional noun describing the section of codebase:

- Component name: `auth`, `api`, `ui`
- Feature area: `login`, `dashboard`
- Module name: `user`, `order`

## Description

- Use imperative, present tense: "change" not "changed" nor "changes"
- Don't capitalize first letter
- No period at the end
- Maximum 50 characters

## Body

- Use imperative, present tense
- Wrap at 72 characters
- Explain motivation and contrast with previous behavior
- Separate from description with blank line

## Footer

- Reference issues: `Fixes #123`, `Closes #456`
- Note breaking changes: `BREAKING CHANGE: description`
- Credit co-authors: `Co-authored-by: Name <email>`

## Breaking Changes

Indicate breaking changes in two ways:

1. Add `!` after type/scope: `feat(api)!: remove deprecated endpoint`
1. Add footer: `BREAKING CHANGE: description of what broke`

## Examples

### Commit with description and breaking change footer

```text
feat: allow provided config object to extend other configs

BREAKING CHANGE: `extends` key in config file is now used for extending other config files
```

### Commit with `!` to draw attention to breaking change

```text
feat!: send an email to the customer when a product is shipped
```

### Commit with scope and `!` to draw attention to breaking change

```text
feat(api)!: send an email to the customer when a product is shipped
```

### Commit with both `!` and BREAKING CHANGE footer

```text
chore!: drop support for Node 6

BREAKING CHANGE: use JavaScript features not available in Node 6.
```

### Commit with no body

```text
docs: correct spelling of CHANGELOG
```

### Commit with scope

```text
feat(lang): add Polish language
```

### Commit with multi-paragraph body and multiple footers

```text
fix: prevent racing of requests

Introduce a request id and a reference to latest request. Dismiss
incoming responses other than from latest request.

Remove timeouts which were used to mitigate the racing issue but are
obsolete now.

Reviewed-by: Z
Refs: #123
```

## Why Use Conventional Commits?

- Automatically generate CHANGELOGs
- Automatically determine semantic version bump
- Communicate nature of changes to teammates and public
- Trigger build and publish processes
- Make it easier for people to contribute
- Provide structured commit history

## Tools

- **commitlint** - Lint commit messages
- **standard-version** - Automate versioning and CHANGELOG generation
- **semantic-release** - Fully automated version management and package publishing
- **commitizen** - Interactive commit message CLI

## FAQ

**Q: How should I deal with commit messages in the initial development phase?**

A: Proceed as if you've already released the product. Typically somebody is using your software, even if it's your fellow developers.

**Q: Are the types in the commit title uppercase or lowercase?**

A: Any casing may be used, but it's best to be consistent. Lowercase is recommended.

**Q: What do I do if the commit conforms to more than one type?**

A: Go back and make multiple commits whenever possible. Part of the benefit of Conventional Commits is its ability to drive us to make more organized commits and PRs.

**Q: Doesn't this discourage rapid development and fast iteration?**

A: It discourages moving fast in a disorganized way. It helps you be able to move fast long term across multiple projects with varied contributors.

**Q: Might Conventional Commits lead developers to limit the type of commits they make?**

A: Conventional Commits encourages us to make more of certain types of commits such as fixes. Other than that, the flexibility of Conventional Commits allows your team to come up with their own types and change those types over time.

**Q: How does this relate to SemVer?**

A: `fix` type commits should be translated to PATCH releases. `feat` type commits should be translated to MINOR releases. Commits with `BREAKING CHANGE` should be translated to MAJOR releases.
