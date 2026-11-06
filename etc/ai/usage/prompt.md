Continue the Claude Code burn-attribution analysis in the ai-dotfiles repo.

Read etc/ai/usage/burn-attribution.md first. It is committed on branch ai-burn-attribution (commit 7fadeb2) and holds the findings, method, and open items. Treat it as the source of truth; the notes it came from are not on this machine.

Your task on this machine is the rate-limit validation (question 1). The runbook is in the file's "Rate limits" section. Work through it in order:
1. Retention check: cleanupPeriodDays, any managed settings, and transcript ages.
2. Snapshot sanity check on rate_limit_snapshots.
3. Group snapshots by window, using five_hour_resets_at and seven_day_resets_at.
4. For each window, sum transcript spend over distinct requestIds, priced per the file's method.
5. Compare the percentage change with the spend change for each window. Report the fit and any windows that do not match.

If rate_limit_snapshots is empty, stop and say so. Don't guess.

Constraints:
- Do not run git add or git commit. I review and commit.
- Do not open .env files, SSH private keys, or SOPS age keys.
- Do not print transcript message content. Read keys, counts, timestamps, and numeric fields only.
- Do not set cleanupPeriodDays to 0.
- Do not use shell trace mode (bash -x or set -x) on any script that reads secrets.
- The scratch scripts from the earlier analysis are not in the repo. Rewrite the pricing from the file's method rather than looking for them.
