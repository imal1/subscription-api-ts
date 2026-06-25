---
name: deployment-flow
description: MioBridge 部署流程（systemd + Nginx + GitHub Actions）
metadata:
  type: project
---

# 部署流程

## 架构概览

```
GitHub Actions (ubuntu-latest)
  ├─ bun install + next build
  ├─ tar -czf release.tar.gz frontend/.next/standalone/.
  └─ scp + ssh →
                      服务器
                      ├─ /tmp/miobridge-deploy-<id>/
                      └─ ~/.config/miobridge/
                           ├─ releases/
                           │   ├─ 20260624-162219-f387663/
                           │   └─ ...
                           ├─ dist → releases/<current>  (软链接)
                           ├─ config.yaml
                           ├─ www/    (subscription.txt, clash.yaml, raw.txt)
                           ├─ log/    (combined.log, error.log)
                           └─ bin/    (mihomo, yq, sing-box)
```

## 原子部署流程（`scripts/server-deploy.sh`）

1. 解压 tarball 到 `releases/<release-id>/`
2. 校验 standalone 入口（`frontend/server.js` 必须存在）
3. 创建临时软链接 `dist.new` → `releases/<release-id>`
4. `mv -Tf dist.new dist` 原子切换
5. `systemctl restart miobridge`
6. 轮询 `curl /api/health`（最长 30s）
7. 失败则回滚：软链接切回上一个 release → 重启 → 失败 release 重命名为 `.failed-<timestamp>`
8. 成功则清理旧 release（保留最近 5 个）

## systemd 单元

- **单元名**：`miobridge`
- **模板**：`config/miobridge.service.template`
- **运行方式**：`node $DIST_DIR/frontend/server.js`
- **环境变量**：`PORT=<api_port> HOSTNAME=0.0.0.0 NODE_ENV=production`
- **WorkingDirectory**：`$DIST_DIR/frontend`

## Nginx 反代

- **模板**：`config/nginx.conf.template`
- **模式**：所有请求（`/`、`/api/*`、`/_next/*`、文件下载）反代到 Next.js 单进程
- **静态加速**：订阅文件可由 nginx 直接从 `$DATA_DIR/www/` 提供

## 目录布局

| 路径 | 用途 |
|------|------|
| `~/.config/miobridge/config.yaml` | 运行时配置 |
| `~/.config/miobridge/dist/` | 当前运行的代码（软链接） |
| `~/.config/miobridge/releases/` | 历史部署版本 |
| `~/.config/miobridge/www/` | 生成的订阅文件 |
| `~/.config/miobridge/log/` | Winston 日志 |
| `~/.config/miobridge/backup/` | 备份目录 |
| `~/.config/miobridge/bin/` | 外部二进制（mihomo, yq, sing-box） |

## 部署触发方式

| 方式 | 命令/条件 |
|------|----------|
| 自动 | push 到 `main` 分支 |
| 手动 (GitHub) | Actions → Deploy → Run workflow |
| 本地 CLI | `gh workflow run deploy.yml --ref main` |
| 自定义命令 | `/miobridge:deploy` |

## 回滚

### 自动回滚
部署失败时 `server-deploy.sh` 自动执行。

### 手动回滚
```bash
cd ~/.config/miobridge
ls -lt releases/
ln -sfn releases/<旧版本目录名> dist
sudo systemctl restart miobridge
```

### 查看当前版本
```bash
readlink ~/.config/miobridge/dist
```