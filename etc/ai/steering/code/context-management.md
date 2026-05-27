# Context Management

## Context Budget Awareness

Monitor your context usage throughout a session. When working on complex tasks:

- After completing a distinct phase of work, assess whether compaction would help
- If you notice the conversation has grown long with many tool calls, suggest compaction
- Before starting a new phase that will require significant context (reading many files, multi-step
  implementation), consider whether prior exploration context is still needed

## When to Suggest Compaction

Suggest `/compact` at these natural breakpoints:

- **After research/exploration phase** — findings are summarized, ready to implement
- **After completing a milestone** — feature works, tests pass, ready for next task
- **After a debugging session** — root cause found and fixed, debug context no longer needed
- **After a failed approach** — lessons learned, switching to a different strategy
- **After a planning phase** — plan is documented, ready to execute
- **Between unrelated tasks** — finishing one topic before starting another

## When NOT to Compact

Do NOT suggest compaction when:

- **Mid-implementation** — holding file paths, variable names, partial code in context
- **During iterative debugging** — actively narrowing down a problem
- **Holding user decisions** — user made choices that haven't been acted on yet
- **In a verification loop** — running tests/lints and fixing issues iteratively
- **When context is small** — compaction adds overhead when there's little to compress

## Writing Good Compaction Summaries

When compaction occurs (whether user-initiated or automatic), the summary should preserve:

1. **Decisions made** — what was chosen and why (not just what)
1. **File paths modified** — exact paths, not descriptions
1. **Current state** — what's done, what's in progress, what's next
1. **Failed approaches** — what was tried and why it didn't work
1. **User preferences** — any stated preferences about approach or style

## Relationship to Auto-Compaction

Auto-compaction is a safety net that fires when context approaches capacity. Strategic compaction at
breakpoints is preferred because:

- You choose WHEN to summarize (at a logical boundary, not mid-thought)
- You control WHAT to preserve (important context, not just recent messages)
- The summary is higher quality (written with full understanding of what matters)

Auto-compaction should rarely trigger if you compact strategically.

## Configured Token Settings

The following settings are active and affect compaction behavior:

### Kiro CLI (`cli.json`)

- `compaction.excludeContextWindowPercent: 15` — preserves the most recent 15% of context during
  compaction (keeps working memory intact)
- `compaction.excludeMessages: 4` — last 4 message exchanges survive compaction unchanged

### Claude Code

- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=60` — triggers compaction at 60% context usage instead of ~95%

### What's NOT Configured (and why)

- **Thinking token cap** — not available in Kiro CLI; for Claude Code, strategic compaction at
  breakpoints is preferred over capping thinking (quality over speed)
- **Subagent model downgrade** — subagent quality matters for complex delegated work; not worth the
  cost savings
- **Compaction trigger threshold in Kiro CLI** — not available as a setting; only
  `excludeContextWindowPercent` (what to preserve) is configurable
