# CI/CD

Keep this document short; workflow files are the source of truth.

## Workflows

- `ci.yml`: PR gate. Runs lint, frontend typecheck, and build.

Production deploys are handled by Vercel Git Integration, not GitHub Actions.
The old SSH/systemd `deploy.yml` and `health-check.yml` workflows were removed.

## Local Equivalents

```bash
bun run lint
bun run typecheck
bun run build
```

## Deployment Secrets

No GitHub Actions deployment secrets are required for production. Keep Vercel
project settings and production environment variables in the Vercel dashboard.
