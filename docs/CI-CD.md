# CI/CD 流水线文档

MioBridge 使用 GitHub Actions 实现完整的 CI/CD 流水线：PR 门禁 → 自动部署 → 定时健康检查。

## 流水线概览

```
PR opened ──→ ci.yml ──→ lint → typecheck → build ──→ ✅ merge allowed
                                                         │
push to main ──→ deploy.yml ──→ build → pack → deploy → health check ──→ ✅
                                                         │
cron */5 ──→ health-check.yml ──→ ping → 正常/自动恢复/告警
```

## ci.yml — PR 门禁

### 触发条件

- PR 到 `main` 分支
- 手动 `workflow_dispatch`

### Job 链路

```
lint (oxlint)
  │
  ▼
typecheck (tsc --noEmit)
  │
  ▼
build (next build + standalone 验证)
```

每个 job 依赖前一个，任何失败都会阻止 merge。

### lint job

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: oven-sh/setup-bun@v2
    with:
      bun-version: 1.0.30
  - run: bun install
  - run: bun run lint
```

### typecheck job

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: oven-sh/setup-bun@v2
    with:
      bun-version: 1.0.30
  - run: bun install
  - run: npx tsc --noEmit
```

### build job

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: oven-sh/setup-bun@v2
    with:
      bun-version: 1.0.30
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
  - run: bun install
  - run: bun run build
  - run: |
      test -f frontend/.next/standalone/frontend/server.js || {
        echo "missing frontend/.next/standalone/frontend/server.js"
        exit 1
      }
```

## deploy.yml — 自动部署

### 触发条件

- push 到 `main` 分支
- 手动 `workflow_dispatch`（可指定 ref）

### 并发控制

`concurrency: deploy-prod`，`cancel-in-progress: false`（不取消正在进行的部署）

### 完整步骤

| 步骤 | 说明 |
|------|------|
| Checkout | `actions/checkout@v4`，支持 `workflow_dispatch` 指定 ref |
| Setup Bun | `oven-sh/setup-bun@v2`，版本 1.0.30 |
| Setup Node | `actions/setup-node@v4`，版本 20（构建时 runtime 一致性） |
| Install | `bun install` |
| Build | `bun run build`（Next.js standalone） |
| Assemble | 复制 `.next/static` 和 `public` 到 standalone 目录 |
| Compute release id | `YYYYMMDD-HHMMSS-<sha7>` 格式 |
| Pack | `tar -czf release.tar.gz` 打包 standalone 整树 |
| Setup SSH | 写入 `DEPLOY_SSH_KEY` 和 `DEPLOY_KNOWN_HOSTS` |
| Upload | scp `release.tar.gz` 和 `server-deploy.sh` 到 `/tmp/miobridge-deploy-<id>/` |
| Apply | 远程执行 `server-deploy.sh apply` |
| Cleanup | `if: always()` 删除临时文件 |
| Summary | 成功时输出 release id、host、commit link |

### 原子部署原理

`server-deploy.sh` 实现零停机部署：

1. 解压到 `releases/<release-id>/`
2. 创建临时软链接 `dist.new`
3. `mv -Tf dist.new dist` 原子切换
4. `systemctl restart miobridge`
5. 轮询 `curl /api/health`（最长 30s）
6. 失败 → 软链接回滚 + 重启 + 留痕
7. 成功 → 清理旧 release（保留最近 5 个）

### 所需 Secrets

| Secret | 必填 | 说明 | 示例 |
|--------|------|------|------|
| `DEPLOY_HOST` | ✅ | 服务器地址 | `1.2.3.4` |
| `DEPLOY_USER` | ✅ | SSH 登录用户 | `imali` |
| `DEPLOY_SSH_KEY` | ✅ | 部署专用 SSH 私钥（完整内容） | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `DEPLOY_KNOWN_HOSTS` | 推荐 | `ssh-keyscan -H <host>` 输出 | 整段 known_hosts 行 |
| `DEPLOY_PORT` | 否 | 自定义 SSH 端口（默认 22） | `2222` |
| `DEPLOY_BASE_DIR` | 否 | 部署根目录（默认 `~/.config/miobridge`） | `/opt/subscription` |

## health-check.yml — 定时健康检查

### 触发条件

- `schedule: "*/5 * * * *"`（每 5 分钟）
- 手动 `workflow_dispatch`

### 检查逻辑

```
SSH 到服务器
  │
  ▼
curl http://127.0.0.1:<port>/api/health
  │
  ├─ 成功 → Step Summary ✅
  │
  └─ 失败 → systemctl restart miobridge → sleep 10
              │
              ├─ curl 成功 → Step Summary ⚠️ 已自动恢复
              │
              └─ curl 失败 → Step Summary ❌ 需人工介入
```

### 端口检测

健康检查端口通过远程执行以下逻辑获取：
1. 从 `~/.config/miobridge/config.yaml` 读取 `app.port`
2. 回退到 `PORT` 环境变量
3. 最终回退 `3001`

## 手动触发部署

### 通过 GitHub Web UI

Actions → Deploy → Run workflow → 选择分支 → Run workflow

### 通过 gh CLI

```bash
# 触发部署
gh workflow run deploy.yml --ref main

# 查看 workflow run ID
gh run list -w deploy.yml -L1

# 等待部署完成
gh run watch <run-id>

# 查看日志
gh run view <run-id> --log
```

### 通过 Claude Code 自定义命令

```
/miobridge:deploy
```

## 常见失败原因

| 错误 | 原因 | 解决 |
|------|------|------|
| `Permission denied (publickey)` | SSH key 无效或未授权 | 检查 `DEPLOY_SSH_KEY` secret，确认公钥在 `authorized_keys` 中 |
| `sudo: a password is required` | NOPASSWD sudoers 未配置 | `sudo visudo -f /etc/sudoers.d/miobridge-deploy` |
| `Host key verification failed` | 服务器 host key 不匹配 | 更新 `DEPLOY_KNOWN_HOSTS` secret |
| 健康检查超时（30s 后回滚） | 服务未正常启动 | 服务器上 `journalctl -u miobridge -n 200` |
| `release 校验失败：未找到 frontend/server.js` | 构建产物异常 | 本地 `bun run build` 验证 `.next/standalone` 结构 |

## 查看部署状态

```bash
# 当前运行版本
readlink ~/.config/miobridge/dist

# 历史版本
ls -lt ~/.config/miobridge/releases/

# 服务状态
sudo systemctl status miobridge

# 最近 workflow runs
gh run list -w deploy.yml -L5
gh run list -w health-check.yml -L3
```