# Core Analyses

A repo can carry generated core analyses in `analysis/`. That directory is git-ignored, so the files
exist only on the machine that generated them. Treat them as repo facts: read the file a question
needs, and do not preload them.

## When to Check

If the repo has an `analysis/` directory, check it before answering a question about the repo's
purpose, architecture, data models, or external integrations. That includes narrow questions about
one feature or one data shape, because the analysis often records context the code alone does not
show. Run `ls analysis/` through Bash. Do not rely on Glob or Grep: they can skip git-ignored paths,
so an empty result does not mean the files are absent.

| The question is about                                      | Read                                |
| ---------------------------------------------------------- | ----------------------------------- |
| What the project does, its purpose, and its current state  | `analysis/project-analysis.md`      |
| Components, design patterns, flows, and module boundaries  | `analysis/architecture-analysis.md` |
| Data models, database tables, and API data shapes          | `analysis/schema-analysis.md`       |
| External services, their APIs, and how they are authorized | `analysis/integration-analysis.md`  |

Read only the files a question needs. Each file lists its own prerequisites, and those must be read
too.

## Staleness

Each file records the commit it describes in its `**HEAD Commit:**` line. Before relying on a file,
compare that hash with `git rev-parse HEAD`. Check every core file that is present, not only the one
you read. Before relying on any of them, state the count, for example "3 of 4 core files are stale."

- If none are stale or missing, use the files.
- If exactly one is stale or missing, offer to run its prompt from `~/.ai-dotfiles/etc/ai/prompts/`,
  for example `architecture-analysis.md`.
- If two or more are stale or missing, offer to run `run-core-analyses.md` in a background subagent.

Do not regenerate an analysis unless the user agrees. The prompts write into `analysis/` and cost a
full model run.
