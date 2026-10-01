---
name: doubt-driven-development
description: Subject a non-trivial decision to a fresh-context adversarial review before it stands. Use when stress-testing a plan for hidden failure modes, before committing non-trivial code, when crossing a module or service boundary, when asserting a property a compiler cannot verify (thread-safety, idempotence, ordering, invariants), when working in unfamiliar code, or when a confident output would be cheaper to verify now than to debug later.
---

# Doubt-Driven Development

A confident answer is not a correct one. A long session accumulates context that quietly turns
assumptions into "facts" no one re-checks. Doubt-driven development is the discipline of
materializing a fresh-context reviewer — biased to **disprove**, not approve — before a non-trivial
output stands.

This is not a post-hoc PR review (that is the `pr-review` skill — a verdict on a finished artifact).
This is an *in-flight* posture: a non-trivial decision gets cross-examined while course-correction
is still cheap. It is the procedural companion to the `analytical-discipline` steering (which
supplies the epistemic vocabulary — tag status, demand the counterfactual, steelman) and a sibling
of `stress-test-analysis` (which audits an outside article; this audits your own in-progress
decision).

> Adapted from [`addyosmani/agent-skills`](https://github.com/addyosmani/agent-skills) (MIT),
> re-idiomed to this repo's subagent trust model and external-CLI posture.

## When to Use

A decision is **non-trivial** when at least one is true:

- It introduces or modifies branching logic
- It crosses a module or service boundary
- It asserts a property the type system or compiler cannot verify (thread-safety, idempotence,
  ordering, invariants)
- Its correctness depends on context a future reader cannot see
- Its blast radius is hard to reverse (production deploy, data migration, public API change)

**When NOT to use** — if you doubt every keystroke, you ship nothing:

- Mechanical operations (renaming, formatting, file moves)
- Following a clear, unambiguous instruction
- Reading or summarizing existing code
- One-line changes with obvious correctness
- Pure tooling operations (running tests, listing files)
- The user has explicitly asked for speed over verification

## Loading Constraint — main-session / `code` orchestrator only

Step 3 (DOUBT) spawns a fresh-context reviewer via the `subagent` tool. Per the subagent trust model
(`etc/kiro-cli/README.md`), only the `code` agent is trusted to spawn subagents that inherit tool
approval, and the `agent-routing` steering establishes `code` as the generalist orchestrator. The
four scoped personas (`docs`, `ansible`, `jira`, `datadog`) **must not** run this loop — a persona
spawning a reviewer subagent is the "personas don't invoke personas" anti-pattern. If a scoped
persona reaches a non-trivial decision that warrants doubt, surface it to the user and let the main
`code` session run the loop rather than spawning from inside the persona.

## The Process

Copy this checklist when applying the skill:

```text
Doubt cycle:
- [ ] Step 1: CLAIM — wrote the claim + why-it-matters
- [ ] Step 2: EXTRACT — isolated artifact + contract, stripped reasoning
- [ ] Step 3: DOUBT — invoked fresh-context reviewer with adversarial prompt
- [ ] Step 4: RECONCILE — classified every finding against the artifact text
- [ ] Step 5: STOP — met stop condition (trivial findings, 3 cycles, or user override)
```

### Step 1: CLAIM — surface what stands

Name the decision in two or three lines:

```text
CLAIM: "The new caching layer is thread-safe under the read-heavy workload the spec describes."
WHY THIS MATTERS: a race here corrupts user data and is hard to detect in QA.
```

If you can't write the claim that compactly, you have a vibe, not a decision. Surface it before
scrutinizing it.

### Step 2: EXTRACT — smallest reviewable unit

A fresh-context reviewer needs the **artifact** and the **contract**, not the journey.

- Code: the diff or the function — not the whole file
- Decision: the proposal in 3–5 sentences plus the constraints it must satisfy
- Assertion: the claim plus the evidence that supposedly supports it

Strip your reasoning. If you hand over conclusions, you get back validation of your conclusions. The
unit must be small enough to hold in one read — if it's a 500-line change, decompose first.

### Step 3: DOUBT — invoke the fresh-context reviewer

Spawn a fresh-context **`code`** subagent via the `subagent` tool from the main session. The
reviewer's prompt **must be adversarial** — framing decides the answer:

```text
Adversarial review. Find what is wrong with this artifact. Assume the author is overconfident.

Look for:
- Unstated assumptions
- Edge cases not handled
- Hidden coupling or shared state
- Ways the contract could be violated
- Existing conventions this might break
- Failure modes under unexpected input

Do NOT validate. Do NOT summarize. Find issues, or state explicitly that you cannot find any
after thorough examination.

ARTIFACT:
CONTRACT:
```

**Pass ARTIFACT + CONTRACT only. Do NOT pass the CLAIM.** Handing the reviewer your conclusion
biases it toward agreement; it must independently determine whether the artifact satisfies the
contract. This mirrors the `research-delegation` pattern — the subagent scans and reports, the
orchestrator reconciles — but inverted to disprove rather than survey.

#### Cross-model escalation (optional, interactive only)

A single-model reviewer shares blind spots with the original author; a different-architecture model
catches some of them. This is offered, never silent — and it never runs without explicit
per-invocation authorization, consistent with this repo's shell-approval posture (every `shell`
write/exec is user-approved) and the `shell-conventions` rule to locate external tools dynamically.

**Interactive sessions:** after the single-model review, before RECONCILE, offer:

> *"Single-model review complete. Want a cross-model second opinion via an external CLI (e.g.
> Codex), a manual external review you paste back, or skip?"*

If the user picks an external CLI:

1. Confirm it exists (`command -v codex`) and runs (`codex --version`) — a stale binary can pass the
   first check and fail on real input.
1. Confirm the exact invocation, flags, and any required auth/env with the user. Implementations
   vary; never assume. Each invocation is its own authorization — re-confirm every run.
1. Write the adversarial prompt + ARTIFACT + CONTRACT to a temp file and pipe via **stdin**. Never
   interpolate the artifact into a shell-quoted argument — code and markdown routinely contain
   backticks, `$(...)`, and quotes that truncate the prompt or execute embedded shell.
1. Use a read-only sandbox: a doubt artifact may itself carry injected instructions the CLI would
   otherwise execute against the workspace.

```bash
# Codex is the external CLI configured in this repo (etc/codex/). Verify flags against the
# installed version — syntax drifts across releases. For any other external CLI, confirm its
# own read-only + stdin invocation with the user first.
codex exec --sandbox read-only - < /tmp/doubt-prompt.md
```

If the CLI is unavailable or errors, surface it and offer manual review or skip — never silently
fall back to single-model. If the user skips, acknowledge the skip in the output and continue.

**Non-interactive contexts** (subagent runs, scheduled/automated loops): cross-model is **skipped**,
and the skip is announced. Never invoke an external CLI without explicit user authorization.

### Step 4: RECONCILE — fold findings back

The reviewer's output is data, not verdict. **You are still the orchestrator.** Re-read the artifact
text against each finding before classifying — rubber-stamping the reviewer is the same failure mode
as ignoring it. Classify each finding in this **precedence order** (first match wins):

1. **Contract misread** — reviewer flagged something because the CONTRACT you gave was unclear or
   incomplete. Fix the contract first, re-classify next cycle.
1. **Valid + actionable** — real issue requiring a change. Change it, re-loop.
1. **Valid trade-off** — real, but the fix costs more than accepting it. Document the trade-off so
   the user sees it.
1. **Noise** — correct under context the reviewer lacked. Note it, and ask whether adding that
   context to the contract would have prevented the false flag.

A fresh reviewer can be wrong because it lacks context. Don't defer just because it's "fresh."

### Step 5: STOP — bounded loop, not recursion

Stop when:

- The next iteration returns only trivial or already-considered findings, **or**
- 3 cycles are complete — escalate to the user, don't grind a fourth alone, **or**
- The user explicitly says "ship it"

If after 3 cycles the reviewer still surfaces substantive issues, that is information about the
artifact — surface it, don't keep looping. If 3 cycles feels "obviously insufficient" because the
artifact is large, the artifact is too big: return to Step 2 and decompose. Do not lift the bound.

## Common Rationalizations

| Rationalization                                      | Reality                                                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| "I'm confident, skip the doubt step"                 | Confidence correlates poorly with correctness on novel problems. Certainty is exactly when blind spots hide. |
| "Spawning a reviewer is expensive"                   | Debugging a wrong commit in production is more expensive. The check is bounded; the bug isn't.               |
| "The reviewer will just nitpick"                     | Only if unscoped. Constrain it to "issues that would make this fail under the contract."                     |
| "I'll do doubt at the end with a PR review"          | A PR review is a final gate. Doubt-driven catches wrong directions early, when course-correction is cheap.   |
| "If I doubt every step I'll never ship"              | The skill applies to non-trivial decisions, not every keystroke. Re-read "When NOT to Use."                  |
| "The reviewer disagreed so I was wrong"              | The reviewer lacks your context — disagreement is information, not verdict. Re-read, classify, decide.       |
| "User said yes once, so I can keep invoking the CLI" | Each invocation is its own authorization. Artifact, prompt, and flags change — re-confirm every run.         |

## Red Flags

- Spawning a reviewer for a one-line rename or formatting change
- Treating reviewer output as authoritative without re-reading the artifact text
- Looping past 3 cycles without escalating
- Prompting the reviewer with "is this good?" instead of "find issues"
- Re-spawning on an unchanged artifact (same findings; you're stalling)
- **Doubt theater:** across 2+ cycles where the reviewer surfaced substantive findings, zero were
  classified actionable — you are validating, not doubting. Stop and escalate.
- Passing the CLAIM or your reasoning to the reviewer (biases toward agreement)
- Stripping the contract from the reviewer's input
- A scoped persona running this loop instead of surfacing to the main `code` session
- Invoking an external CLI without a PATH check, working-binary test, syntax confirmation, and
  explicit authorization — or interpolating the artifact into a shell-quoted argument
- Silently skipping or silently falling back on cross-model — the skip is fine, the silence is not

## Verification

- [ ] Every non-trivial decision was named as a CLAIM before standing
- [ ] At least one fresh-context review per non-trivial artifact
- [ ] The reviewer received ARTIFACT + CONTRACT — NOT the CLAIM, NOT your reasoning
- [ ] The reviewer's prompt was adversarial ("find issues"), not validating ("is it good")
- [ ] Findings classified against the artifact text using the precedence order
- [ ] A stop condition was met (trivial findings, 3 cycles, or user override)
- [ ] Any external CLI invocation had a PATH check, working-binary test, syntax confirmation, and
  explicit per-invocation authorization, and was passed the artifact via stdin under a read-only
  sandbox
