# Single-File RESEARCH.md Template

Best for projects with one to four research topics and under ~300 lines total. For projects with
five or more topics or deep multi-product evaluations, use the multi-file `research/` directory
format instead (see `references/templates/research-readme.md` and
`references/templates/research-topic.md`).

```markdown
# Research & Reference Materials

Curated resources for [project topic].

## Getting started

**Project context** (read first):

- [Requirements](planning/requirements.md) - Project requirements and constraints
- [ADR-001](decisions/adr-001-decision-title.md) - Key platform/architecture decision

**Then explore**:

- **[Topic Area 1]** (Core Concepts)
- **[Topic Area 2]** (As Needed)
- **[Topic Area 3]** (For Specific Integration)

## [Topic area 1]

### 1. [Resource title]

- **URL**: <https://example.com/resource>
- **Purpose**: [Why this resource is relevant]
- **Key Concepts**:
  - [Concept 1]
  - [Concept 2]
  - [Concept 3]

### 2. [Resource title]

- **URL**: <https://example.com/resource>
- **Purpose**: [Why this resource is relevant]
- **Key Concepts**:
  - [Concept 1]
  - [Concept 2]
- **Note**: [Any caveats or context about this resource]

## [Topic area 2]

### 3. [Resource title]

- **URL**: <https://example.com/resource>
- **Purpose**: [Why this resource is relevant]
- **Key Concepts**:
  - [Concept 1]
  - [Concept 2]

### 4. [Best practice or concept — no URL needed]

- **Concept**: [Description of the concept]
- **Best Practices**:
  - [Practice 1]
  - [Practice 2]
  - [Practice 3]

## [Topic area with alternatives to compare]

### [Option] comparison

| Factor        | [Option A]   | [Option B]   | [Option C]   |
| ------------- | ------------ | ------------ | ------------ |
| [Factor 1]    | ✅ [detail]  | ❌ [detail]  | ⚠️ [detail]  |
| [Factor 2]    | [detail]     | [detail]     | [detail]     |
| [Factor 3]    | [detail]     | [detail]     | [detail]     |

### Assessment

[Opinionated conclusion stating which option is the clear choice and why. Reference specific factors
from the comparison table. State trade-offs explicitly.]

### 5. [Option A details]

- **URL**: <https://example.com/option-a>
- **Purpose**: [What this option provides]
- **Key Specs**: [Relevant specifications]
- **Relevance**: [How it fits this project's requirements]

### 6. [Option B details]

- **URL**: <https://example.com/option-b>
- **Purpose**: [What this option provides]
- **Key Specs**: [Relevant specifications]
- **Relevance**: [How it fits this project's requirements]

## Project-specific context

### [Summary topic 1]

From [requirements.md](planning/requirements.md):

- **[Key parameter]**: [Value]
- **[Key parameter]**: [Value]
- **[Key parameter]**: [Value]

### Key decision points

From [ADR-001](decisions/adr-001-decision-title.md):

1. **[Decision area]**: [Choice made]
1. **[Decision area]**: [Choice made]

## Quick reference

### For common questions

- **[Topic]**: See [Resource Title] (section N) + [internal doc]
- **[Topic]**: See [Resource Title] (section N) + [internal doc]

## Additional resources

### Community resources

- **[Community 1]**: <https://example.com> - [Description]
- **[Community 2]**: <https://example.com> - [Description]
```

## Template conventions

- Number entries sequentially across all sections for easy reference
- Each entry has URL (if external), purpose, and key concepts
- Entries can be URL-based (external resources) or concept-based (best practices without URLs)
- Link back to internal docs (requirements, ADRs) to connect research to decisions
- Group by topic area, not by source type
- Include comparison tables when evaluating alternatives — table first, then assessment, then
  individual deep-dives
- Include an assessment subsection after comparison tables stating the opinionated conclusion
- Include a "Project-specific context" section summarizing key parameters from internal docs
- Include a "Quick reference" section mapping common questions to relevant entries

## When to migrate to directory format

Consider switching to a `research/` directory when:

- This file exceeds ~300 lines
- Five or more distinct topic areas exist
- Individual topics need their own comparison tables or multi-product evaluations
- Multiple ADRs reference different sections of this file
