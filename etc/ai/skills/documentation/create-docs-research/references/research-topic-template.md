# research/ Topic File Template

Template for individual topic files within a `research/` directory.

```markdown
# [Topic name]

[One to two sentence overview of what this topic covers and why it matters to the project.]

## [Option/product] comparison

| Requirement or factor | [Option A]   | [Option B]   | [Option C]   |
| --------------------- | ------------ | ------------ | ------------ |
| [Requirement 1]       | ✅ [detail]  | ❌ [detail]  | ⚠️ [detail]  |
| [Requirement 2]       | [detail]     | [detail]     | [detail]     |
| [Requirement 3]       | [detail]     | [detail]     | [detail]     |

## Key findings

- **[Finding 1].** [Brief explanation with supporting evidence.]
- **[Finding 2].** [Brief explanation with supporting evidence.]
- **[Finding 3].** [Brief explanation with supporting evidence.]

## [Option/product deep-dives]

### [Option A name]

- **URL**: <https://example.com/option-a>
- **Purpose**: [What this option provides]
- **Key Specs**:
  - [Spec 1]
  - [Spec 2]
- **Limitations**: [Known gaps or concerns]
- **Relevance**: [How it fits this project's requirements]

### [Option B name]

- **URL**: <https://example.com/option-b>
- **Purpose**: [What this option provides]
- **Key Specs**:
  - [Spec 1]
  - [Spec 2]
- **Limitations**: [Known gaps or concerns]
- **Relevance**: [How it fits this project's requirements]

## Related documentation

- [Research: Other Topic](other-topic.md) — [how it relates]
- [ADR-NNN: Decision Title](../decisions/adr-NNN-decision-title.md) — decision informed by this
  research
```

## Template conventions

- **Summary first, details second**: Comparison table → key findings → individual deep-dives. The
  reader gets the answer at a glance, then can dig deeper if needed.
- Each file is self-contained — a reader should understand the topic without reading other research
  files.
- Comparison tables use emoji indicators (✅/❌/⚠️) for quick scanning.
- Key findings section states opinionated conclusions, not neutral summaries. Say which option is
  best and why.
- Deep-dive entries include Limitations and Relevance fields to connect back to project
  requirements.
- Related documentation links at the end cross-reference other research files and the ADRs this
  research informed.
- Not every topic file needs a comparison table — some topics are single-product evaluations or
  reference collections. Omit the comparison table and key findings sections when there is nothing
  to compare.
