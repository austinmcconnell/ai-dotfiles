# Agent Routing

## Why This Exists

This repo runs several kiro-cli agents, each scoped to a domain with its own steering, skills,
knowledge bases, and safety denies. `code` is the deliberate generalist — the agent you land in when
you forget `--agent <x>`. It legitimately touches docs, infra, YAML, and tickets in passing, so it
does *not* hand off for incidental cross-domain work. But when a prompt is squarely a specialist
agent's job, working it in `code` means skipping that agent's tuned steering, skills, and safety
scopes. This doc is a low-frequency routing nudge for exactly that case.

**This nudge applies only when you are the `code` agent.** The four scoped agents (`docs`,
`ansible`, `jira`, `datadog`) already *are* the right agent by construction — they must never emit
this nudge.

## When to Nudge

Suggest a switch **once** when a prompt is squarely in another agent's domain:

| The prompt is squarely about…                                 | Suggest   |
| ------------------------------------------------------------- | --------- |
| Authoring an ADR or an mdBook / documentation page            | `docs`    |
| Writing or running an Ansible role or playbook                | `ansible` |
| Creating or updating a JIRA issue / sprint / board            | `jira`    |
| Auditing Datadog monitors, APM, dashboards, or UST compliance | `datadog` |

"Squarely in the domain" means the domain work *is the task*, not a passing touch.

- **Re-evaluate at the analysis→implementation transition.** Analyzing or auditing another domain's
  artifacts (reading a playbook, reviewing its docs) stays in `code`. The nudge fires when the task
  *crosses* into producing that domain's work — proposing or writing the role, playbook, or repo
  edits. The transition is the trigger, not the first mention of the domain.

This doc governs the *mid-session* case — a task crossing into a specialist's domain while you work.
The *session-start* case (landing the default `code` agent in a repo that has a tuned specialist,
detected from a root marker like `ansible.cfg`/`book.toml`) is owned by the `suggest-agent-fit.sh`
agentSpawn hook, which emits its own one-time confirm-not-switch nudge.

## When to Stay Silent

- **Incidental cross-domain touches** — editing a code comment that happens to be Markdown, reading
  a playbook to understand a deploy, referencing a JIRA ticket ID, glancing at a Datadog link.
  `code` is the generalist; these are its normal reach, not a handoff signal.
- **After you have already nudged once this session** for that domain. Suggest once, then drop it —
  the maintainer heard you. Re-nudging is the noise that gets an advisory muted.
- **When already acting on the user's explicit choice to stay in `code`.**

Precision over recall: a missed nudge costs nothing; a noisy one degrades the shared advisory
channel and trains the maintainer to ignore it.

## How to Word the Nudge

Name the target agent and give the maintainer the switch-vs-relaunch tradeoff, which is *not*
symmetric:

> This looks squarely like `docs` work. `/agent docs` switches steering + skills in place
> immediately, but a switch does NOT run the new agent's startup checks (KB-staleness + handoff
> recall are skipped) — for a clean start, relaunch with `--agent docs`.

Substitute the right agent name. Keep it to one short aside, then proceed with the work if the
maintainer doesn't switch — this is a routing hint, not a gate.

## What This Is Not

This is a **nudge, not enforcement**. It never blocks a command. If a genuinely dangerous
cross-domain action needs to be *stopped* (not merely flagged), that is a separate `preToolUse` /
`shell.deniedCommands` deny-rule decision, made on its own risk merits — never folded into this
advisory.
