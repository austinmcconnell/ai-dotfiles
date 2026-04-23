# GitHub Actions Conventions

## Security

- Pin third-party actions to full commit SHA, not tags
- Use `permissions` block to restrict token scope (least privilege)
- Never use `pull_request_target` with checkout of PR head
- Prefer OIDC (`id-token: write`) over long-lived cloud credentials
- Never echo secrets to logs

## Structure

- One workflow per concern (CI, release, deploy)
- Set `concurrency` to cancel redundant runs on the same branch
- Cache dependencies for faster builds
- Use matrix builds for multi-version testing

## Debugging

- Check Annotations tab before diving into full logs
- Suggest `act` (nektos/act) for local workflow testing
