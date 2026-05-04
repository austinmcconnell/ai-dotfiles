---
name: kiro-skill-authoring
description: Author and maintain kiro-cli skills with correct structure, frontmatter, descriptions, and reference files. Use when creating new skills, editing existing skills, reviewing skill quality, or asking about skill conventions.
---

# Kiro Skill Authoring

## Skill Format

<!-- Source: kiro-cli Agent Configuration docs — skill:// resources section -->

A skill is a single `SKILL.md` file with YAML frontmatter followed by a markdown body.

### Frontmatter

Two required fields — `name` and `description`:

```yaml
---
name: my-skill-name
description: One-line summary. Use when [trigger phrases].
---
```

<!-- Source: agentskills.io/specification — frontmatter table -->

The Agent Skills spec defines optional fields (`license`, `compatibility`, `metadata`,
`allowed-tools`). These are spec-valid and won't cause parse errors, but kiro-cli only reads `name`
and `description` — optional fields are silently ignored. Other tools (Cursor, Codex, etc.) may also
ignore them. Keep frontmatter to `name` and `description` unless a specific need arises. The most
useful optional field is `compatibility` (max 500 chars) for environment requirements — e.g.,
`compatibility: Requires Python 3.14+ and uv`.

#### Name constraints

- Lowercase letters, numbers, and hyphens only
- Max 64 characters
- Must not start/end with a hyphen or contain consecutive hyphens
- Must match the parent directory name
- Doubles as a slash command (`/skill-name`) — keep it short and typeable

### Description

The description serves two purposes:

1. **Human-readable summary** shown in `/context show` and skill listings
1. **Semantic trigger** the agent uses to decide when to load the skill on demand

<!-- Source: agentskills.io/specification — description field -->

**Must be a single line.** Max 1024 characters per the Agent Skills spec. kiro-cli documentation
only shows single-line descriptions, and multi-line YAML syntax (`>`, `|`) is untested — it may not
parse correctly. All existing skills in this repo use single-line descriptions; keep it that way.

Write descriptions that cover both purposes:

<!-- Source: agentskills.io/skill-creation/optimizing-descriptions -->

- Use imperative phrasing — "Use this skill when..." rather than "This skill does..."
- Start with what the skill does (summary)
- End with "Use when..." phrases listing the tasks that should trigger loading

**Good:**
`Create structured research files with cited sources, YAML frontmatter, and standardized templates. Use when researching products, technologies, concepts, or any topic requiring organized, verifiable findings.`

**Bad:** `Research skill` — too vague for semantic matching, no trigger phrases.

**Bad:**
`This skill helps you create research files following a standardized template with YAML frontmatter including created date, last updated date, last verified date, update summary, and sources with URLs and verification dates, using inline citations in square brackets, organized in topic subdirectories under the _research_ directory with README indexes.`
— too long; metadata is loaded into context at startup for every skill, so verbose descriptions
waste tokens across all conversations.

Keep descriptions concise. Front-load the most distinctive terms — the agent matches on these first.

### Body

Start with an H1 title. Recommended: match the skill name, but existing skills vary (e.g., `todo` →
"Todo Working File"). Then use any combination of:

- **Workflow / procedure sections** — numbered steps for multi-step processes
- **Rules / conventions** — bullet lists of requirements
- **Examples** — inline or linked from `references/`
- **Gotchas** — environment-specific facts that defy reasonable assumptions
- **Validation checklist** — verification steps at the end

<!-- Source: agentskills.io/specification — progressive disclosure -->

No fixed section template — structure should match the skill's content. Keep SKILL.md under 500
lines / ~5000 tokens. Move detailed reference material to `references/` files.

## Directory Layout

```text
etc/kiro-cli/skills/<category>/<skill-name>/
├── SKILL.md              ← required
├── references/           ← optional: documentation the agent reads on demand
│   ├── template.md
│   └── checklist.md
├── scripts/              ← optional: executable code the agent can run
└── assets/               ← optional: templates, schemas, static resources
```

Symlinks from `~/.kiro/skills/` point to the source directories under `etc/kiro-cli/skills/`.

### Categories

Group skills by domain: `development`, `documentation`, `operations`, `research`, `scrum`, `shared`.
Use `shared` for skills used across multiple agents or domains.

## Reference Files

Put templates, examples, checklists, and detailed reference material in `references/`. Keep
individual reference files focused — agents load them on demand, so smaller files mean less context
usage.

<!-- Source: kiro.dev/docs/cli/skills — "Kiro loads reference files only when the instructions
     direct it to." agentskills.io best practices — "The key is telling the agent *when* to load
     each file." -->

**Tell the agent when to load each file.** Reference files are not loaded automatically — the agent
reads them only when SKILL.md directs it to. Conditional directives are more useful than generic
"see references/" pointers:

**Good — conditional:** `Read references/api-errors.md if the API returns a non-200 status code.`

**Good — direct:** `For ECS deployments, follow the guide in references/ecs-guide.md.`

**Bad — vague:** `See references/ for details.` — the agent doesn't know when to look or which file
to read.

Use relative paths from the skill root. Keep references one level deep — avoid deeply nested
reference chains.

### When to use reference files

- Content is long enough to distract from the main workflow (templates, full examples)
- Content is reusable across multiple skills or contexts
- Content changes independently from the skill's workflow

### When to keep content inline

- Short examples that illustrate a rule (a few lines)
- Rules and conventions that are the skill's core content
- Gotchas the agent needs before encountering the situation

## Skill Loading

<!-- Source: kiro.dev/docs/cli/skills — skill locations -->

### Default agent (auto-discovery)

The default agent automatically loads skills from both locations — no configuration needed:

- **Workspace:** `.kiro/skills/` — project-specific skills
- **Global:** `~/.kiro/skills/` — personal skills across all projects

Workspace skills take priority when names collide.

### Custom agents

Custom agents don't auto-discover skills. Register them explicitly via `skill://` URIs:

```json
{
    "resources": [
        "skill://.kiro/skills/**/SKILL.md",
        "skill://~/.kiro/skills/**/SKILL.md"
    ]
}
```

### Loading behavior

- **Startup:** Only metadata (name, description, filepath) is sent to the model
- **On demand:** Full SKILL.md content is loaded when the agent determines the skill is relevant, or
  when the user invokes the skill via `/skill-name`
- **Reference files** are not loaded automatically — the agent reads them only when SKILL.md directs
  it to

### Steering doc triggers

For deterministic loading (not relying on semantic matching), add entries to
`skill-loading-triggers.md`:

```markdown
| Task                    | Skill to load first    |
| ----------------------- | ---------------------- |
| Writing commit messages | `commit-message-writing` |
```

Use steering triggers when a task must always load a specific skill regardless of how the user
phrases the request.

## Skills vs Steering Docs

Steering docs are a kiro-cli concept (not part of the Agent Skills spec).

- **Skills** contain workflows, procedures, and templates — loaded on demand when relevant
- **Steering docs** contain principles, conventions, and rules — always loaded into context

If content applies to every conversation (coding style, security rules, git conventions), it belongs
in a steering doc. If content applies only to specific tasks (writing research, creating commits),
it belongs in a skill.

## Sizing Guidelines

**Skill metadata is always in context.** Every skill's name + description consumes tokens in every
conversation. Keep descriptions concise.

**Skill body is loaded on demand.** Longer skills are fine — they only consume tokens when relevant.
But prefer linking to reference files over inlining large templates or examples.

**Right-size the skill:**

- If the workflow is simple and the rules are few, a short SKILL.md with no references is fine (see:
  `todo`, `virtual-environment`)
- If the skill is a pointer to detailed reference material, keep SKILL.md minimal and delegate (see:
  `aws-operations`, `writing-style`)
- If the skill defines a complex multi-step workflow, a longer SKILL.md is appropriate (see:
  `create-research`, `commit-message-writing`)

## Workflow: Creating a New Skill

1. **Decide placement** — pick the category and skill name (kebab-case)
1. **Create `SKILL.md`** — write frontmatter with name and description, then the body
1. **Add reference files** if needed — create `references/` and link from SKILL.md
1. **Ensure discoverability** — for the default agent, place the skill in `.kiro/skills/` or
   `~/.kiro/skills/`. For custom agents, verify the skill is matched by a `skill://` glob pattern
1. **Add steering trigger** if the skill should load deterministically for specific tasks
1. **Verify loading** — start a new session, run `/context show` to confirm the skill appears, then
   try `/skill-name` to confirm it's invocable as a slash command

## Validation Checklist

- [ ] SKILL.md starts with YAML frontmatter containing `name` and `description`
- [ ] Name is lowercase, hyphens only, matches parent directory name
- [ ] Description is a single line with imperative "Use when..." trigger phrases
- [ ] Reference files (if any) are in `references/` with conditional loading directives
- [ ] Skill is in a discoverable location (default agent auto-discovery or `skill://` glob)
- [ ] `/context show` displays the skill with correct metadata
- [ ] `/skill-name` invokes the skill as a slash command
- [ ] No duplication of content that belongs in steering docs
