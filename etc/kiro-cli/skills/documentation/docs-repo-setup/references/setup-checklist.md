# Day 1 Setup Checklist

## Scaffold (5 minutes)

- [ ] Run `cookiecutter gh:austinmcconnell/cookiecutter-docs`
- [ ] Initialize git, review .gitignore

## Review generated files (5 minutes)

- [ ] Verify AGENTS.md content ownership model
- [ ] Verify SUMMARY.md structure
- [ ] Verify README.md and INTRODUCTION.md
- [ ] Verify subdirectory READMEs

## Quality gates (10 minutes)

- [ ] Run `pip install pre-commit`
- [ ] Run `pre-commit install`
- [ ] Test `pre-commit run --all-files`
- [ ] Test `mdbook serve` and `mdbook build`

## Shared resource registration (5 minutes)

If this repo references shared resources (IP addresses, switch ports, rack slots, PDU ports):

- [ ] Add the repo to the `cross-repo-audit` skill
- [ ] Run a targeted conflict check against authoritative sources

## Start adding content

Use content templates from `references/templates/` as the project grows:

- `component.md` — new component specifications
- `configuration.md` — new configuration specs
- `procedure.md` — new step-by-step procedures
- `research-readme.md` / `research-topic.md` — research directory content
- `todo.md` — working file for open questions and blockers
