# Agent Harness Audit

Audit this AI dotfiles repo as an agent harness: map what it already does, find the gaps, and
recommend the smallest fixes. This is analysis only. Do not edit any tracked file.

## Context

This repo is deliberately a "soft harness", not a hand-built or pre-made one:

- Skills hold the procedures
- Hooks, permissions, and pre-commit enforce rules
- Steering sets policy
- engram holds cross-session memory and handoffs
- `ideas.md`, `backlog.md`, and `todo.md` hold the work queue

These pieces cover Claude Code, Kiro CLI, Cursor, and Codex.

Before anything else, read `etc/ai/steering/shared/model-gates.md` and search engram for the
`decision/model-routing-step-up` memory. Together they record the decision against a dedicated
harness: the main session stays on a mid or small model and steps up to the strongest model at
gates. Do not reopen that decision unless you find evidence that it is failing.

## Grounding

1. Read `AGENTS.md`, `etc/ai/README.md`, `etc/claude-code/README.md`, and
   `etc/kiro-cli/README.md`, then follow their pointers as needed.
1. Check what the docs claim against the code: hooks, settings, permission lists, the persona
   generator and validators, and `.pre-commit-config.yaml`.
1. Read the recent git log in full, without `--oneline`, so you see what changed and why.

## Harness Layers

Inventory each layer. For each one, record:

- **Mechanism**: which files or features implement it
- **Strength**: enforced (a hook, permission, or pre-commit check) or advisory (steering or skill
  text)
- **Coverage**: which tools it reaches
- **Evidence**: the file and line, or the transcript, that shows it

Layers:

1. **Model routing and gates**: which model runs planning, doubt checks, implementation, and
   mechanical work, and how each is reached
1. **Work loop**: plan → review → implement → verify → commit
1. **Adversarial review**: when a doubt review is suggested, who approves it, and what the reviewer
   receives
1. **Enforcement**: hooks, permission allow, ask, and deny lists, and pre-commit
1. **Memory and handoff**: engram saves, handoffs, and session-start recall
1. **Work queue**: the idea-refinement funnel and `todo.md`
1. **Verification**: tests, validators, and the verification loop
1. **Cost and usage tracking**: what is priced, and what spend is invisible
1. **Context management**: compaction settings and handoff points
1. **Subagents and personas**: which exist, which model each runs on, and what tools each has
1. **Cross-tool parity**: which layers only one tool has

## Behavior Check

Configuration says what should happen; transcripts show what did. Sample recent sessions (Claude
Code transcripts live under `~/.claude/projects/`; use other tools' logs where they exist) and
check whether the gates and skills fired when they should have. For example:

- Was a doubt review suggested before a non-trivial plan was presented?
- Did a required skill load before its work began?
- Did a subagent run on the expected model?

Note every advisory rule that was skipped and every enforced one that did not fire.

Transcripts are local to each machine. A commit that arrived by a fast-forward pull (`git reflog`
shows it as a merge from a remote) has no session to sample here, so list it as unobserved rather
than judging whether its gates fired.

## Gaps

Rank the gaps by impact. For each, propose the smallest fix that uses the repo's existing building
blocks: a skill line, a hook, a permission rule, or a validator. Recommend an outside harness only
if no existing building block can close the gap, and say why.

## What to Ignore

- Features one tool lacks entirely, unless the gap matters for a layer above
- Differences documented as intentional deviations in the tool READMEs
- Style and wording issues that do not change behavior

## Output Format

Write the findings to `analysis/agent-harness-audit.md` with:

1. **Summary**: a short verdict on how well the soft harness holds up
1. **Inventory table**: one row per layer:

| Layer | Mechanism | Strength | Coverage | Evidence |
| ----- | --------- | -------- | -------- | -------- |

1. **Ranked gaps**: each with its impact, its evidence, and the smallest fix
1. **Open questions**: what you could not settle from the repo or the transcripts

Mark every claim as verified, inferred, or assumed. Finish by offering to capture the gaps in
`ideas.md` for idea refinement. Ask clarifying questions before starting if anything is ambiguous.
