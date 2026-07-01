# MioBridge

[简体中文](./README.zh-CN.md)

> A distributed subscription converter and control plane powered by mihomo.
> MioBridge aggregates sing-box, Xray, and V2Ray node sources into
> Clash-compatible outputs with an SSR dashboard, remote Agent support, and
> atomic production deployment.

MioBridge is a single Next.js full-stack service. The dashboard, API routes,
scheduled jobs, and backend conversion services all live under `frontend/`.
Production runs the Next standalone output directly, with no separate Express
server.

## Highlights

- **Multi-protocol aggregation**: vless, vmess, trojan, hysteria2, tuic, shadowsocks
- **Clash-compatible outputs**: `raw.txt`, `subscription.txt`, and `clash.yaml`
- **Distributed nodes**: remote nodes expose source URLs through a lightweight Agent
- **HMAC control plane**: the main node talks to Agents over signed HTTP requests
- **SSR dashboard**: Next.js Pages Router UI using the Botanical Garden theme
- **Scheduled refresh**: automatic subscription updates plus manual API/UI triggers
- **Atomic deployment**: GitHub Actions build, SSH upload, symlink switch, health check, rollback

## Stack

| Layer | Tech |
| --- | --- |
| Runtime | Node.js 18+ in production, Bun for development and builds |
| App | Next.js Pages Router, Node runtime, standalone output |
| UI | React, Tailwind CSS, Botanical Garden design tokens |
| Conversion | mihomo |
| Config | YAML files under `~/.config/miobridge` |
| Agent | Bun-compiled remote node service |
| Deploy | systemd, Nginx, GitHub Actions, SSH |

## Quick Start

```bash
git clone https://github.com/imal1/MioBridge.git
cd MioBridge
bun install
bun run dev
```

Open `http://localhost:3001`.

Production build and standalone start:

```bash
bun run build
bun run start
```

Runtime config and generated files live outside the repository:

```text
~/.config/miobridge/
  config.yaml
  nodes.yaml
  raw.txt
  subscription.txt
  clash.yaml
  log/
  bin/
```

## Common Commands

```bash
bun run lint
bun run typecheck
bun run build
cd frontend && bun run test
cd agent && bun test
```

Build the remote Agent binary:

```bash
cd agent
bun build src/server.ts --compile --target=bun-linux-x64 --outfile miobridge-agent
```

## Public Endpoints

| Endpoint | Purpose |
| --- | --- |
| `/` | SSR dashboard |
| `/api/health` | health check |
| `/api/status` | service status |
| `/api/update` | trigger subscription refresh |
| `/api/convert` | convert supplied subscription content |
| `/subscription.txt` | base64 subscription output |
| `/clash.yaml` | Clash YAML output |
| `/raw.txt` | raw node list output |

Compatibility paths are served by Next rewrites, so public URLs stay stable
while implementation remains inside API routes.

## Project Layout

```text
frontend/
  src/pages/                 Next pages and API routes
  src/server/                framework-independent backend services
  src/components/            dashboard UI
  next.config.js             standalone output and rewrites
agent/                       remote node Agent
scripts/                     install, manage, and deploy helpers
docs/                        deployment and operations documentation
.github/workflows/           CI/CD workflows
```

## Deployment

Production deployments are normally triggered by pushing `main`. The workflow
builds the standalone Next.js output, uploads it to the server, switches the
runtime symlink atomically, restarts `miobridge`, and verifies health before
finishing.

Detailed setup is in [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md). CI/CD notes are
in [docs/CI-CD.md](./docs/CI-CD.md).

## Operations

Useful commands on a deployed host:

```bash
sudo systemctl status miobridge
sudo journalctl -u miobridge -n 100 --no-pager
tail -n 100 ~/.config/miobridge/log/combined.log
readlink ~/.config/miobridge/dist
```

For troubleshooting, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## License

MIT
