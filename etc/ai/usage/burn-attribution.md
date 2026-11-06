# Burn attribution: findings, method, and open items

Findings from the 2026-11-06 analysis of Claude Code usage data, written so the analysis can be
continued on another machine. Covers what was measured, how, what was decided, and what is still
open. The estimator itself is described in `README.md` in this directory.

Snapshot as of 2026-11-06 on the work machine (enterprise billing). Counts are for that machine's
local data only.

## Data sources and what each one can answer

- **`usage.db` `cost_snapshots`** (primary estimator source): one row per statusline firing where
  `total_cost_usd` changed. `raw_json` holds the payload, including `context_window.current_usage`,
  which is the usage of the last API call only. Calls between firings are not recorded.
- **`usage.db` `sessions`**: one row per session. `total_cost_usd` is the authoritative session
  total. `raw_json` holds the last payload, including `prompt_cache`.
- **`usage.db` `subagent_tasks`**: one row per subagent task. `estimated_cost_usd` comes from a
  single token count (no input/output split), so it is an estimate.
- **`usage.db` `compaction_events`**: PreCompact and PostCompact hook events. Token fields are
  sparse (see Q7).
- **Transcripts** (`~/.claude/projects/<project>/<session>.jsonl`, plus `subagents/` files): one
  record per streamed block. Each request has a `requestId`; several records can share one.
  Transcripts are subject to `cleanupPeriodDays`, so they are a cross-check, not the primary source.
- **`cost-state` record** in transcripts: Claude Code's own per-model totals. Also subject to
  retention.

Payload rate-limit data (`rate_limits`) is present only on subscription machines. Enterprise billing
machines never have it, so `rate_limit_snapshots` stays empty there.

## Method

**Transcript pricing:** group assistant records by `requestId`, keep the first record that has
`message.usage`, and price each request with `pricing.json` rules:

- Cache writes split into 5m and 1h using `cache_creation.ephemeral_*` (fall back to
  `cache_creation_input_tokens` as 5m when the breakdown is absent).
- Cache reads at `cache_read_multiplier`; for Sonnet 5.5 and Sonnet 5, use the pre-version
  multiplier when the Claude Code version is below 2.1.296.
- Haiku 5.5 tier: a request whose prompt (input + cache writes + cache reads) is over 100K tokens
  uses the `long_context` rates for the whole request.
- Include subagent files under `subagents/`.

**Turns:** a turn starts at a user record with `turnPosition` and `origin.kind` = human. A turn with
at least one assistant response counts as a turn. Peer-origin turns are counted and flagged. Turns
with no response, and turns with no `end_turn`, are reported separately. Records with `isMeta` are
not turn starts.

**Ratios:** estimate ÷ `total_cost_usd`. A "band" is 0.85 to 1.15.

## Turn-level findings

Survey across 109 sessions with transcripts: 1,303 turn starts, 1,274 with a response, 1,308
distinct `end_turn` messages. 10 to 12 sessions have no `turnPosition` and are excluded from turn
statistics. Their non-meta prompt counts do not match end-of-turn counts (for example, one session
has 12 prompts and 11 ends), so no fallback is used.

### Cost per turn, pooled (1,274 turns, 96 sessions, $85.19 priced)

| Turn bucket | Turns | Mean USD | Median | P90   | Share of cost |
| ----------- | ----- | -------- | ------ | ----- | ------------- |
| 1           | 95    | 0.120    | 0.022  | 0.329 | 13.3%         |
| 2–5         | 258   | 0.075    | 0.022  | 0.164 | 22.6%         |
| 6–10        | 241   | 0.088    | 0.049  | 0.214 | 24.8%         |
| 11–20       | 270   | 0.065    | 0.032  | 0.160 | 20.6%         |
| 21–40       | 220   | 0.043    | 0.031  | 0.093 | 11.1%         |
| 41+         | 190   | 0.034    | 0.027  | 0.068 | 7.6%          |

The pooled mean falls with turn number. Long sessions contribute many late turns, and late turns are
short, so this is largely a composition effect.

### Within-session trend (58 sessions with at least 5 turns; 44 with at least 10)

Per-session Spearman ρ of each measure against turn index (median across sessions):

| Measure                 | ≥5 turns: median ρ | ρ > 0    | ≥10 turns: median ρ | ρ > 0    |
| ----------------------- | ------------------ | -------- | ------------------- | -------- |
| Cost per request        | +0.29              | 40 of 58 | +0.29               | 30 of 44 |
| Cache reads per request | +0.83              | 51 of 58 | +0.49               | 37 of 44 |
| Peak prompt per request | +1.00              | 50 of 58 | +0.54               | 36 of 44 |
| Requests per turn       | −0.21              | 12 of 58 | −0.16               | 11 of 44 |

Reading: within a session, context grows (prompt size and cache reads per request rise). Turns carry
fewer requests later, which offsets the growth, so cost per turn is roughly flat. Cost per turn does
not have a robust sign across sessions. Caveats: model switches are not controlled, and compaction
is not removed from the sample.

## Model and effort mix (Q4)

Transcript pricing across all 117 transcript sets, distinct requests, main and subagent files: total
$119.54 across 6,914 request lines.

| Model             | Thread   | Requests | USD   | Share |
| ----------------- | -------- | -------- | ----- | ----- |
| claude-haiku-5-5  | main     | 4,832    | 42.33 | 35.4% |
| claude-sonnet-5   | main     | 687      | 40.20 | 33.6% |
| claude-sonnet-5-5 | main     | 843      | 32.38 | 27.1% |
| claude-sonnet-5   | subagent | 34       | 1.80  | 1.5%  |
| claude-haiku-5-5  | subagent | 389      | 1.44  | 1.2%  |
| claude-haiku-4-5  | subagent | 120      | 1.03  | 0.9%  |
| other             |          | 9        | 0.19  | 0.2%  |

- By effort: medium 70.7% of spend, high 28.3%, unset 1.0%.
- Model and effort are confounded: every `high` request is `claude-sonnet-5`.
- Haiku and Sonnet 5.5 requests carry an `advisorModel` field (Opus 5.5). That usage is not
  separately priced here.

Session-level cross-check (usage.db, 128 claude-code sessions, $183.60): Sonnet 5 `high` 38.9%,
Haiku 5.5 medium 29.0%, Sonnet 5.5 medium 21.7%, Sonnet 5 medium 10.3%.

## Subagent share (Q5)

- Transcript pricing: subagent requests are $4.6 of $119.54 (3.8%).
- `isSidechain` is true on every assistant record in a 40-file sample of subagent transcripts, and
  false on main-thread records.
- usage.db `subagent_tasks`: 74 tasks in 24 parent sessions, `estimated_cost_usd` total $13.93 (7.6%
  of $183.60). Not reconciled with transcript pricing: the Sonnet subagent estimate is $10.71
  against $1.80 from transcripts. Treat the usage.db figure as an unreconciled estimate.
- Adding subagent transcripts to the 21 sessions that have them moves the median transcript/actual
  ratio from 0.78 to 0.83, and the count within the band from 2 to 7. The signal is weak (subagents
  are about 5% of a session's cost), but it supports `total_cost_usd` including subagent cost. Not
  proven.

## Cache misses (Q6)

From the last `prompt_cache` payload in 113 of 128 claude-code sessions. TTL is `1h` on the rows
checked.

| Model             | Sessions | Requests | Misses | Miss rate | Sessions with a miss | Rebuilt tokens |
| ----------------- | -------- | -------- | ------ | --------- | -------------------- | -------------- |
| claude-haiku-5-5  | 77       | 4,707    | 30     | 0.64%     | 19                   | 3.20M          |
| claude-sonnet-5   | 19       | 1,111    | 5      | 0.45%     | 4                    | 0.46M          |
| claude-sonnet-5-5 | 16       | 843      | 2      | 0.24%     | 2                    | 0.24M          |

- Rebuild cost (rebuilt tokens × (1h write rate − read rate)): about $3.3 at base Haiku rates, $5.7
  with the Haiku over-100K tier, against $183.60 total (1.8% to 3.1%).
- `recache_tokens_if_cold` (8.7M Haiku, 2.8M Sonnet 5, 1.7M Sonnet 5.5) is counterfactual exposure,
  not realized cost. It is not added to any cost figure.
- Miss causes are unlabelled for 20 of the 25 sessions with a miss. Labelled causes:
  `ttl_expired_1h` (4 sessions), `messages_rewritten` (1), `effort_changed` (1).

## Compaction cost (Q7)

- 48 PreCompact and 46 PostCompact events, all `auto`, in 30 of 128 sessions. Haiku 5.5 in 18
  sessions, Sonnet 5 in 6, Sonnet 5.5 in 6. Those sessions total $105.69 of $183.66.
- Token fields: `real_pre_tokens` is set on 15 of 46 PostCompact rows (mean 199K before, 29K after).
  PreCompact rows carry no token fields.
- Summarization-call cost is not logged. Bound: per-token input pricing gives roughly $0.01 to $0.40
  per event, or about $0.50 to $8 across 46 events (0.3% to 4.5% of total). Estimate only.
- `cumulative_dropped_tokens` totals 5.6M. Compaction shrinks later prompts, which lowers later
  cache reads. The saving is not quantified.
- Summary records and events: 54 compact-summary records (34 transcript files) against 46 events. 45
  summaries pair with 45 events in time (44 within 60 seconds). The other 9 summaries sit in five
  sessions with no event, four of which predate the first event row (hook logging started late). One
  event has no summary record. One post-hook-start event is missing for a single session.

## Estimator validation

### Haiku 5.5 long-context tier

Official rates (pricing page, fetched 2026-11-06): at or under 100K prompt tokens, input $0.10,
output $0.50, cache read $0.01, cache write $0.125 (5m) / $0.20 (1h). Over 100K: input $0.50, output
$2.50, cache read $0.05, cache write $0.625 (5m) / $1.00 (1h). The prompt length counts input, cache
reads, and cache writes. Haiku 5.5 is the only model the pricing page names with a prompt-length
tier.

Result across 75 Haiku sessions with cost: mean ratio 0.52 → 0.86 with the tier. Within the band: 24
→ 35.

Alternatives tested on 77 Haiku sessions with transcripts (median ratio; count within band):

| Tier rule                                                                   | Median | Within band |
| --------------------------------------------------------------------------- | ------ | ----------- |
| Whole request over 100K, using input + cache writes + cache reads (shipped) | 0.85   | 37 of 77    |
| Input only                                                                  | 0.32   | 20 of 77    |
| Input + cache reads                                                         | 0.83   | 26 of 77    |
| Marginal (tier only on tokens above 100K)                                   | 0.44   | 21 of 77    |

The shipped rule is best across the population.

### Duplicate counting

Usage tuples repeat in every Haiku session with snapshots. Repeats are the same API call
re-reported: no usage tuple is shared by two distinct `requestId`s across 109 sessions. Deduping
makes the estimate worse (it moves 44 of 46 affected sessions farther from `total_cost_usd`).
Rejected. No estimator change.

### Coverage

Snapshots capture about 79% of transcript output tokens (pooled over 104 sessions). Calls between
firings are missed, so the raw snapshot estimate undercounts. Repeats partly offset that.

### Transcript pricing does not close the gap

Transcript-based pricing (distinct `requestId`s, subagent files, 5m/1h split, version rule, tier)
gives mean ratio 0.852, against 0.845 for the snapshot estimator. It is not a basis for rewriting
the estimator. The snapshot estimator stays primary.

### Sonnet 5.5 residual

Post-2.1.296 Sonnet 5.5 sessions sit at 0.78 to 0.86 under both snapshot and transcript pricing. The
residual is general under-capture, not version- or tier-specific. No change.

Three Sonnet 5 sessions show snapshot ratios far below transcript ratios: one has a single snapshot
(ratio 0.01 vs 0.70 from transcripts), another has one snapshot (0.02 vs 0.78), and a third has 76
snapshots over roughly 300K-token contexts (0.26 vs 0.87). The snapshot path misses calls between
firings; transcript pricing recovers most of the spend.

### Open outliers

- Session 605bf8c9: transcript estimate 2.38× actual under the shipped rule. It fits a marginal tier
  rule (0.99), but that rule fails across the population. Left as a documented outlier.
- Session 492a3eb3: below 0.35 under every tier variant tested, so the tier is not its cause. Cause
  unknown.
- Session f4f9eae5: the transcript's `cost-state` record exceeds the assistant records by about 125K
  cache-read tokens. Side calls (unrecorded billed requests) do not explain the general gap: 46 of
  49 sessions without an extra `api-request` still show an output gap. Cause unknown.

## Retention

- `cleanupPeriodDays: 90` is set in the user settings on the work machine. No managed-settings file
  was found at the standard macOS path; other managed sources were not checked.
- 105 transcripts are older than 30 days; none is older than 90 days yet; the oldest is 74 days old
  (2026-11-06).
- The Claude Code default is 30 days, by file modification time. Official docs confirm this.
- Do not set `cleanupPeriodDays` to 0. A reported issue says it stops transcript writes.

## Rate limits (personal machine only; not yet validated)

The validation question: does the five-hour or seven-day used percentage move in proportion to
transcript spend? This needs `rate_limit_snapshots` from a subscription machine.

Status as of 2026-11-06 on the personal machine: not validated, because there is not enough data.
`rate_limit_snapshots` holds 3 rows. The five-hour window moved from 1% to 3% over about 21 minutes;
the seven-day window stayed at 3%. That leaves one window with a change, and too few points at whole-
percent resolution for a fit. The retention and `resets_at` checks pass. `cleanupPeriodDays` is 90 in
user settings, no transcripts are older than 30 days, and both reset epochs decode to plausible times.

Rerun the runbook once both windows have several snapshots over a period with meaningful spend. The
seven-day window needs to move too.

Runbook (run on the machine that has rate-limit data):

1. Retention: check `cleanupPeriodDays`, managed settings, and the ages of transcript files.
1. Snapshot sanity check: `resets_at` values are epoch seconds, and percentages rise monotonically
   within each window.
1. Group snapshots by window (`five_hour_resets_at`, `seven_day_resets_at`). Take the change in
   percentage from the first to the last snapshot of each window.
1. For the same time interval, sum transcript spend over distinct `requestId`s (method above).
1. Compare percentage change with spend change per window. A roughly linear relationship means the
   percentage tracks spend. Report the fit and the windows that do not match.
1. The snapshot table has no `session_id`. Per-session attribution can only split a window's spend
   by session. It cannot read sessions out of the percentage.

## Open items

- Rate-limit validation (above). Needs more snapshots across both windows.
- Outliers 605bf8c9, 492a3eb3, and f4f9eae5 (above).
- Usage.db `subagent_tasks` estimate does not reconcile with transcripts.
- Whether `total_cost_usd` fully includes subagent cost (weak support, not proven).
- Advisor-model usage: not found in transcripts as separate priced requests. Sessions with advisor
  requests run at the same ratio as sessions without (1.18 vs 1.17), so it is not a large unrecorded
  cost. Not proven either way.
- Interrupt-marker check (rerun): user records containing "Request interrupted" appear 13 times
  across 10 of 35 short sessions. Of 69 unclosed turns in those sessions, 63 are followed by a new
  prompt. At most 13 of the 69 are interrupts, so unclosed turns are not treated as interrupted.

## Decisions

- Estimator source: usage.db `cost_snapshots`. Transcripts and `cost-state` are cross-checks only
  because of retention.
- No estimator change from this analysis. Any change needs a plan and review first.
- Turn convention: as above (turn start = human-origin `turnPosition`; responded turns counted; peer
  turns flagged).
