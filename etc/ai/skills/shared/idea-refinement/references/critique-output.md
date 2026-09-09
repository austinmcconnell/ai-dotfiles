# Critique Output Contract

When refining an idea, present the analysis in this shape. Keep each section to a few sentences —
substance over length.

## Per-idea format

```markdown
### <idea, one line>

**Stress-test**: <does it fit the project's purpose/constraints/architecture? what does it conflict
with, duplicate, or break?>

**Scope**: <is the ask too big/vague/bundled? recommended split, narrowing, or reshape>

**Research flags**: <specific open questions that must be settled first — name them, or "none">

**Verdict**: Promote | Needs research | Reshape | Drop
<one line justifying the verdict and stating where the idea goes next>
```

## Verdict meanings

- **Promote** — survived critique; move to the Refined section (or `backlog.md`) with its scope
  decision recorded.
- **Needs research** — sound but blocked on a named unknown; stays in Unrefined with the question
  written down.
- **Reshape** — worth doing but not as asked; record the recommended change to scope or approach.
- **Drop** — doesn't fit; record the one-line reason so it isn't re-proposed later.

## Batch reviews

When reviewing several ideas at once, present them grouped by verdict (Promote first, then Reshape,
Needs research, Drop) so the actionable ones lead. End with a single recommended next action — e.g.
"promote these two and start a commit plan for the first," or "settle the research question on X
before anything else."

## Principles

- Be a critical partner, not a cheerleader. The value is in surfacing weaknesses, not validating.
- Recommend changing the *ask* when the ask is the problem — don't just refine a flawed scope.
- Tie every judgment to *this* project: its purpose, constraints, and existing code. Generic advice
  is low value.
