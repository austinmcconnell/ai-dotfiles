# AI Usage/Cost Tracking

Local, durable tracking of token usage and estimated $ cost across AI coding tools, stored outside
engram in a SQLite database that isn't committed to git. Tool-agnostic by design, but only Claude
Code is wired up today — see "Why Kiro CLI isn't wired up" below.

## Storage

- **DB**: `~/.local/share/ai-usage/usage.db` — sibling to the existing `~/.local/share/ai-audit/`
  directory (`audit-shell-commands.sh`'s log), following that same convention rather than inventing
  a new one.
- **Schema**: `schema.sql`. `sessions` (one row per top-level session) and `subagent_tasks` (one row
  per subagent) are **upserted, not appended**: the source data (Claude Code's
  `statusLine`/`subagentStatusLine`) reports cumulative totals on every firing, not per-turn deltas,
  so each row is a snapshot overwritten in place, keyed by identity (`(tool, session_id)` /
  `(tool, parent_session_id, task_id)`). Every tool-specific column (`total_cost_usd`, `credits`,
  etc.) is nullable, since no single tool populates all of them. `compaction_events` and
  `cost_snapshots` (see "Cost trajectory" below) are the deliberate exceptions — both append-only,
  since `sessions`' upsert-in-place would otherwise overwrite the one history they exist to
  preserve.
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
  (model/cost/context%/effort), upserts the `sessions` row, and appends a `cost_snapshots` row (see
  "Cost trajectory" below).
- `claude-subagent-statusline.sh` — per-subagent rows. Emits no stdout at all, so Claude Code keeps
  its default subagent-row rendering; this script's only job is the `subagent_tasks` upsert.

## Compaction tracking: `compaction_events`

Claude Code's `PreCompact`/`PostCompact` hook payloads carry **no token data at all** (confirmed via
`anthropics/claude-code#91767`) — the one structural exception to this doc's "not hooks" framing
above, since `compaction_events` is the only table populated from hooks rather than the statusline.
`log-compaction-event.sh` is wired to both events in `etc/claude-code/settings.json` and works
around the missing payload data two different ways:

- **`snapshot_input_tokens`** (both events): an approximation — the session's last-known
  `sessions.input_tokens` at the moment the hook fires, not an exact figure from the compaction
  itself.
- **`real_pre_tokens`/`real_post_tokens`/`cumulative_dropped_tokens`/`duration_ms`** (`PostCompact`
  only): exact figures. Claude Code writes a `compact_boundary` system message with a
  `compactMetadata` object into the session's transcript once compaction finishes, and the hook
  payload's `transcript_path` (which every hook payload *does* carry) can be read to extract it.
  That record doesn't exist yet at `PreCompact` time, so these stay `NULL` on `PreCompact` rows.
  Verified against the approximation on a real compaction: the approximation was off by up to 5.8x
  in one direction, which is why the real columns exist rather than trusting the snapshot alone.

**Empirical finding worth preserving**: the real compaction trigger point is a fraction of the
configured `autoCompactWindow`, not a fixed token floor — but that fraction isn't flat either. Four
real compactions: 100K configured → 48.5% (twice), 200K → 55.1%, 600K → 57.5%. The ratio rises with
window size; neither a fixed percentage nor a fixed reserved-token buffer fits the data cleanly.
`etc/ai/hooks/suggest-context-checkpoint.sh` (a `UserPromptSubmit` hook) reads this table's sibling
data (`sessions.input_tokens`) to nudge at a fixed absolute threshold rather than trying to derive
one from this still-uncertain ratio.

## Cost trajectory: `cost_snapshots`

`sessions` only ever holds the latest snapshot — once a session ends, there's no way to see how its
cost/tokens grew over its lifetime, only the final number. `cost_snapshots` fixes that: an
append-only row per statusline firing, but only when `total_cost_usd` has actually changed since
this session's last recorded snapshot — skips true no-op re-renders while keeping every real
cost-changing step, so a session's trajectory survives past `sessions`' own upsert.

The cost-changed check runs entirely in SQL (`INSERT ... SELECT ... WHERE (subquery) IS NOT :cost`),
not bash string comparison — SQLite's text rendering of a REAL (e.g. `1.0`) doesn't always
string-match jq's rendering of the same number (e.g. `1.00`), which would false-negative a bash `!=`
compare and insert a duplicate row on every firing.

This exists to support future cost analysis (e.g. "does cost per turn climb as a session grows"),
not to attribute cost by tool type — Claude Code's statusline only ever reports cumulative session
totals, never a per-tool-call breakdown, so that finer-grained attribution isn't derivable from any
data this repo has access to.

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

- **No EAV/fully-generic metric schema.** Considered and rejected in favor of nullable typed columns
  plus a `raw_json` escape hatch — simpler to query at this scale (two known tools), and adding a
  column later is a one-line migration, not a rewrite.

## Reporting: `bin/ai-usage`

`bin/ai-usage` (`--summary`/`--by-model`/`--by-effort`) is a read-only canned-report CLI over this
DB. All three views aggregate `sessions.total_cost_usd` alone — never add
`subagent_tasks.estimated_cost_usd` on top of it. See "Does session cost already include subagent
spend?" below for why; `subagent_tasks` is surfaced only as a separate, known-partial informational
breakdown.

### Does session cost already include subagent spend?

**Yes — verified against official docs, 2026-09-25.** Claude Code's own `total_cost_usd` (the same
figure the statusLine's `cost.total_cost_usd` reports) already counts subagent/Task-tool spend
alongside the top-level loop:

- [`code.claude.com/docs/en/agent-sdk/cost-tracking`](https://code.claude.com/docs/en/agent-sdk/cost-tracking)
  gives an explicit table of what each result-level field counts when subagents run.
  `total_cost_usd` (and `modelUsage`/`model_usage`) is marked **"Included. Counts subagent requests
  alongside the top-level loop."** Only the separate `usage` field excludes subagents (main loop
  only).
- [`code.claude.com/docs/en/costs`](https://code.claude.com/docs/en/costs) confirms the statusLine's
  cost field is the *same* number as the `/usage` Session block's `Total cost` line ("The same total
  appears in the status line's cost field").
- The one documented subagent exclusion on the *statusline* page is a different, unrelated field —
  the `prompt_cache` object ("Claude Code doesn't count subagent requests in these statistics") —
  not `cost.total_cost_usd`. Don't conflate the two; this was the trap that made the question worth
  verifying explicitly rather than assuming from that one caveat.

**Consequence for every aggregate query**: sum `sessions.total_cost_usd` alone for a "total cost"
view. Summing it with `subagent_tasks.estimated_cost_usd` double-counts — the latter is already
folded into the former. `subagent_tasks` remains useful only as a separate, informational,
known-partial breakdown (see the visibility-window gap above), never as an addend.
