---
name: ci-cd-pipeline
description: CI/CD workflow decisions and operational notes for MioBridge
metadata:
  type: project
---

# CI/CD Pipeline

## 2026-07-01 — Type check runs in the Next.js workspace

The repository root still contains a migration-era `tsconfig.json` that points
at root `src/**/*`. The active application lives under `frontend/`, so CI must
run TypeScript checks from that workspace.

Current PR gate:

```bash
bun run lint
cd frontend && bunx tsc --noEmit
bun run build
```

The root `package.json` exposes `bun run typecheck` as a convenience wrapper
for the frontend command.
