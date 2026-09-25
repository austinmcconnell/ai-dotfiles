# AI Usage/Cost Tracking

Local, durable tracking of token usage and estimated $ cost across AI coding tools, stored outside
engram in a SQLite database that isn't committed to git. Tool-agnostic by design, but only Claude
Code is wired up today — see "Why Kiro CLI isn't wired up" below.

## Storage

- **DB**: `~/.local/share/ai-usage/usage.db` — sibling to the existing `~/.local/share/ai-audit/`
  directory (`audit-shell-commands.sh`'s log), following that same convention rather than inventing
  a new one.
- **Schema**: `schema.sql`, two tables — `sessions` (one row per top-level session) and
  `subagent_tasks` (one row per subagent). Both are **upserted, not appended**: the source data
  (Claude Code's `statusLine`/`subagentStatusLine`) reports cumulative totals on every firing, not
  per-turn deltas, so each row is a snapshot overwritten in place, keyed by identity
  (`(tool, session_id)` / `(tool, parent_session_id, task_id)`). Every tool-specific column
  (`total_cost_usd`, `credits`, etc.) is nullable, since no single tool populates all of them.
- **Pricing**: `pricing.json` — model → $/M-token rates, used only to estimate subagent $ cost
  (Claude Code's main session already reports `cost.total_cost_usd` itself; subagents only report a
  combined `tokenCount`, so `estimated_cost_usd` is a blended-rate approximation, not an exact
  figure — see the comment in `lib.sh`'s `usage_estimate_cost`). Verified against the `claude-api`
  skill's cached pricing table on 2026-09-25 — re-verify before trusting old entries; prices change.

## Claude Code integration

Wired in `etc/claude-code/settings.json` via the `statusLine`/`subagentStatusLine` settings (see
[code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline)) — **not** hooks;
Claude Code's hook payloads carry no token/cost data at all (confirmed via
`anthropics/claude-code#91767`, an open, unaddressed feature request). Both scripts read a JSON
payload on stdin and write to the DB as a side effect:

- `claude-statusline.sh` — the main session. Prints the visible status line text
  (model/cost/context%/effort) and upserts the `sessions` row.
- `claude-subagent-statusline.sh` — per-subagent rows. Emits no stdout at all, so Claude Code keeps
  its default subagent-row rendering; this script's only job is the `subagent_tasks` upsert.

## Why Kiro CLI isn't wired up

Empirically confirmed, not assumed: kiro-cli's own hook system (`agentSpawn`/`preToolUse`/
`postToolUse`/`userPromptSubmit`/`stop`) carries **no token, credit, model, or cost data in any
payload** — verified by registering a temporary probe agent and inspecting the raw JSON each hook
received (only `hook_event_name`, `cwd`, `session_id`, and event-specific text fields showed up,
even on `stop`). Kiro also has no local usage file, no CLI subcommand (`kiro-cli --help-all` has
none), and no local DB with usage data (`~/.kiro/sessions/dashboard-search.db` is just an FTS5
search index over session titles/prompts). The only place Kiro's usage data exists is its cloud,
admin-only enterprise dashboard.

This means Kiro CLI currently cannot be captured locally at all — not a design gap to build around,
a real capability gap on Kiro's side. If Kiro ever exposes this differently (a real usage command, a
hook payload field, a local file), the schema already has a slot: `tool = 'kiro-cli'` rows with the
`credits` column populated and `total_cost_usd`/token columns left null, mirroring how `sessions`
already tolerates per-tool nulls. No code changes should be needed beyond a new `kiro-*.sh`
ingestion script — don't re-run the hook probe or re-derive this from scratch; check this file
first.

## Deliberately out of scope (for now)

- **No reporting/query layer.** This is the data store only. A `dotfiles cost`-style CLI, or
  anything reading this DB, is a separate future step.
- **No EAV/fully-generic metric schema.** Considered and rejected in favor of nullable typed columns
  plus a `raw_json` escape hatch — simpler to query at this scale (two known tools), and adding a
  column later is a one-line migration, not a rewrite.
