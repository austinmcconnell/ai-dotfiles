# Zsh & Zephyr Best Practices Audit

Research current best practices for zsh configuration and the Zephyr framework, then compare against
the local dotfiles implementation.

## Local Configuration Discovery

Read these files to understand the current setup:

- `etc/zsh/.zstyles` — Zephyr plugin configuration via zstyles
- `etc/zsh/.zsh_plugins.txt` — Antidote plugin manifest
- `etc/zsh/conf.d/` — Topic-specific configuration files
- `etc/zsh/.zshrc` — Main shell configuration
- `etc/zsh/.zshenv` — Environment variables (all shells)
- `etc/zsh/.zprofile` — Login shell configuration
- `etc/zsh/functions/` — Autoloaded custom functions
- `AGENTS.md` — Zsh Configuration Architecture section

## Research Phase

Search for current best practices and recent changes. Focus on:

1. **Zephyr upstream** — check <https://github.com/mattmc3/zephyr> for recent commits, README
   changes, new plugins, deprecated options, or zstyle changes
1. **Antidote** — check <https://github.com/mattmc3/antidote> for new features, performance
   recommendations, or loading pattern changes
1. **Zsh options** — recently recommended setopt/unsetopt patterns for history, completion,
   navigation, and safety
1. **History management** — best practices for HISTSIZE, SAVEHIST, share_history, deduplication, and
   backup strategies
1. **Startup performance** — profiling techniques, deferred loading patterns, compilation
   recommendations
1. **Security** — zsh-specific security considerations (history file permissions, autoloading from
   untrusted paths, etc.)
1. **Completion system** — compinit optimization, caching, and recommended styles

## Comparison Phase

Compare the local config against researched best practices. Categorize findings as:

- **Aligned** — local config follows the recommendation
- **Gap** — recommendation not implemented, would improve performance, security, or correctness
- **Intentionally Different** — local config deviates for documented reasons
- **New Feature** — upstream added something not yet adopted locally

## Evaluation Criteria

For each gap or new feature:

- Does this solve a real problem or improve measurable startup time?
- Is it compatible with the current plugin set (antidote static loading, Zephyr confd)?
- Does it conflict with existing conf.d files or zstyle settings?
- What's the risk of breakage vs. benefit?

Skip recommendations that are purely stylistic or framework-specific to oh-my-zsh/prezto.

## Output Format

Write findings to `analysis/zsh-best-practices-audit.md` with:

1. **Research Summary** — key findings from Zephyr/antidote/zsh community, with source URLs
1. **Aligned** — what's already correct (brief list)
1. **Gaps** — actionable improvements with rationale and priority (high/medium/low)
1. **New Features** — upstream additions worth evaluating
1. **Intentionally Different** — deviations confirmed as appropriate
1. **Not Applicable** — recommendations that don't fit this setup (one-line reasons)

For each gap, include the specific config change needed.
