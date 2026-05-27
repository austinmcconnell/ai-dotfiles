# Cross-Session Memory

## When to Save Memories

Save to engram (`mem_save`) when:

- Making an architectural decision with rationale
- Discovering a failed approach (what was tried, why it failed)
- Establishing a project convention not documented elsewhere
- Completing a significant milestone in multi-session work
- Finding a non-obvious workaround or solution
- Receiving explicit user preferences about workflow

## When NOT to Save Memories

Never store:

- Secrets, credentials, API keys, tokens, or passwords
- Contents of .env files or encrypted secrets
- SSH keys or certificate material
- Personally identifiable information (PII)
- Temporary debugging state that won't matter next session
- Information already captured in project docs, READMEs, or steering files

## How to Use Memory

### Session Start

At the beginning of a session, if the user describes a task or project:

1. Use `mem_search` with relevant keywords to find prior context
1. Use `mem_context` to get recent session history for the project
1. Mention relevant findings briefly: "From a previous session, I recall..."

Do NOT dump all memories into the response. Surface only what's relevant to the current task.

### During Work

Save memories at natural breakpoints — not after every small action. Good triggers:

- "We decided to use X instead of Y because..."
- "Approach X failed because of Z — don't retry without fixing Z first"
- "User prefers [specific workflow/style/tool]"

Use descriptive titles and the What/Why/Where/Learned structure.

### Memory Types

Use these types when saving:

- `decision` — architectural or design choices with rationale
- `bug` — bugs found, root causes, and fixes
- `convention` — project or user conventions discovered
- `blocker` — things that blocked progress and how they were resolved
- `preference` — explicit user preferences about tools or workflow

### Topic Keys

Use `mem_suggest_topic_key` to get a consistent topic key before saving. This ensures related
memories cluster together for retrieval.

## Memory Hygiene

- Keep memories concise — a few sentences, not paragraphs
- Include the "why" — bare facts without rationale are less useful
- Use project names consistently so memories are findable
- Don't duplicate information that belongs in docs or code comments
