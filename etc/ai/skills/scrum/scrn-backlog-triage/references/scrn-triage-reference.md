# SCRN Triage Reference

## Legacy Labels (do not use on new issues)

These exist on old issues but should not be applied to new work:

- `NY1115`, `NY1115-PO-Workflow1`, `NY1115-Go-Live`, `NY1115-Phase2`, `NY1115-Test-Case-Bug`,
  `NY1115-E2ETesting` — use epic parent relationships instead
- `roadmap` — superseded by `2026_roadmap`
- `Customer:NY1115`, `Domain:Screenings/Coordination` — cross-project taxonomy, not useful in SCRN
- `CC-UAT`, `Product_Reviewed`, `V5_EA`, `frontend`, `forms` — single-use or too generic

## The `maybe-delete` Workflow

For issues suspected to be obsolete:

1. Add the `maybe-delete` label
1. Add a comment explaining why it may be obsolete
1. If the issue belongs to another team, ask in the comment whether they want it transferred
1. After 2 weeks with no response, close the issue

## Epic Lifecycle

- Epics should be closed when all child work is Done or the initiative is abandoned
- An epic with no children and no updates in 60+ days should be reviewed for closure
- "Development & Testing" epics that haven't been updated in 90+ days are likely stale — flag them
