---
name: stress-test-analysis
description: Critically analyze and stress-test the claims, evidence, and conclusions of an article, essay, op-ed, or argument using established epistemology, forecasting, and argumentation frameworks. Use when auditing an article, stress-testing claims, fact-checking an argument, evaluating a piece's reasoning, or asked to critique the logic of a written work.
---

# Stress-Test Analysis

Audit a written argument (article, essay, op-ed, report, or a claim set) for the soundness of its
claims, evidence, and conclusions — separating what the piece *establishes* from what it merely
*asserts*. This is the workflow behind the `analytical-discipline` steering principles.

The goal is **not** to agree or disagree with the piece's conclusion. It is to assess whether the
conclusion is *earned by the evidence presented*. A well-argued piece you disagree with passes; a
poorly-argued piece you agree with fails.

## When to Use

- The user shares an article/essay/op-ed and asks you to stress-test, audit, critique, or fact-check
  its claims or reasoning.
- The user asks whether a piece's conclusion is supported, or where its argument is weak.
- You are about to rely on an outside piece as evidence and need to gauge its trustworthiness.

## Core Workflow

### 1. Read the whole piece first

Fetch and read the entire argument before judging any part. Note its central thesis (the one
sentence the whole piece exists to establish) and the main claims that support it. Use `web_fetch`
in `full` mode here — auditing an argument means you need the *whole* text, so this is the justified
exception to `debugging-discipline`'s "fetch narrowly" rule (which targets extracting one fact from
a large doc-site page, not reading a piece end to end). Use `selective` with tight `search_terms`
only for oversized pages where you need specific claims, not the full argument.

### 2. State the verifiability frame up front

Before analyzing, declare what you *can* and *cannot* verify, and say so plainly:

- **Time-boxed facts** — claims about events, prices, or data you cannot independently confirm
  (especially recent or future-dated events). Do not assert these true or false; flag them as
  load-bearing-but-unverified.
- **Checkable facts** — claims you can verify against sources; verify the decision-critical ones.
- **Non-factual content** — the reasoning, forecasts, and rhetoric, which you assess on their
  internal merits regardless of the facts.

This frame is itself an honesty move: it prevents you from laundering unverified premises into a
confident verdict.

### 3. Decompose and tag every load-bearing statement

Break the argument into its claims and tag each by **epistemic status**: verified fact, reported
claim, inference, speculation, or opinion. The central diagnostic is *mismatch* — speculation
written in the flat declarative register of fact, a forecast stated as if reported. For the specific
tests to apply, load `references/framework-catalog.md` and work the checklist.

### 4. Run the framework checks

Apply the auditing lenses from `references/framework-catalog.md`. At minimum, reason through these
six lenses (they catch the most common failures) — "reason through," not "tick off": the point is
coverage, not tallying checkmarks into a verdict.

1. **Epistemic-status tagging** — is speculation dressed as fact? (ICD 203 std 3)
1. **Causal attribution** — for every "X caused Y," is the counterfactual established, or is it
   correlation on a timeline? (counterfactual test / Bradford Hill)
1. **Precision vs. methodology** — do specific numbers/dates rest on a disclosed model, or are they
   false precision? (Tetlock calibration; ICD 203 std 2)
1. **Falsifiability** — what observation would prove the thesis wrong? If none, it is narrative, not
   prediction. (Popper)
1. **Source load & one-sidedness** — does removing one source collapse the thesis? Is every data
   point cutting the same direction with no steelmanned counter? (ICD 203 std 4 & 6; weak-man)
1. **Tone as a tell** — where the author reaches for contempt or loaded language, mark it: each
   loaded term is a place where an argument should be. This is an interpretive *heuristic*, not a
   sourced empirical test — treat it as a pointer to *where to look* for a missing argument, not as
   proof of one.

Load the catalog for the deeper lenses (Toulmin decomposition, analysis of competing hypotheses, key
assumptions check, lateral reading, Paul-Elder standards) when the piece warrants a fuller audit.

### 5. Verify the decision-critical facts

For the handful of claims the thesis actually rests on, verify against authoritative sources rather
than asserting from memory (see `research-delegation` steering). Prefer primary/official sources;
tag community/secondary sources as such. If a load-bearing fact cannot be verified, say so — an
unverifiable linchpin is itself a finding.

### 6. Write the audit

Produce the structured output in `references/output-template.md`: the verifiability frame, what the
argument gets right (steelman first), where it breaks down (by failure type, with evidence), the
verification caveat, and a bottom-line verdict that separates rhetoric quality from analytic quality
from predictive validity.

## Rules

- **Steelman before critiquing.** State the strongest version of the argument and what it gets right
  *before* listing weaknesses. A critique that only attacks is incomplete and less credible.
- **Attack the argument, not the author or the conclusion.** Never let agreement or disagreement
  with the thesis substitute for assessing whether it was earned.
- **Cite the specific failure, with the specific text.** "This is speculation dressed as fact"
  requires quoting the sentence and naming why. Vague "this seems biased" is not an audit.
- **Do not manufacture balance.** If the piece is genuinely sound, say so. If it is uniformly weak,
  say that. Sizing the critique to the evidence applies to your audit too.
- **Verify your own load-bearing claims.** If you assert a framework says X or a fact is Y, that is
  itself subject to this skill's standard — verify it (see `analytical-discipline` steering).

## Reference Files

- Load `references/framework-catalog.md` in step 3–4 — the auditing lenses, each with the specific
  test to apply and its verified source. This is the core reference; load it for any real audit.
- Load `references/output-template.md` in step 6 — the structure for the written audit.
- Read `references/worked-example.md` if you want a full end-to-end example of the workflow applied
  to a real article, or if unsure how much depth an audit warrants.

## Validation Checklist

- [ ] Read the entire piece before judging
- [ ] Stated the verifiability frame (what can/can't be verified) up front
- [ ] Tagged load-bearing statements by epistemic status
- [ ] Reasoned through the six minimum framework lenses (including tone-as-a-tell)
- [ ] Verified the decision-critical facts against sources (or flagged them unverifiable)
- [ ] Steelmanned the argument before critiquing
- [ ] Every failure cited specific text and a specific failure type
- [ ] Bottom line separates rhetoric / analysis / prediction quality
- [ ] Critique sized to the evidence — no manufactured balance in either direction
