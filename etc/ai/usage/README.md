# AI Usage/Cost Tracking

Local, durable tracking of token usage and estimated $ cost across AI coding tools, stored outside
engram in a SQLite database that isn't committed to git. Tool-agnostic by design, but only Claude
Code is wired up today — see "Why Kiro CLI isn't wired up" below. For the cost-estimate method,
validation, and decisions, read `cost-estimation.md` in this directory.

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
- **Migrations**: see "Schema migrations" below.
- **Pricing**: `pricing.json` — model → $/M-token rates, used only to estimate subagent $ cost.
  Claude Code's main session already reports `cost.total_cost_usd` itself, while a subagent payload
  carries only a combined `tokenCount` that cannot be split into input and output. So
  `subagent_tasks.estimated_cost_usd` is priced from the subagent's own transcript by
  `usage_transcript_cost` in `lib.sh`: one final record per `requestId`, with the long-context and
  cache-read rules from `pricing.json`. A request whose usage has a non-empty `iterations` array is
  priced pass by pass, each at its own model, so a subagent's advisor calls are included and each
  pass's own cache-write split is used (the top-level split covers only the first pass). Tiering per
  pass is inferred, not verified on a multi-pass record. It is NULL while the transcript is missing,
  any request is unpriced, or an iteration has an unknown type. A stored cost never decreases — a
  later firing that cannot read the transcript, or that reads fewer records than an earlier one,
  leaves the higher value in place — so the figure does not depend on which firing happens to land
  after the subagent's final transcript record. Tests: `test/test-subagent-cost.sh`. Verified
  against the `claude-api` skill's cached pricing table on 2026-09-25 — re-verify before trusting
  old entries; prices change.

## Schema migrations

`PRAGMA user_version` holds the DB's schema version, and `migrations/NNNN-<slug>.sql` takes a DB
from version `NNNN - 1` to `NNNN`. `usage_db_init` in `lib.sh` runs on every statusline render. It
reads the version once and returns at once when the DB is current. Otherwise:

- **A new DB** gets `schema.sql`, which is always the newest schema, and jumps straight to the
  newest version.
- **A DB from before versioning** (version 0 with tables) is adopted as version 1 by
  `migrations/0001-baseline.sql`, plus whichever `compaction_events` columns it lacks. The baseline
  is frozen: never edit it. Adopting from `schema.sql` instead would give the DB a newer shape that
  later migrations collide with.
- **An older DB** runs each later migration in order. Each one and its version bump share one
  `BEGIN IMMEDIATE` transaction, guarded on the starting version. A failure rolls back and leaves
  the version unchanged. When several sessions race, exactly one applies the migration and the rest
  see the new version and succeed.
- **A DB newer than the checkout's migrations** is left alone.

To change the schema, edit `schema.sql` and add the next-numbered migration that brings an existing
DB to the same shape, in one commit. `test/test-migrations.sh` (a pre-commit hook) checks that a new
DB and a migrated one end up with the same columns. Rules for a migration file:

- **No transaction control or dot-commands.** No `BEGIN`, `COMMIT`, `PRAGMA journal_mode`, or
  `.`-commands. The runner wraps the file in its own transaction, and any of these would break that
  wrapping.
- **Keep it fast.** Other writers block for up to the 5 s busy timeout (`USAGE_DB_BUSY_TIMEOUT_MS`)
  before failing. The statusline scripts wait only 200 ms, then skip that firing's capture so a
  render never stalls, so a slow migration also loses snapshots. Run a rebuild of a large table,
  such as `cost_snapshots`, as an explicit one-off command rather than as a migration.
- **Rely on named columns.** `ALTER TABLE ... ADD COLUMN` appends, so a migrated DB's column order
  can differ from a new one's. Every `INSERT` names its columns, and new ones must too.

The live DB follows whatever checkout the statusline runs from. Checking out a branch that adds a
migration upgrades `usage.db` on the next render, and switching back leaves the DB at the newer
version, which older code ignores. Since migrations only add, rolling back means undoing the
migration's change by hand and then setting `PRAGMA user_version` to the earlier number.

`0002-subagent-name-from-description.sql` is the exception: it rewrites `subagent_tasks.name` in
place, so there is nothing to drop. The old activity label survives in each row's `raw_json`
(`tasks[].label`). A row whose `raw_json` holds no text description keeps its old name, so `name`
can still hold an activity label on rows written before the writer changed. An older checkout's
writer puts labels back into `name` on every firing, and nothing re-runs the backfill.

## Claude Code integration

Wired in `etc/claude-code/settings.json` via the `statusLine`/`subagentStatusLine` settings (see
[code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline)) — **not** hooks;
Claude Code's hook payloads carry no token/cost data at all (confirmed via
`anthropics/claude-code#91767`, an open, unaddressed feature request). Both scripts read a JSON
payload on stdin and write to the DB as a side effect:

- `claude-statusline.sh` — the main session. Prints the visible status line text
  (model/usage/context%/effort), upserts the `sessions` row, and appends a `cost_snapshots` row (see
  "Cost trajectory" below). Usage is the 5h and 7d rate-limit percentages with time to reset on a
  claude.ai subscription, and session cost otherwise. On Enterprise, a usage segment
  (`usage 27% (15d 12h) -21`) follows the cost, from the usage cache in `~/.claude.json`. The 7d
  segment ends with a pace delta: the points its usage sits above (`+`) or below (`-`) an even burn
  across the fixed 7-day window, e.g. `7d 12% (6d 5h) +1`. The segment turns yellow at +10, red at
  +20, and green at -15 or lower (room to use more before the reset). `test/test-statusline.sh`
  covers the rendering.

  The Enterprise usage segment reads the `extra_usage` block of the usage cache in `~/.claude.json`
  (`CLAUDE_CONFIG_DIR` is honoured). That cache refreshes when `/usage` runs, not on every turn, so
  the figure can lag real spend. The segment is hidden when the cache predates the current month.
  The reset date is not in the cache, so the window is assumed to be the calendar month in
  America/Chicago, starting on the 1st. Check that against the reset date in the `/usage` panel.
  Anthropic doesn't document the cache's fields, so the segment disappears rather than breaking the
  line if they change.

- `claude-subagent-statusline.sh` — per-subagent rows. Emits no stdout at all, so Claude Code keeps
  its default subagent-row rendering; this script's only job is the `subagent_tasks` upsert. `name`
  holds the launch description from the payload's `description` field, not `label`, which tracks the
  subagent's live activity. A firing without a description leaves the stored name alone.

## Repairing `subagent_tasks` rows

Two maintenance scripts fix historical rows. Both default to a dry run, print before/after per row,
and need `--apply` to write; `--apply` backs the DB up first and refuses to run if that backup path
already exists.

Rows written before the column-shift fix have their columns off by one. They are identifiable by a
non-NULL `effort`, which the current writer never sets. `repair-subagent-tasks.sh` rebuilds those
columns from the row's stored `raw_json` and clears `estimated_cost_usd`, because cost now comes
from the transcript rather than from any column it could recompute.

`backfill-subagent-cost.sh` then reprices every row from its own subagent transcript. A row whose
transcript is missing or not fully priceable is cleared to NULL rather than left holding a figure
from the superseded blended-rate estimator, so expect rows whose transcripts have aged out of
retention to lose their value rather than keep a wrong one.

Run them in that order, each as a dry run first:

```bash
./repair-subagent-tasks.sh            # review
./repair-subagent-tasks.sh --apply
./backfill-subagent-cost.sh           # review
./backfill-subagent-cost.sh --apply
```

Afterwards no row should have a non-NULL `effort`. Both scripts are idempotent. Each waits up to 5
seconds for a lock held by a statusline write. If the lock outlasts that, `--apply` fails with
nothing written, and a re-run is safe.

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
  only): exact figures, but not from the hook. Claude Code writes a `compact_boundary` system
  message with a `compactMetadata` object into the session's transcript once compaction finishes,
  and that is after the `PostCompact` hook has returned, so the hook inserts these `NULL` and the
  resolver below fills them. They stay `NULL` on `PreCompact` rows. Verified against the
  approximation on a real compaction: the approximation was off by up to 5.8x in one direction,
  which is why the real columns exist rather than trusting the snapshot alone.
- **`raw_json._diag.hook_started_at`** (`PostCompact` only): the payload plus the millisecond ISO
  timestamp of the hook firing, the only sub-second time recorded for the event. Compare it with a
  boundary's `timestamp` to see how long after the hook the transcript write landed.

The hook always exits 0, including when the DB is locked or unwritable, and its SQLite waits are
short (300 ms for the version check, 400 ms each for the snapshot read and the insert) so they fit
inside the hook's 5 s limit.

**Resolving the real columns**: Claude Code writes the `compact_boundary` record after the
`PostCompact` hook runs, so a row's own boundary is never on disk when the hook fires.
`usage_resolve_compaction_boundaries <session-id>` in `lib.sh` reads the boundaries from the
session's main transcript and its `subagents/*.jsonl` (a subagent's compaction fires the hook with
the main session's id and transcript path) and pairs them with the session's `PostCompact` rows by
time: a row and a boundary pair only when each is the other's single candidate within 5 seconds.
Rows with two candidates are ambiguous and stay untouched. A session whose transcripts cannot all be
read, or whose last line is a half-written boundary, is skipped whole. The pairing and the write
happen in one `BEGIN IMMEDIATE` transaction, after the files are read.

The statusline runs it for you: after printing, `claude-statusline.sh` checks for a `PostCompact`
row of the current session from the last 10 minutes with `real_pre_tokens` still `NULL`, and if one
exists starts `resolve-compaction-boundaries.sh --live <session-id>` detached (`perl`'s
`POSIX::setsid`, since macOS has no `setsid` binary). That mode only fills `NULL` rows and never
overwrites or clears. A per-session lock directory under `$USAGE_DB_DIR/resolve-locks/` limits it to
one start per 2 minutes; the lock is never removed, it just ages out, so a row that never pairs
costs about five scans in its 10-minute window. A session that never renders a statusline (headless
`claude -p`, the SDK, a session closed right after compacting) keeps `NULL` until the script is run
by hand.

`resolve-compaction-boundaries.sh [--apply] [session-id]` runs it by hand. The default is a dry run
that prints `class|row|before|after` for every row (`fill`, `correct`, `same`, `ambiguous`,
`neighbour`, `unmatched`) and a `summary|rows|boundaries|paired` line per session; `--apply` backs
the DB up first, and only when something would change. Besides filling empty rows it replaces a
wrong value, and it clears a row only when that row has no candidate boundary and holds another
boundary's `preTokens`, which marks it as a neighbour's value. Any other stored value is kept and
listed as `unmatched`.

**Empirical finding worth preserving**: with no `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` set,
auto-compaction fires a roughly constant ~35K tokens below the configured `autoCompactWindow`, not
at a fixed fraction of it. A 150K window compacted at ~115.5K (five compactions) and a 250K window
at ~215K (three), both measured on Haiku; the reserve is not confirmed for other models.

- **Measuring the trigger**: the check runs on the last API response's usage, so the trigger lies
  between the last turn that did not compact and the turn that did. Read those per-turn `usage`
  totals from the transcript. `real_pre_tokens` is not the trigger point: it also counts tool
  results that arrived after the check and overshot by 2-3K in these runs.
- **With the override set**: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=60` moved the trigger to about 60% of
  the window minus ~13K. Earlier observations that looked like a ratio rising from 48.5% to 57.5% of
  the window (100K to 600K) fit that formula and were an artifact of the override.

`etc/ai/hooks/suggest-context-checkpoint.sh` (a `UserPromptSubmit` hook) reads this table's sibling
data (`sessions.input_tokens`) and nudges 15K tokens before the trigger, derived from the configured
`autoCompactWindow` minus the ~35K reserve.

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

## Rate-limit trajectory: `rate_limit_snapshots`

Same append-only-on-change idea as `cost_snapshots`, but deliberately **no `session_id`**.
`rate_limits` (`five_hour`/`seven_day` `used_percentage`/`resets_at`) is an account-wide figure, not
a per-session one — every concurrently open session's statusline reports the identical percentage.
Keying rows by `session_id` the way `cost_snapshots` does would duplicate one real-world change once
per concurrently open session rather than attributing distinct usage to each, so the table instead
has one global timeline: a row is appended only when `five_hour_used_percentage` or
`seven_day_used_percentage` has changed since the table's last row (the same SQL `IS NOT` dedup
`cost_snapshots` uses, `OR`-ed across both columns since either can change independently). Only
fires when `rate_limits` is present in the payload at all (claude.ai Pro/Max/Ultra subscribers — see
"Display decision" below); absent for Enterprise/API.

Because the dedup check and insert aren't one atomic SQL statement across every writer, two sessions
racing a near-simultaneous rate-limit change can both pass the check and insert a duplicate row.
Accepted as harmless — same class of best-effort dedup as `cost_snapshots`, not worth adding
cross-process locking to close.

`bin/ai-usage --rate-limits` is the canned report over this table.

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

## Session-level cost estimator: `estimate-session-cost.sh`

`estimate-session-cost.sh <session_id-or-prefix>` is a **cross-check only, never authoritative**.
`sessions.total_cost_usd` stays the source of truth for every aggregate — this script exists to
sanity-check the pricing table and the capture pipeline against it, not to replace it.

It reprices each `cost_snapshots` row for the session from that row's `raw_json`, using
`context_window.current_usage.{input_tokens,output_tokens,cache_creation_input_tokens, cache_read_input_tokens}`
— the last-API-call-only usage — priced with `pricing.json` (the cache write multiplier is chosen
per row from that row's `prompt_cache.ttl`). It does **not** use the dedicated
`cost_snapshots.input_tokens`/`output_tokens` columns: those hold
`context_window.total_input_tokens`/`total_output_tokens`, which is the current context-window size,
not a per-call or cumulative billing figure — documented at
[code.claude.com/docs/en/statusline](https://code.claude.com/docs/en/statusline). Summing per-call
`current_usage` across all of a session's snapshots is valid because that field is never cumulative
— unlike `total_cost_usd`, it resets to the latest call's usage each time.

Prints the estimate, the actual `total_cost_usd`, their ratio, and flags the session when the ratio
falls outside roughly 0.85–1.15 — a sign the pricing table, cache multiplier, or capture assumptions
are off for that session's model.

Long-context pricing is per request: a model whose `pricing.json` entry has a `long_context` block
(Haiku 5.5 today) prices each request at the higher rates when its prompt, counting input, cache
reads, and cache writes, is over the threshold. The estimate can mix tiers within one session. This
estimator prices the last call's usage only, so unlike `usage_transcript_cost` it does not price
advisor passes or split a multi-pass request.

Cache-read rates are version-aware where a model's entry in `pricing.json` names a repricing
release: Sonnet 5.5 used 0.1x before Claude Code 2.1.296 and 0.05x from it. Each row uses the
`version` in its own payload, and a row without one falls back to the current rate. That differs
from `usage_transcript_cost` in `lib.sh`, which refuses to price such a request rather than pick a
side of the boundary; the two implementations of these rules are duplicated, not shared. Sonnet 5.5
sessions before 2.1.296 still estimate below actual, and Haiku 5.5 estimates run below `cost-state`
where requests cross the 100K-token tier — see "Cache-write rate check" in `cost-estimation.md`.

## Deliberately out of scope (for now)

- **No EAV/fully-generic metric schema.** Considered and rejected in favor of nullable typed columns
  plus a `raw_json` escape hatch — simpler to query at this scale (two known tools), and adding a
  column later is a one-statement migration (see "Schema migrations"), not a rewrite.

## Reporting

`bin/ai-usage` holds the canned reports (`--summary`, `--by-model`, `--by-effort`, `--subagents`,
`--rate-limits`); query the DB directly (e.g. with `sqlite3`) for anything else. `--subagents` shows
subagent launches by agent type, then the 20 most expensive launches by name, with unpriced launches
sorted last and counted separately. Any aggregate should sum `sessions.total_cost_usd` alone — never
add `subagent_tasks.estimated_cost_usd` on top of it. See "Does session cost already include
subagent spend?" below for why; `subagent_tasks` is useful only as a separate, informational
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
breakdown, never as an addend.
