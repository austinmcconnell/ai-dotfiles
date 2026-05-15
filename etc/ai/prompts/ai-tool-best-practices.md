# AI Tool Best Practices Audit

Research current best practices for a specific AI tool's configuration and compare against the local
dotfiles implementation. Run this for one tool at a time.

## Tool Discovery

Read `install/ai-tools.sh` and check which tool directories exist under `etc/` to determine the
available AI tools. Each tool has a directory in `etc/` with its configuration files and a
`README.md` documenting its setup.

If the user specified a tool in their message, proceed with that tool. Otherwise, present the
discovered tools as a numbered list and ask which one to audit.

## Research Phase

Search official documentation for the target tool's current best practices. Focus on:

1. **Security permissions** — recommended deny/allow patterns, least-privilege guidance
1. **MCP server setup** — security recommendations, configuration conventions
1. **Steering/rules files** — structure, sizing, scoping recommendations
1. **New features** — recently added configuration options relevant to security or workflow
1. **Deprecations** — features or patterns that are no longer recommended

Use these official documentation sources:

- Kiro CLI: <https://kiro.dev/docs/cli/>
- Claude Code: <https://docs.anthropic.com/en/docs/claude-code/>
- Cursor: <https://docs.cursor.com/>

Provide source URLs for every recommendation.

## Comparison Phase

Read the selected tool's configuration directory (`etc/<tool>/`) including its `README.md`. The
README documents the current configuration model, best practices already followed, and intentional
deviations — use it as the baseline for comparison.

Also read `etc/ai/README.md` and `AGENTS.md` for shared infrastructure context.

Compare the local config against researched best practices. Categorize findings as:

- **Aligned** — local config follows the recommendation
- **Gap** — recommendation not implemented, would improve security or workflow
- **Intentionally Different** — local config deviates but for documented reasons (check README)

## Evaluation Criteria

For each gap, critically evaluate:

- Does this solve a real problem for this setup?
- What's the maintenance burden vs. benefit?
- Does it conflict with the cross-tool parity principle?
- Is it a security improvement or just a style preference?

Skip recommendations that add complexity without solving a real problem.

## Output Format

Write findings to `analysis/<tool>-best-practices-audit.md` with:

1. **Research Summary** — key best practices found, with source URLs
1. **Aligned** — what's already correct (brief list)
1. **Gaps** — actionable improvements with rationale and priority (high/medium/low)
1. **Intentionally Different** — documented deviations confirmed as appropriate
1. **Not Applicable** — recommendations that don't fit this setup (one-line reasons)

For each gap, include the specific config change needed (code example).
