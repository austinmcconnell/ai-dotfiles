# Framework Catalog

The auditing lenses, grouped by what they check. Each entry gives the **test to apply** and its
**source**. Sources are tagged `[OFFICIAL]` (primary/canonical) or `[SECONDARY]`, and marked
`[VERIFIED first-hand]` where the source text was read directly during this skill's research
(2026-09-15), versus `[flagged]` where only a snippet/publisher page was available.

Do not treat this as a box-ticking scorecard — Bradford Hill's own caveat applies to the whole
catalog: these are *viewpoints to reason from*, not a checklist that mechanically yields a verdict.

## The Six Minimum Checks

Reason through all six on every audit — they catch the most common failure modes. "Reason through,"
not "tick off": coverage is the goal, not a checkmark tally (see the box-ticking caveat above).

### 1. Epistemic-status tagging (fact vs. inference vs. speculation)

**Test:** Tag each load-bearing statement as verified fact, reported claim, inference, speculation,
or opinion. Flag any place where the *register* (flat declarative prose, specific numbers, no
hedging) exceeds the actual epistemic status — speculation written as if it were reporting is the
single most common manipulation.

<!-- Source: Intelligence Community Directive 203, "Analytic Standards," ODNI (2007, rev. 2015),
     Tradecraft Standard 3: "Properly distinguishes between underlying intelligence information and
     analysts' assumptions and judgments... Products should state assumptions explicitly when they
     serve as the linchpin of an argument." [OFFICIAL] [VERIFIED first-hand via archive.org djvu
     text; all .gov PDF endpoints returned HTTP 403]. Canonical URL: https://www.dni.gov/files/documents/ICD/ICD-203.pdf -->

### 2. Causal attribution (counterfactual test)

**Test:** For every "X caused Y," ask three questions — is the mechanism plausible? Is the
attribution exclusive (what else could cause Y)? What would Y look like *without* X (the
counterfactual)? "X happened, then Y happened, and X is bad" is correlation on a timeline, not
established cause. If the piece assigns 100% of an effect to one cause among many plausible inputs,
that is asserted, not demonstrated.

<!-- Source: Stanford Encyclopedia of Philosophy, "Counterfactual Theories of Causation" (rooted in
     David Lewis 1973): "c caused e" means had c not occurred, e would not have occurred. [SECONDARY,
     authoritative] URL: https://plato.stanford.edu/entries/causation-counterfactual/ -->

<!-- Supporting rubric: Austin Bradford Hill, "The Environment and Disease: Association or
     Causation?", Proc. Royal Society of Medicine 58 (1965): nine viewpoints — strength, consistency,
     specificity, temporality, biological gradient, plausibility, coherence, experiment, analogy.
     Hill: "None... can be required as a sine qua non" — viewpoints, not a checklist. Temporality
     (cause precedes effect) is the one necessary condition. [OFFICIAL] [VERIFIED first-hand]
     URL: https://pmc.ncbi.nlm.nih.gov/articles/PMC4291332/ -->

### 3. Precision vs. methodology (calibration)

**Test:** Does the specificity of a prediction match its disclosed method? A dated numeric
point-forecast ("gas at $4.50 in March 2027") with no model, error bars, base rate, or probability
is false precision — narrow ranges signal overconfidence, not authority. A well-formed forecast
states a specific outcome, a numeric probability, and a deadline so it can be scored after the fact.

<!-- Source: Philip Tetlock, Expert Political Judgment (Princeton UP, 2005) — experts are
     systematically overconfident; "hedgehogs" forcing events through one big idea do worse than
     "foxes" weighing many. [OFFICIAL, trade/academic book — NOT verified first-hand]. Operationalized
     in Mellers/Ungar/Tetlock et al., "Psychological Strategies for Winning a Geopolitical
     Forecasting Tournament," Psychological Science (2014) [OFFICIAL, peer-reviewed — flagged:
     SagePub returned 403, confirmed via search snippet not full text]. -->

<!-- Supporting: ICD 203 Tradecraft Standard 2 mandates a probability lexicon (e.g. "very unlikely
     05-20%", "likely 55-80%") and forbids mixing terms — a professional standard for expressing
     forecast uncertainty. [OFFICIAL] [VERIFIED first-hand, see check 1 source] -->

<!-- Boundary condition: Nassim Taleb, The Black Swan (Random House, 2007) — in complex, fat-tailed
     domains, precise point forecasts of rare high-impact events are unreliable; the "ludic fallacy"
     is treating messy reality like a game with stable known odds. [OFFICIAL, trade book — not
     first-hand; no single canonical free URL]. -->

### 4. Falsifiability (demarcation)

**Test:** Ask what observation would prove the thesis wrong. A claim compatible with *every*
possible outcome — "if nothing changes, this happens," rescued from any counter-evidence — explains
nothing and predicts nothing. Watch for the *ad hoc rescue*: a framing ("a projection, not a
prophecy") that lets the author claim vindication if it happens and "the path changed" if it
doesn't. Use falsifiability as a *question to ask*, not a mechanical pass/fail (the
Duhem–Quine/Lakatos "protective belt" means a single counter-instance rarely settles it).

<!-- Source: Stanford Encyclopedia of Philosophy, "Karl Popper" [SECONDARY, authoritative]
     [VERIFIED first-hand]. Falsifiability as demarcation; the logical asymmetry (no confirmations
     verify a universal, one counter-instance refutes it); Marxism "saved from falsification by the
     addition of ad hoc hypotheses"; and §9: unconditional prophecy is impossible for systems that
     are not "well isolated, stationary, and recurrent" — "modern society is surely not one of
     them" (Popper 1963). Directly bears on month-by-month socio-economic forecasts.
     URL: https://plato.stanford.edu/entries/popper/  Primary: Popper, The Logic of Scientific
     Discovery (1959); Conjectures and Refutations (1963) [OFFICIAL, print]. -->

### 5. Source load & one-sidedness

**Test:** Count the load-bearing sources — if removing one collapses the thesis, that is a single
point of failure; flag it. An op-ed asserting a conclusion is a *claim*, not evidence for it. Then
check directionality: does every data point cut the same way, with no seriously-engaged
counter-scenario? A one-directional ledger is advocacy, not analysis.

<!-- Source: ICD 203 Tradecraft Standard 4 "Incorporates analysis of alternatives" (explicitly names
     "forecasting future trends" and "low probability... high-impact" cases) and Standard 6
     "acknowledge significant supporting and contrary information." [OFFICIAL] [VERIFIED first-hand] -->

<!-- Source (misrepresenting opponents): Aikin & Casey, "Straw Men, Weak Men, and Hollow Men,"
     Argumentation 25(1) (2011) — the "weak man" (attacking a real but unrepresentative version of
     an opposing view) is subtler than the straw man. [OFFICIAL, peer-reviewed]. PhilPapers:
     https://philpapers.org/rec/AIKSMW -->

### 6. Tone as a tell

**Test:** Mark every place the author reaches for contempt, ridicule, or loaded language ("morons,"
"the regime," "the arsonist"). Treat each as a pointer to *where to look* for a missing argument —
loaded language often stands in for a claim the author did not make. Then supply the skepticism the
tone is trying to preempt.

<!-- Source: NONE — this is an interpretive heuristic, not a sourced empirical finding, and is
     tagged as such per this file's honesty rule. Its cousin is the classical rhetoric distinction
     of logos vs. pathos (persuasion by emotion vs. by reason), but "tone reveals a weak argument"
     is an opinion/rule-of-thumb. Use it to locate weaknesses, never as proof of one — the sourced
     checks (1–5) must confirm any weakness it points to. -->

## Deeper Lenses (load when a fuller audit is warranted)

### Toulmin decomposition

**Test:** Break an argument into claim, grounds (data), warrant (the usually-*unstated* assumption
linking grounds to claim), backing, qualifier, and rebuttal. The **warrant** is the highest-value
target: unstated warrants are where weak arguments hide their leaps.

<!-- Source: Stephen E. Toulmin, The Uses of Argument (Cambridge UP, 1958) [OFFICIAL, print — NOT
     verified first-hand]. Operational breakdown: Purdue OWL [SECONDARY]:
     https://owl.purdue.edu/owl/general_writing/academic_writing/historical_perspectives_on_argumentation/toulmin_argument.html -->

### Analysis of Competing Hypotheses (ACH) & Key Assumptions Check (KAC)

**Test (ACH):** List all plausible explanations, not just the author's. Array the evidence against
*every* hypothesis, and weight evidence that is *inconsistent* with (disconfirms) a hypothesis over
evidence that merely fits it. Does the piece's conclusion survive a search for disconfirming
evidence, or does it only cherry-pick support? **Test (KAC):** List the assumptions the argument
rests on; ask which, if wrong, would collapse the conclusion. Surface the load-bearing *unstated*
assumptions and stress-test those.

<!-- Source: Richards J. Heuer Jr. & Randolph H. Pherson, Structured Analytic Techniques for
     Intelligence Analysis (CQ Press/SAGE, 3rd ed. 2019); Heuer, Psychology of Intelligence Analysis
     (origin of ACH). [OFFICIAL, authors' canonical texts — NOT verified first-hand; publisher +
     pherson.org confirmed]. Note: empirical tests of ACH's debiasing effect are mixed — it is a
     rigor scaffold, not a proven bias-eliminator. -->

### Lateral reading (source credibility)

**Test:** To vet a source, *leave it* — open new tabs and see what independent authoritative sources
say *about* the author/outlet — rather than judging by the page's own polish or self-description.
This is what professional fact-checkers do; it is faster and more accurate than reading vertically.

<!-- Source: Sam Wineburg & Sarah McGrew, "Lateral Reading and the Nature of Expertise," Teachers
     College Record 121(11) (2019); Stanford History Education Group, Civic Online Reasoning.
     [OFFICIAL, peer-reviewed — flagged: SagePub returned 403, confirmed via search + SHEG].
     URL: https://journals.sagepub.com/doi/10.1177/016146811912101102 -->

### Paul–Elder intellectual standards

**Test:** As a comprehensive rubric, grade the argument's elements (purpose, question, information,
inferences, concepts, assumptions, implications, point of view) against the universal standards:
clarity, accuracy, precision, relevance, depth, breadth, logic, significance, fairness. Heavier than
the six minimum checks — use it when a thorough scored audit is wanted.

<!-- Source: Foundation for Critical Thinking (Richard Paul & Linda Elder), criticalthinking.org
     [OFFICIAL, originating institution]. URL:
     https://www.criticalthinking.org/pages/critical-thinking-where-to-begin/796 -->

### CRAAP test (lightweight source check)

**Test:** Currency, Relevance, Authority, Accuracy, Purpose — a beginner mnemonic for source
evaluation. Explicitly **subordinate to lateral reading**: it is a vertical/on-page checklist, which
is exactly the method lateral reading was developed to improve on. Use only as a quick reminder, not
the primary source audit.

<!-- Source: Sarah Blakeslee, Meriam Library, CSU Chico (2004). [OFFICIAL for what it is —
     single-institution librarian handout]. URL: https://library.csuchico.edu/help/source-or-information-good -->

## Sourcing Notes (honesty ledger)

- **Verified first-hand (source text read 2026-09-15):** ICD 203 (nine tradecraft standards, via
  archive.org djvu text); Popper (SEP entry, in full); Bradford Hill (PMC full text).
- **Not verified first-hand — cite with this caveat:** Toulmin (1958 print monograph); Tetlock 2014
  tournament paper (SagePub 403, snippet only); lateral-reading paper (SagePub 403, confirmed via
  search + SHEG); Taleb (trade book, no canonical free URL); Heuer/Pherson (publisher pages).
- **Term with no academic origin:** "steelmanning" is a rationalist-community coinage. The *concept*
  is sound and sourced — the **principle of charity** (Davidson 1974, building on Quine) — but do
  not attribute the *word* "steelman" to a scholarly source; it has none.
