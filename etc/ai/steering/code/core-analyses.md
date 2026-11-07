# Core Analyses

A repo can carry generated core analyses in `analysis/`. That directory is git-ignored, so the files
exist only on the machine that generated them. Treat them as repo facts: read the file a question
needs, and do not preload them.

## When to Check

When a question is about the repo's purpose, architecture, data models, or external integrations,
read the matching file below if it exists. Test the exact path (for example `test -f
analysis/architecture-analysis.md`); do not list the directory or rely on Glob or Grep, since they can
skip git-ignored paths. Narrow questions about one feature or data shape count too, because the
analysis often records context the code alone does not show.

| The question is about                                      | Read                                |
| ---------------------------------------------------------- | ----------------------------------- |
| What the project does, its purpose, and its current state  | `analysis/project-analysis.md`      |
| Components, design patterns, flows, and module boundaries  | `analysis/architecture-analysis.md` |
| Data models, database tables, and API data shapes          | `analysis/schema-analysis.md`       |
| External services, their APIs, and how they are authorized | `analysis/integration-analysis.md`  |

Read only the files a question needs. Each file lists its own prerequisites, and those must be read
too.

## Staleness

Do not compare hashes yourself. A session-start notice reports staleness for repos under `~/projects`:

- `🔍 N of 4 core analyses in analysis/ are stale or missing.` means some files are out of date. Mention
  the count once, in your first reply, and offer to refresh them: run the prompt from
  `~/.ai-dotfiles/etc/ai/prompts/` for one file, or `run-core-analyses.md` in a background subagent
  for two or more.
- `💡 No core analyses in analysis/ yet.` means none exist. Mention it only if the user's question
  would benefit, and do not generate them unprompted.
- No notice means either the files are current or the repo is outside `~/projects`, where staleness is
  not checked. If you rely on an analysis file in that case, say that its currency is unverified.

Do not regenerate an analysis unless the user agrees. The prompts write into `analysis/` and cost a
full model run.
