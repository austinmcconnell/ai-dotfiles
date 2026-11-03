# Shared Placement Audit

Audit the skills under `~/.ai-dotfiles/etc/ai/skills/` and the steering docs under
`~/.ai-dotfiles/etc/ai/steering/`, and decide which belong in `shared/` (loaded by more than one
agent) and which should stay in their domain. This is a read-only audit: report candidates with
evidence and move nothing.

If you cannot read the repository, say so and ask for the files listed under "Inputs" rather than
guessing from file names.

## Context

- Skills sit in category directories (`development/`, `operations/`, `scrum/`, and so on, plus
  `shared/`). Steering sits in domain directories. Agents never name a file directly; they load
  whatever their glob lists match.
- Kiro agents load skills and steering through glob lists in
  `~/.ai-dotfiles/etc/kiro-cli/cli-agents/*.json` (`skill://` and `file://` lines).
- Claude Code personas declare their tools and engram grants in frontmatter at
  `~/.ai-dotfiles/etc/claude-code/agents/*.md`. Claude skills are installed flat from every category.
- Steering domains that every session loads are listed in `UNIVERSAL_STEERING_DOMAINS` in
  `~/.ai-dotfiles/install/ai-tools.sh`. Persona domains are in `install/persona-domains.sh`.
- Every file placed in `shared/` adds context to every agent whose globs match it. A move is never
  free.

## Inputs

- The agent glob files and persona frontmatter listed above.
- Trigger tables: `etc/ai/steering/<domain>/skill-loading-triggers.md` and
  `etc/ai/steering/shared/skill-loading-triggers.md`.
- Grep access to the repository for skill names and doc filenames.

## Method

1. **Build the load map first.** For each agent, list the skill globs and steering globs it loads.
   Take this from the glob and frontmatter files, not from README prose, which can drift.
1. **Collect evidence for each candidate:**
   - Trigger-table rows: which domains name the skill or doc.
   - Inbound and outbound references: grep the skill name or doc filename across the repository.
   - Reachability: for each trigger row naming a skill, check that the agent loading that table can
     also load the skill through its globs. A mismatch is a finding even if nothing moves.
1. **Decide placement:**
   - **`shared/`** when two or more agents need the content and it is not specific to one agent's
     tools or domain.
   - **Stay in domain** when one agent or domain needs it. A stray reference from elsewhere is a
     reason to fix the reference, not to move the file.
   - **Guardrails go to `shared/`** when any agent with write-capable tools cannot load them. Safety
     rules such as "never delete" or "do not expose secrets" should not depend on which persona is
     running.
1. **Verify before reporting.** Re-check each cited line. Label each claim as verified (read or
   grepped) or inference.

## What NOT to recommend

- Do not move a file because one reference names it. Check which agent loads the referencing content.
- Do not move content to `shared/` for tidiness. Each shared file costs context in every session that
  globs it.
- Do not recommend changes to skill or steering content. Placement only.
- Do not report a trigger-table mismatch as a placement problem until you have checked the globs.
- Do not count orphans (no grep hits) as dead. Say they are unreferenced and stop there.

## Output format

1. **Table:** path | current location | recommended (`shared/` or stay in `<domain>/`) | evidence
   (file:line for each reference or glob) | confidence (high, medium, low).
1. **Move to `shared/`:** each item with its evidence and the agents whose context it adds to.
1. **Move out of `shared/`:** each item with the agent or domain that needs it.
1. **Borderline:** items that could go either way, with the reason.
1. **Incidental findings:** broken references, reachability gaps, stale paths, and orphans.
1. **Summary:** for each agent, the moves that change what it loads.

Quote only the lines needed as evidence. Do not paste whole files.
