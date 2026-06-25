---
name: ci-cd-pipeline
description: MioBridge GitHub Actions CI/CD 流水线
metadata:
  type: project
---

# CI/CD 流水线

## 流水线总览

```
PR opened ──→ ci.yml ──→ lint → typecheck → build ──→ ✅ merge allowed
                                                          │
push to main ──→ deploy.yml ──→ build → pack → deploy → health check ──→ ✅
                                                          │
cron */5 ──→ health-check.yml ──→ ping → 正常/自动恢复/告警
```

## ci.yml — PR 门禁

**触发条件**：`pull_request` 到 `main`，或 `workflow_dispatch`

**Job 链路**：`lint` → `typecheck` → `build`（串行，失败即停止）

- **lint**：Checkout → Setup Bun → Install → `bun run lint`（oxlint）
- **typecheck**：Checkout → Setup Bun → Install → `npx tsc --noEmit`
- **build**：Checkout → Setup Bun + Node → Install → `bun run build` → 验证 `frontend/.next/standalone/frontend/server.js` 存在

## deploy.yml — 自动部署

**触发条件**：push 到 `main`，或 `workflow_dispatch`（可指定 ref）

**并发控制**：`concurrency: deploy-prod`，`cancel-in-progress: false`

**步骤**：
1. Checkout（`actions/checkout@v4`）
2. Setup Bun（`oven-sh/setup-bun@v2`，版本 1.0.30）
3. Setup Node（`actions/setup-node@v4`，版本 20）
4. Install dependencies（`bun install`）
5. Build（`bun run build`，Next standalone）
6. Assemble（复制 `.next/static` 和 `public` 到 standalone 目录）
7. Compute release id（`YYYYMMDD-HHMMSS-<sha7>`）
8. Pack tarball（`tar -czf`）
9. Setup SSH（写入 `DEPLOY_SSH_KEY` 和 `DEPLOY_KNOWN_HOSTS`）
10. Upload artifact & deploy script（scp 到 `/tmp/miobridge-deploy-<id>/`）
11. Apply deploy（远程执行 `server-deploy.sh apply`）
12. Cleanup remote tmp（`if: always()`）
13. Summary（部署成功时输出 release id、host、commit）

## health-check.yml — 定时健康检查

**触发条件**：`schedule: "*/5 * * * *"` + `workflow_dispatch`

**步骤**：
1. Setup SSH（使用已有 secrets）
2. SSH 到服务器执行 `curl -fsS http://127.0.0.1:<port>/api/health`
3. 成功 → Step Summary 记录 ✅
4. 失败 → `sudo systemctl restart miobridge` → sleep 10 → 再次 curl
   - 恢复 → Step Summary 记录 ⚠️ 已自动恢复
   - 仍失败 → Step Summary 记录 ❌ 需人工介入

## GitHub Secrets

| Secret | 用途 |
|--------|------|
| `DEPLOY_HOST` | 服务器地址 |
| `DEPLOY_USER` | SSH 用户 |
| `DEPLOY_SSH_KEY` | 部署专用 SSH 私钥 |
| `DEPLOY_KNOWN_HOSTS` | 服务器 host key（防 MITM） |
| `DEPLOY_PORT` | SSH 端口（默认 22） |
| `DEPLOY_BASE_DIR` | 部署根目录（默认 `~/.config/miobridge`） |

## 本地操作

```bash
# 触发部署
gh workflow run deploy.yml --ref main

# 等待并查看部署
gh run watch $(gh run list -w deploy.yml -L1 --json databaseId -q '.[0].databaseId')

# 查看最近的 workflow runs
gh run list -w deploy.yml -L5
gh run list -w health-check.yml -L3
```
