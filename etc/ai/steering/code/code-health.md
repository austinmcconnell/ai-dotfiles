---
paths:
  - '**/*.py'
  - '**/*.js'
  - '**/*.ts'
  - '**/*.go'
  - '**/*.rb'
  - '**/*.java'
  - '**/*.rs'
  - '**/*.sh'
  - '**/*.tf'
---

# Code Health

## Why This Matters

Peer-reviewed research across 39 proprietary codebases (30,737 files) demonstrates that healthy code
enables 2x faster development, contains 15x fewer defects, and reduces estimation uncertainty by 9x
(Tornhill & Borg, 2022). A follow-up study found that refactoring to top-performer health levels
yields 43% faster delivery and 32–50% fewer post-release defects. For AI-assisted development,
unhealthy code increases defect risk by 30% and consumes up to 50% more tokens.

These are not aspirational claims — they are statistical findings from production codebases. The
principles below target the specific code properties that drive these outcomes.

## Function Length

A function should fit in your working memory. Aim for 20–30 lines of logic (excluding blank lines,
docstrings, and type declarations). Treat 60 lines as a hard ceiling — beyond that, you are almost
certainly mixing responsibilities.

Signs a function is too long:

- You need to scroll to understand what it does
- You feel the urge to add section comments within the function
- Different paragraphs of code operate on unrelated state

Refactoring: extract each logical paragraph into a named function. The name should explain the
*intent* of that section, eliminating the need for a comment.

## Bumpy Road

A "bumpy road" function has multiple sections of deeply nested code separated by flat stretches.
Each bump typically represents a distinct responsibility hiding inside one function.

How to recognize it:

- The indentation profile has several peaks (nested blocks) separated by top-level code
- The function reads like a sequence of steps that happen to share a scope
- You can insert blank lines between the bumps and each section still makes sense in isolation

Refactoring: extract each bump into its own function. The remaining function should read as a
high-level orchestration of named steps.

## Complex Conditionals

When a branch condition combines more than 2–3 boolean operators (`and`, `or`, `not`), it exceeds
what readers can parse in one pass.

Guidance:

- Aim for at most 2 boolean operators per condition expression
- Beyond that, extract sub-expressions into named booleans or predicate functions
- Name the extracted boolean after the *business rule*, not the implementation:
  `is_eligible_for_discount` not `has_flag_and_date_valid`
- Prefer early returns and guard clauses to reduce nesting and eliminate `else` branches that carry
  complex conditions

## Primitive Obsession

Primitive obsession is using bare strings, integers, or booleans to represent domain concepts that
have their own rules. It scatters validation logic across the codebase and makes invalid states
representable.

Refactor to a value object or domain type when:

- The value has validation rules (email format, non-negative amount, ISO date range)
- The same validation logic appears in multiple places
- Three or more related primitives travel together as function parameters (e.g., `street`, `city`,
  `zip` → `Address`)
- The value has a unit or constraint that bare primitives cannot express (currency + amount, lat +
  lng)

Leave values as primitives when they are purely structural with no domain rules (loop counters,
array indices, format strings).

## Cohesion and Single Responsibility

A module (file, class, or package) should have one reason to change — meaning it serves one actor or
responsibility. This is about *change frequency*, not size.

How to assess cohesion:

- If you can describe what a module does using "AND" (handles logging AND sends emails AND validates
  input), it has too many responsibilities
- Methods/functions in a class should operate on shared internal state. If subsets of methods use
  entirely disjoint attributes, the class is likely two classes merged together
- A file that requires imports from many unrelated domains is a cohesion smell

Guidance:

- Aim for one clear responsibility per file/class — the "elevator pitch" test: can you describe its
  purpose in one sentence without "and"?
- SRP is about actors and reasons to change, not line count. A 300-line file with one responsibility
  is healthier than a 50-line file with three

## Brain Method

A "brain method" combines multiple risk factors simultaneously: it is large, complex, deeply nested,
and has many dependencies. Any single factor might be manageable — the compound effect is what makes
the function impossible to hold in working memory.

The compound rule — a function becomes a brain method when it exhibits **three or more** of:

- Large (exceeds 60 lines)
- High cyclomatic complexity (many branches)
- Deep nesting (3+ levels of indentation in logic)
- Many dependencies (high parameter count or many external calls)

Brain methods are the highest-priority refactoring targets because they concentrate defect risk and
slow every developer who touches them.

## File Size

There is no universal hard limit, but files that grow beyond 300–400 lines of logic deserve
scrutiny. Files exceeding 500 lines are a red flag indicating mixed responsibilities.

Signs a file is too large:

- Multiple unrelated classes or function groups coexist
- The file requires a table of contents to navigate
- Changes to one section routinely create merge conflicts with unrelated work

Refactoring: split along responsibility boundaries, not arbitrary line counts. Each resulting file
should pass the cohesion test above.

## Code Duplication

Repetition is not inherently bad — premature abstraction is often worse than duplication. Apply the
Rule of Three: tolerate duplication until the third occurrence, then extract a shared abstraction.

When duplication is harmful:

- The same logic (aim for ~10+ lines at ~75% structural similarity) appears in three or more places
- Changes to the logic require updating multiple locations in lockstep
- The duplicated code represents a single business rule that should have one authoritative source

When repetition is acceptable:

- Two similar blocks serve different actors and may diverge independently
- The "duplication" is coincidental similarity, not shared knowledge
- Abstracting would require contorting the code with excessive parameterization

## Applying These Principles

When writing new code:

1. Start with small, focused functions — if a function grows beyond 30 lines, pause and extract
1. Name each function after its intent — good names eliminate the need for structural comments
1. Flatten nested logic with guard clauses and early returns before adding more branches
1. Represent domain concepts as types, not naked primitives
1. One file = one responsibility. When adding code, ask whether it belongs here or deserves its own
   module

When reviewing or refactoring existing code, prioritize brain methods and hotspot files (code that
changes frequently). Research shows that quality issues in frequently-modified code have
disproportionate impact on velocity and defect rates.
