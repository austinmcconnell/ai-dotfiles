# Core Analyses

A repo can carry generated core analyses in `analysis/`. That directory is git-ignored, so the files
exist only on the machine that generated them. Treat them as repo facts: read the file a question
needs, and do not preload them.

## When to Check

When a question is about the repo's purpose, architecture, data models, or external integrations,
read the matching file below if it exists. Test the exact path (for example
`test -f analysis/architecture-analysis.md`); do not list the directory or rely on Glob or Grep,
since they can skip git-ignored paths. Narrow questions about one feature or data shape count too,
because the analysis often records context the code alone does not show.

| The question is about                                      | Read                                |
| ---------------------------------------------------------- | ----------------------------------- |
| What the project does, its purpose, and its current state  | `analysis/project-analysis.md`      |
| Components, design patterns, flows, and module boundaries  | `analysis/architecture-analysis.md` |
| Data models, database tables, and API data shapes          | `analysis/schema-analysis.md`       |
| External services, their APIs, and how they are authorized | `analysis/integration-analysis.md`  |

Read only the files a question needs, plus their prerequisites: `architecture` and `schema` depend
on `project`, and `integration` depends on the other three.

## Staleness

Do not compare hashes yourself. On `main` or `master`, in a git repo under `~/projects`, a
session-start notice reports what it finds:

- `🔍 N of 4 core analyses in analysis/ are stale: <names>.` Tell the user in your first reply,
  before answering anything else, and offer a refresh. Do not start one until they accept. If they
  do, use the matching `<name>-analysis.md` prompt from `$AI_DOTFILES_DIR/etc/ai/prompts/` for one
  file, or `run-core-analyses.md` with those file names in a background subagent for two or more.
  The notice may add `Also missing: <names>.`
- `💡 Core analyses in analysis/ are missing: <names>.` Those files were never generated. Mention it
  only if the user's question would benefit, and do not generate them unless asked.
- `💡 No core analyses in analysis/ yet.` No core file exists. The same rule applies.

No notice does not prove a file is current. Either all four files are within 20 commits of HEAD, or
the check did not run: another branch, outside `~/projects`, a repo with no commits, or a session
event that skips the hook, such as `/clear`. When you rely on an analysis file without a notice, say
that it may lag HEAD.

Do not regenerate an analysis unless the user agrees. The prompts write into `analysis/` and cost a
full model run.
