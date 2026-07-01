# CI/CD

Keep this document short; workflow files are the source of truth.

## Workflows

- `ci.yml`: PR gate. Runs lint, frontend typecheck, and build.
- `deploy.yml`: push/manual deployment. Builds standalone output, uploads a
  release, switches the server symlink, restarts service, and health checks.
- `health-check.yml`: scheduled/manual health check with restart attempt.

## Local Equivalents

```bash
bun run lint
bun run typecheck
bun run build
```

## Deployment Secrets

Required: `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`.

Optional/common: `DEPLOY_PORT`, `DEPLOY_BASE_DIR`, `DEPLOY_KNOWN_HOSTS`.

Use workflow logs and GitHub Step Summary for run details instead of expanding
this file.
