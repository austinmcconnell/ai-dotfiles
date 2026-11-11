# Cost estimation: method and validation

How usage cost is estimated and why the estimator is shaped as it is: the data sources, the pricing
rules, how the estimate was validated, and the standing decisions. The estimator itself is described
in `README.md` in this directory.

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

An earlier comparison of transcript token totals against `cost-state` implied a 1h cache-write rate
about 2.22× input rather than the published 2.0×, mostly in Haiku 5.5 sessions. Repricing the last
`cost-state` record per session from its own token counts with `pricing.json` (2.0× for 1h writes,
1.25× for 5m) removes that gap for every model except Haiku 5.5: Opus 5.5, Sonnet 5.5, Sonnet 5 and
Opus 5 match `costUSD` within 0.5% in 35 of 36 session-model rows (the other is 1.7% off). The
published rates and `pricing.json` are right, so no rate change is warranted.

Haiku 5.5 does not reprice from model-level totals, because its 100K-token tier applies per request.
Pricing each request from the transcripts with the tier closes most of it: in 18 sessions the
flat-rate estimate is 1.1× to 5.3× below `cost-state`, and the tiered estimate is within 1.3× in 11
of them, including the five sessions with the most spend. Transcript token totals do not match
`cost-state` exactly in any of those sessions, so the remaining 2% to 30% gap is not isolated. Four
small sessions (under $0.10) stay 2× to 3.6× off with or without the tier, and are unexplained.

The official prompt-caching page (checked 2026-11-06) gives 1h cache writes as 2× base input and 5m
writes as 1.25×, matching `pricing.json`.

## Retention

- `cleanupPeriodDays: 90` is set in the user settings on the work machine. No managed-settings file
  was found at the standard macOS path; other managed sources were not checked.
- Check transcript file ages before relying on a cross-check; files past the window are deleted.
- The Claude Code default is 30 days, by file modification time. Official docs confirm this.
- Do not set `cleanupPeriodDays` to 0. A reported issue says it stops transcript writes.

## Rate limits (personal machine only; provisional)

The validation question: does the five-hour or seven-day used percentage move in proportion to
transcript spend? This needs `rate_limit_snapshots` from a subscription machine.

Result, as of 2026-11-11, from `rate_limit_snapshots` rows spanning 2026-11-06T19:29Z to
2026-11-11T14:50Z on the personal machine. Percentages are whole numbers and are not monotonic
within a window, so the figures use each window's running maximum. Spend is priced from transcripts,
one record per `requestId` over all projects and subagents, with the rules in Method. Each 5h window
runs from its first snapshot (at 0%) to the first sample where its maximum was reached. Times are
UTC.

| 5h window               | Change | Spend  | $ per point | Opus share of spend |
| ----------------------- | ------ | ------ | ----------- | ------------------- |
| Nov 7 15:45–19:03       | 0 → 77 | $33.71 | 0.44        | 92%                 |
| Nov 7 22:04–Nov 8 02:00 | 0 → 99 | $32.58 | 0.33        | 66%                 |
| Nov 8 13:08–17:59       | 0 → 32 | $7.09  | 0.22        | 15%                 |
| Nov 8 18:00–22:58       | 0 → 33 | $11.37 | 0.34        | 94%                 |
| Nov 8 23:07–Nov 9 02:31 | 0 → 64 | $22.43 | 0.35        | 99%                 |
| Nov 9 14:06–14:23       | 0 → 13 | $3.08  | 0.24        | 80%                 |
| Nov 11 01:57–04:16      | 0 → 27 | $8.52  | 0.32        | 52%                 |
| Nov 11 13:47–14:50      | 0 → 22 | $5.47  | 0.25        | 15%                 |

The last window was still open when this was measured, so its figures are a lower bound.

- **Within a window the percentage is linear in spend.** The running-maximum percentage against
  cumulative dollars has R² of 0.985 or better in 7 of 8 windows. The 17-minute Nov 9 window is the
  exception at 0.854.

- **Across 5h windows the ratio is not stable.** Dollars per point ranges from 0.22 to 0.44
  (coefficient of variation 23%), against whole-percent rounding of under about 4% at these changes.
  A fixed offset (percentage = 8.6 + 2.40 × dollars) raises R² only from 0.910 to 0.943, with
  residuals from −12.5 to +12.2 points. The through-origin slope implies about $36 of
  transcript-priced spend per 5h limit. That is a fit, not a measured limit.

- **The 7d percentage is linear in cumulative spend.** From 0 at 23:00 Nov 7 to 33, over 312
  snapshots, R² against cumulative dollars is 0.999 and spend is $83.01 (about 2.5 dollars per
  point). Each successive 5-point step cost $11.69 to $13.90, or 2.34 to 2.78 dollars per point.
  That implies about $250 per 7d limit, from one window. The window resets at 23:00 Nov 14.

- **Model mix does not explain the 5h spread consistently.** Opus share runs from 15% to 99%. The
  two windows at 15% Opus cost 0.22 and 0.25 per point and the windows at 66% to 99% cost 0.33 to
  0.44, but the 80% Opus window costs 0.24. A token-weighted limit would predict a clean shift. The
  result neither supports it nor rules it out.

- **Excluded:** four 5h windows whose change was 3 points or less (1 → 3, 0 → 2, 0 → 1, 0 → 1). They
  are too coarse to use.

- **Which metric the percentage follows is unresolved.** Across the eight 5h windows:

  | Metric      | Spread of points per unit | Through-origin R² (5h) | R² against cumulative (7d) |
  | ----------- | ------------------------- | ---------------------- | -------------------------- |
  | Dollars     | 23%                       | 0.910                  | 0.999                      |
  | Output      | 43%                       | 0.974                  | 0.981                      |
  | Input       | 35%                       | 0.453                  | 0.959                      |
  | Cache write | 30%                       | 0.724                  | 0.981                      |
  | Cache read  | 39%                       | 0.389                  | 0.962                      |

  Dollars has the most stable ratio and the best 7d fit. Output tokens has the best 5h
  through-origin fit, but two large windows dominate it. The 7d column is weak evidence for any
  metric, because every cumulative series rises over time. Eight windows cannot separate them.

- **Not checked:** usage on other devices or on claude.ai counts toward the same limits and is not
  in this machine's transcripts. It could account for the 5h spread. Testing that needs the other
  device's usage for the same windows.

- **`cost_snapshots` and `sessions` token fields are not running totals.** `input_tokens` and
  `output_tokens` hold the most recent API call's values. In `cost_snapshots` they fall within a
  session (12 and 595 decreases). In `sessions`, input equals the last call's input plus cache reads
  and writes exactly, checked against one session's transcript. Use transcripts for token totals.

Runbook (run on the machine that has rate-limit data):

1. Retention: check `cleanupPeriodDays`, managed settings, and the ages of transcript files.
1. Snapshot sanity check: `resets_at` values are epoch seconds. Percentages are not monotonic in the
   table, so use each window's running maximum.
1. Group snapshots by window (`five_hour_resets_at`, `seven_day_resets_at`). Take the change from
   the first snapshot to the running maximum, and note when the maximum was first reached. Split a
   window's interval where its other reset changes; the 5h window at 03:00 UTC Nov 8 changed its 7d
   reset at 23:00 UTC Nov 7.
1. For the same time interval, sum token totals per kind (input, output, cache write, cache read)
   and priced spend from transcripts, one record per `requestId`, over all projects and subagents.
   Where transcripts have aged out, fall back to main-session deltas from `cost_snapshots` plus
   `subagent_tasks.estimated_cost_usd`, which run low (see Coverage).
1. Compare percentage change with spend change per window. A roughly linear relationship means the
   percentage tracks spend. Report the fit and the windows that do not match.
1. The snapshot table has no `session_id`. Per-session attribution can only split a window's spend
   by session. It cannot read sessions out of the percentage.

## Decisions

- Estimator source: usage.db `cost_snapshots`. Transcripts and `cost-state` are cross-checks only
  because of retention.
- The main-session snapshot estimator is unchanged. Any change to it needs a plan and review first.
- Subagent cost is priced from each subagent's own transcript. A blended input/output rate times
  `tokenCount` misprices both ways (cache-read-heavy Sonnet 3.6× high, output-heavy Haiku 5.5 0.7×),
  so no constant correction fits.
- `total_cost_usd` is the authoritative session total. Whether it fully includes subagent cost is
  not proven: adding subagent transcripts moved the median transcript-to-actual ratio from 0.78 to
  0.83 across 21 sessions, which is weak support.
- Advisor calls appear as `advisor_message` entries in `usage.iterations[]` of main-session
  transcripts, and top-level usage excludes their tokens. Estimates do not price them.
