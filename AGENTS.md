# AGENTS.md

Keep this file small. It is loaded often.

## Project

MioBridge is a TypeScript subscription converter. The active app is a single
Next.js full-stack service under `frontend/` using Pages Router, Node runtime,
SSR, and `output: 'standalone'`. There is no separate Express server.

## Architecture Rules

- Backend logic lives in `frontend/src/server/**` and is framework-independent.
  Use `XxxService.getInstance()` and expose new behavior through thin API routes.
- SSR pages call services directly in `getServerSideProps`; do not self-call HTTP
  inside the same process.
- Node-only modules belong in `server/`, `pages/api/`, or
  `instrumentation-node.ts`. Keep `instrumentation.ts` guarded by
  `NEXT_RUNTIME === 'nodejs'` before dynamic import.
- Runtime config/data/logs/backups live under `~/.config/miobridge`, independent
  of cwd. Config is `~/.config/miobridge/config.yaml`.
- External binaries are `mihomo`, `yq`, and optionally `sing-box`; prefer
  `~/.config/miobridge/bin/`, then repo `bin/`, then PATH.
- Public compatibility URLs `/subscription.txt`, `/clash.yaml`, `/raw.txt`, and
  `/health` are Next rewrites to internal API routes.
- Main node generates `raw.txt`, `subscription.txt`, and `clash.yaml`. Child nodes
  only run the Agent/kernel and expose source URLs.
- Normal remote Agent checks use public `http://<host>:<agentPort>` plus HMAC.
  SSH is for deployment/diagnosis only.

## Commands

```bash
bun install
bun run dev                 # cd frontend && next dev -p 3001
bun run build               # Next standalone build
bun run start               # node frontend/.next/standalone/frontend/server.js
bun run lint                # oxlint frontend/src
bun run typecheck           # frontend TypeScript check
cd agent && bun test
cd agent && bun build src/server.ts --compile --target=bun-linux-x64 --outfile miobridge-agent
```

Do not run root `npx tsc --noEmit`; the active TS project is `frontend/`.

## Deployment Notes

- Production runs Node with `PORT`, `HOSTNAME=0.0.0.0`, and
  `NODE_ENV=production`.
- `scripts/manage.sh install` builds and installs standalone output to
  `~/.config/miobridge/dist/frontend/server.js`.
- Standalone output needs `.next/static` and `public` copied into the runtime
  directory; preserve that in build/deploy changes.

## UI

Use the existing Botanical Garden design tokens from
`frontend/src/styles/globals.css`. Avoid hard-coded colors and Tailwind gray
palette classes in components; prefer CSS variables and existing UI patterns.

## Memory

Update `.Codex/memory/` only when the change matches its topic:

- bug fix: prepend to `.Codex/memory/bug-fixes.md`
- architecture/tech decision: append to `.Codex/memory/project-architecture.md`
- CI/CD change: update `.Codex/memory/ci-cd-pipeline.md`
- deployment flow change: update `.Codex/memory/deployment-flow.md`
- config convention change: update `.Codex/memory/config-patterns.md`
- coding/lint convention change: update `.Codex/memory/coding-conventions.md`

Keep memory entries short. Add new files to `.Codex/memory/MEMORY.md`.
