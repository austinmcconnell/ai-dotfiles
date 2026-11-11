# Burn attribution: findings, method, and open items

Findings from the 2026-11-06 analysis of Claude Code usage data, written so the analysis can be
continued on another machine. Covers what was measured, how, what was decided, and what is still
open. The estimator itself is described in `README.md` in this directory.

Snapshot as of 2026-11-06 on the work machine. Counts are for that machine's local data only.

## Data sources and what each one can answer

- **`usage.db` `cost_snapshots`** (primary estimator source): one row per statusline firing where
  `total_cost_usd` changed. `raw_json` holds the payload, including `context_window.current_usage`,
  which is the usage of the last API call only. Calls between firings are not recorded.
- **`usage.db` `sessions`**: one row per session. `total_cost_usd` is the authoritative session
  total. `raw_json` holds the last payload, including `prompt_cache`.
- **`usage.db` `subagent_tasks`**: one row per subagent task. `estimated_cost_usd` is priced from
  each subagent's own transcript, one record per `requestId`. It is NULL when the transcript is
  missing or cannot be fully priced.
- **`usage.db` `compaction_events`**: PreCompact and PostCompact hook events. Token fields are
  sparse.
- **Transcripts** (`~/.claude/projects/<project>/<session>.jsonl`, plus `subagents/` files): one
  record per streamed block. Each request has a `requestId`; several records can share one.
  Transcripts are subject to `cleanupPeriodDays`, so they are a cross-check, not the primary source.
- **`cost-state` record** in transcripts: Claude Code's own per-model totals. Also subject to
  retention.

Payload rate-limit data (`rate_limits`) is present only on subscription machines. Enterprise billing
machines never have it, so `rate_limit_snapshots` stays empty there.

## Method

**Transcript pricing:** group assistant records by `requestId`, keep the last record that has
`message.usage`, and price each request with `pricing.json` rules:

- Cache writes split into 5m and 1h using `cache_creation.ephemeral_*` (fall back to
  `cache_creation_input_tokens` as 5m when the breakdown is absent).
- Cache reads at `cache_read_multiplier`; for Sonnet 5.5, use the pre-version multiplier when the
  Claude Code version is below 2.1.296.
- Haiku 5.5 tier: a request whose prompt (input + cache writes + cache reads) is over 100K tokens
  uses the `long_context` rates for the whole request.
- Include subagent files under `subagents/`.

Why one record per `requestId`: Claude Code's own `cost-state` token totals match this convention.
Across 161 sessions with `cost-state`, the output total matches within 1% in 60 sessions when
counted per `requestId`, and in one session when counted per record. In 30 short sessions where all
four token totals match, per-record cost is exactly twice the per-`requestId` cost (each request has
two records), and per-`requestId` cost is 0.91 of `cost-state`. Session 492a3eb3 does not fit either
convention; cause unknown.

**Ratios:** estimate ÷ `total_cost_usd`. A "band" is 0.85 to 1.15.

## Estimator validation

### Haiku 5.5 long-context tier

Rates and the 100K-token threshold are in `pricing.json`.

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

### Cache-write rate check

Across 30 sessions whose per-`requestId` token totals match `cost-state` in all four components, the
remaining cost gap is almost entirely 1h cache writes. The 1h write rate that closes the gap is
$0.222 to $0.228 per million tokens in the Haiku 5.5 sessions with more than 10K 1h write tokens,
against $0.20 published here. For Sonnet 5.5 (one session with 33K 1h write tokens) the implied rate
is $4.45, against $4.00 at 2× input. The gap is the same across Claude Code versions 2.1.285,
2.1.308, and 2.1.311, and is about 2.22× input rather than 2.0×.

The official prompt-caching page (checked 2026-11-06) gives 1h cache writes as 2× base input and 5m
writes as 1.25×, matching `pricing.json`, so the published rate is not the cause. The remaining gap
is unexplained: either `cost-state` bills 1h writes differently, or another term scales with cache
writes. The estimates above use the published rate and are about 10% low on 1h writes.

## Retention

- `cleanupPeriodDays: 90` is set in the user settings on the work machine. No managed-settings file
  was found at the standard macOS path; other managed sources were not checked.
- 105 transcripts are older than 30 days; none is older than 90 days yet; the oldest is 74 days old
  (2026-11-06).
- The Claude Code default is 30 days, by file modification time. Official docs confirm this.
- Do not set `cleanupPeriodDays` to 0. A reported issue says it stops transcript writes.

## Rate limits (personal machine only; provisional)

The validation question: does the five-hour or seven-day used percentage move in proportion to
transcript spend? This needs `rate_limit_snapshots` from a subscription machine.

Provisional result, as of 2026-11-07, from 205 rows spanning 2026-11-06T19:29Z to 2026-11-07T23:11Z
on the personal machine. Percentages are whole numbers and are not monotonic within a window: one 5h
window has 16 decreases across 108 rows, another has 19 across 87, and the 7d window has 4 and 2.
The figures below use each window's running maximum. Spend is main-session deltas from
`cost_snapshots` plus `subagent_tasks.estimated_cost_usd` over the same interval. The 7d rows are
split at 18:50 Nov 7, the first sample where the 7d percentage reached 13.

| Window                | Change  | Spend  | $ per point | Opus share of spend |
| --------------------- | ------- | ------ | ----------- | ------------------- |
| 5h, 15:45–19:03 Nov 7 | 0 → 77  | $36.36 | 0.47        | 93%                 |
| 5h, 22:04–23:15 Nov 7 | 0 → 43  | $14.66 | 0.34        | 43%                 |
| 7d, 15:45–18:50 Nov 7 | 3 → 13  | $33.07 | 3.31        | 92%                 |
| 7d, 18:50–22:59 Nov 7 | 13 → 18 | $16.00 | 3.20        | 60%                 |

- **Linearity is not established.** The two 7d sub-intervals agree within 4% in dollars per point,
  but the two 5h windows differ by 38%. Two windows per type cannot separate a real nonlinearity
  from whole-percent rounding and noise.

- **Model mix does not explain the 5h gap consistently.** The Opus-heavy 5h window costs more per
  point, but the 7d sub-intervals move from 92% to 60% Opus with almost no change in dollars per
  point. A token-weighted limit would predict a shift in both. The result does not support it, and
  does not rule it out.

- **Excluded:** two 5h windows with 2 points each (1 → 3, 0 → 2). They are too coarse to use.

- **Token kinds (transcripts, one record per `requestId`, all projects and subagents).** Points per
  unit, compared across the two windows of each type:

  | Metric      | 5h ratio gap | 7d ratio gap |
  | ----------- | ------------ | ------------ |
  | Dollars     | 32%          | 3%           |
  | Output      | 9%           | 0.2%         |
  | Input       | 43%          | 30%          |
  | Cache write | 40%          | 45%          |
  | Cache read  | 29%          | 24%          |
  | All tokens  | 30%          | 25%          |

  Output tokens agree best in the 5h windows, where the rounding error is about ±1–2%. The 7d gaps
  are inside the rounding error (the 5-point change alone is about ±10%), so they do not separate
  the metrics. Six metrics on four intervals is a lead to test on more windows, not a finding.

- **`cost_snapshots` and `sessions` token fields are not running totals.** `input_tokens` and
  `output_tokens` hold the most recent API call's values. In `cost_snapshots` they fall within a
  session (12 and 595 decreases). In `sessions`, input equals the last call's input plus cache reads
  and writes exactly, checked against one session's transcript. Use transcripts for token totals.

The seven-day window was flat at 3% from before 15:45 Nov 7, so spend before that point does not
count toward its change.

Runbook (run on the machine that has rate-limit data):

1. Retention: check `cleanupPeriodDays`, managed settings, and the ages of transcript files.
1. Snapshot sanity check: `resets_at` values are epoch seconds. Percentages are not monotonic in the
   table, so use each window's running maximum.
1. Group snapshots by window (`five_hour_resets_at`, `seven_day_resets_at`). Take the change from
   the first snapshot to the running maximum, and note when the maximum was first reached. Split a
   window's interval where its other reset changes; the 5h window at 03:00 UTC Nov 8 changed its 7d
   reset at 23:00 UTC Nov 7.
1. For the same time interval, sum token totals per kind (input, output, cache write, cache read)
   from transcripts, one record per `requestId`. Then sum spend: main-session deltas from
   `cost_snapshots` plus `subagent_tasks.estimated_cost_usd`. Cross-check against transcripts where
   retention allows (method above).
1. Compare percentage change with spend change per window. A roughly linear relationship means the
   percentage tracks spend. Report the fit and the windows that do not match.
1. The snapshot table has no `session_id`. Per-session attribution can only split a window's spend
   by session. It cannot read sessions out of the percentage.

## Open items

- Rate-limit validation (above): provisional. Needs a token-weighting test and more windows.
- Outliers 605bf8c9 and 492a3eb3 (above). f4f9eae5 is explained by a likely missing request and web
  searches, not yet verified.
- Counting convention: per-`requestId` for estimator comparisons. Session 492a3eb3 is the exception.
- Cache-write rate: the 1h write rate implied by `cost-state` is about 10% above the published rate
  (see Cache-write rate check). Verify before changing `pricing.json`.
- Usage.db `subagent_tasks` estimate: resolved for new rows. Rows are priced from subagent
  transcripts. Historical rows are repriced by `backfill-subagent-cost.sh`, which is a dry run
  unless given `--apply`.
- Effort split and session-level cross-check in Q4 are from the 117-set scope; recount if reused.
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
- The main-session snapshot estimator is unchanged. Any change to it needs a plan and review first.
