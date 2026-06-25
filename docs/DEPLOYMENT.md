# 远程部署指南（GitHub Actions + rsync 风格的 SSH 推送）

本文档描述如何用 GitHub Actions 替代「服务器上 git clone + 跑 manage.sh setup」的旧流程。
新流程：CI 跑构建 → 通过 SSH 把 standalone 产物推到服务器 → 服务器上原子切换软链接 → 健康检查 → 失败自动回滚。

> 服务器上的 systemd 单元、nginx 反代、外部二进制（mihomo/yq/sing-box）这些**保持不变**，
> 仍然由 `scripts/manage.sh setup` 一次性安装。CI 只负责更新 `~/.config/miobridge/dist/` 这个产物目录。

## 整体架构

```
GitHub Actions (ubuntu-latest)
  ├─ bun install + next build
  ├─ tar -czf release.tar.gz frontend/.next/standalone/.
  └─ scp + ssh →
                                 服务器
                                 ├─ /tmp/miobridge-deploy-<id>/
                                 │    release.tar.gz
                                 │    server-deploy.sh
                                 └─ ~/.config/miobridge/
                                      ├─ releases/
                                      │   ├─ 20261107-103045-abc1234/
                                      │   ├─ 20261108-091820-def5678/   ← 新
                                      │   └─ legacy/                    ← 首次迁移
                                      └─ dist → releases/20261108-091820-def5678  (软链接)
```

`systemd` 单元里 `WorkingDirectory=$DIST_DIR/frontend`、`ExecStart=node $DIST_DIR/frontend/server.js`，
`$DIST_DIR` 是软链接，所以重启服务后立即指向新版本。

## 服务器一次性准备

> 假设你已经按旧流程跑过 `scripts/manage.sh setup`，systemd 单元和 nginx 配置已生效。

### 1. 创建专用 deploy key

在**本地**生成一对仅供 CI 使用的密钥：

```bash
ssh-keygen -t ed25519 -f ~/.ssh/miobridge-deploy -N '' -C 'github-actions-deploy'
```

把公钥加入服务器对应用户的 `~/.ssh/authorized_keys`：

```bash
ssh-copy-id -i ~/.ssh/miobridge-deploy.pub <user>@<host>
# 或手动 cat ~/.ssh/miobridge-deploy.pub | ssh <user>@<host> 'cat >> ~/.ssh/authorized_keys'
```

私钥稍后填到 GitHub Secret `DEPLOY_SSH_KEY`。

### 2. 配置 NOPASSWD sudoers（仅限重启服务）

CI 在远端要执行 `sudo systemctl restart miobridge`，必须免密。
用 `sudo visudo -f /etc/sudoers.d/miobridge-deploy` 写入（注意把 `<user>` 替换成实际部署用户）：

```
<user> ALL=(root) NOPASSWD: /bin/systemctl restart miobridge, /bin/systemctl restart miobridge.service
```

> 路径以 `which systemctl` 实际输出为准（Debian/Ubuntu 通常是 `/bin/systemctl`，部分系统是 `/usr/bin/systemctl`，两个都写也无妨）。

### 3. 抓取服务器 host key

```bash
ssh-keyscan -H <host> 2>/dev/null
```

把整段输出保存为 GitHub Secret `DEPLOY_KNOWN_HOSTS`（首次缺失时 workflow 会自动 keyscan 兜底，但生产环境**强烈建议**显式配置以防中间人攻击）。

## GitHub Secrets

仓库 Settings → Secrets and variables → Actions 添加：

| Secret              | 必填 | 说明                                       | 示例                                     |
| ------------------- | ---- | ------------------------------------------ | ---------------------------------------- |
| `DEPLOY_HOST`       | ✅   | 服务器地址                                 | `1.2.3.4` 或 `vps.example.com`           |
| `DEPLOY_USER`       | ✅   | SSH 登录用户                               | `imali`                                  |
| `DEPLOY_SSH_KEY`    | ✅   | 上一步生成的 **私钥**完整内容              | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `DEPLOY_KNOWN_HOSTS`| 推荐 | `ssh-keyscan -H <host>` 的输出             | 整段 known_hosts 行                      |
| `DEPLOY_PORT`       | 否   | 自定义 SSH 端口，默认 `22`                 | `2222`                                   |
| `DEPLOY_BASE_DIR`   | 否   | 自定义部署根目录，默认 `~/.config/miobridge` | `/opt/subscription`                  |

## 触发部署

- **自动**：推送到 `main` 分支即触发。
- **手动**：Actions 页面 → `Deploy` → `Run workflow`，可指定分支/tag。

## 在服务器上手动调用

`scripts/server-deploy.sh` 是自包含的（不依赖 lib/），可单独使用：

```bash
# 健康检查
~/path/to/server-deploy.sh health

# 手动 apply（拿到一个本地 tarball）
BASE_DIR=~/.config/miobridge \
  ~/path/to/server-deploy.sh apply ./release.tar.gz manual-$(date +%s)
```

支持的环境变量：

| 变量              | 默认值                        | 用途                                  |
| ----------------- | ----------------------------- | ------------------------------------- |
| `BASE_DIR`        | `$HOME/.config/miobridge`  | 部署根目录                            |
| `SERVICE_NAME`    | `miobridge`         | systemd 单元名                        |
| `KEEP_RELEASES`   | `5`                           | 保留的历史版本数                      |
| `HEALTH_TIMEOUT`  | `30`                          | 健康检查最长等待秒数                  |
| `HEALTH_PATH`     | `/api/health`                 | 健康检查路径                          |
| `PORT`            | 自动从 `config.yaml` 读取     | 健康检查端口                          |

## 回滚与运维

### 自动回滚

部署失败（`systemctl restart` 非零，或 30 秒内 `/api/health` 不可达）时，脚本会：
1. 把 `dist` 软链接切回上一个 release
2. 重启服务
3. 把失败的 release 重命名为 `<id>.failed-<timestamp>` 留痕

### 手动回滚到任意历史版本

```bash
cd ~/.config/miobridge
ls -lt releases/                           # 查看所有 release
ln -sfn releases/<某个旧 id> dist          # 切链接（注意 -n 才会替换链接而不是落入目录）
sudo systemctl restart miobridge
```

### 查看当前版本

```bash
readlink ~/.config/miobridge/dist
```

### 清理失败留痕

```bash
rm -rf ~/.config/miobridge/releases/*.failed-*
```

## 与旧 manage.sh 流程的关系

| 场景                         | 旧流程                              | 新流程                              |
| ---------------------------- | ----------------------------------- | ----------------------------------- |
| 首次安装（systemd / nginx / mihomo） | `manage.sh setup`                   | **依然** `manage.sh setup`          |
| 部署新版本代码               | `git pull && manage.sh build`        | `git push origin main`（CI 自动）   |
| 更新 mihomo / yq / sing-box  | `manage.sh setup`                   | `manage.sh setup`（独立于 CI）      |
| 改 systemd 单元 / nginx 模板 | `manage.sh setup` 重新生成          | 同左                                |

CI 只接管「应用代码部署」这一段，二进制和服务模板仍由 `manage.sh` 在服务器上管理。

## 排查

| 现象                                   | 可能原因 / 检查                                                        |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `Permission denied (publickey)`        | `DEPLOY_SSH_KEY` 内容有误，或公钥未加入 `authorized_keys`               |
| `sudo: a password is required`         | NOPASSWD sudoers 未配置或路径不匹配（`which systemctl` 看实际路径）    |
| `Host key verification failed`         | `DEPLOY_KNOWN_HOSTS` 缺失或服务器换了 host key，重新跑 `ssh-keyscan -H` |
| 健康检查超时回滚                       | 服务器看 `journalctl -u miobridge -n 200`；端口是否被占用    |
| `release 校验失败：未找到 frontend/server.js` | 构建步骤异常，本地复现 `bun run build` 看 `.next/standalone` 结构 |

## 首次部署完整步骤

### 1. 服务器环境准备

```bash
# 安装 Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装 nginx
sudo apt-get install -y nginx

# 创建目录结构
mkdir -p ~/.config/miobridge/{bin,www,log,backup,releases}
```

### 2. 安装外部二进制

```bash
# mihomo (clash-meta)
# 从 https://github.com/MetaCubeX/mihomo/releases 下载对应架构版本
wget -O ~/.config/miobridge/bin/mihomo <mihomo-download-url>
chmod +x ~/.config/miobridge/bin/mihomo

# yq v4
wget -O ~/.config/miobridge/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
chmod +x ~/.config/miobridge/bin/yq

# sing-box (可选)
wget -O ~/.config/miobridge/bin/sing-box <sing-box-download-url>
chmod +x ~/.config/miobridge/bin/sing-box
```

### 3. 配置

```bash
# 从模板创建配置文件
cp config.yaml.example ~/.config/miobridge/config.yaml
# 编辑配置文件
nano ~/.config/miobridge/config.yaml
```

### 4. 安装 systemd 和 nginx

```bash
# 使用 manage.sh 自动配置
bash scripts/manage.sh setup
```

### 5. 配置 GitHub Actions Secrets

在仓库 Settings → Secrets and variables → Actions 中添加所有必需 secrets（见 CI-CD.md）。

## 日志查看

### 应用日志

```bash
# 综合日志
tail -f ~/.config/miobridge/log/combined.log

# 错误日志
tail -f ~/.config/miobridge/log/error.log

# 按关键词过滤
grep "订阅更新" ~/.config/miobridge/log/combined.log
grep "ERROR" ~/.config/miobridge/log/error.log

# 开启 debug 日志
# 编辑 config.yaml: logging.level: debug
sudo systemctl restart miobridge
```

### 系统日志

```bash
# 最近 100 行
sudo journalctl -u miobridge -n 100 --no-pager

# 实时跟踪
sudo journalctl -u miobridge -f

# 按时间范围
sudo journalctl -u miobridge --since "1 hour ago"

# 查看启动日志
sudo journalctl -u miobridge -b
```

## 目录结构详解

```
~/.config/miobridge/
├── config.yaml              # 主配置文件
├── dist/                    # 当前运行代码（软链接 → releases/<id>）
├── releases/                # 历史部署版本
│   ├── 20260624-162219-f387663/
│   ├── 20260625-091820-abc1234/
│   └── legacy/              # 旧布局迁移（如果有）
├── bin/                     # 外部二进制文件
│   ├── mihomo               # clash-meta 内核
│   ├── yq                   # YAML 处理工具
│   └── sing-box             # 代理管理（可选）
├── www/                     # 生成的订阅文件
│   ├── subscription.txt     # Base64 编码的节点列表
│   ├── clash.yaml           # Clash 配置文件
│   └── raw.txt              # 原始节点 URL
├── log/                     # 应用日志
│   ├── combined.log         # 综合日志
│   └── error.log            # 错误日志
└── backup/                  # 备份文件
```

## 与 health-check.yml 的协作

定时健康检查（`health-check.yml`）每 5 分钟自动 ping `/api/health`。如果服务不可达，会自动重启服务并重试。如果重启后仍不可达，会在 GitHub Actions Step Summary 中记录 ❌，需要人工介入。

### 手动健康检查

```bash
# 通过 server-deploy.sh
bash scripts/server-deploy.sh health

# 直接 curl
curl -fsS http://localhost:3001/api/health
```

### 禁用自动恢复

如果需要在维护期间禁用自动恢复，可以暂停 health-check workflow：

```bash
gh workflow disable health-check.yml
# 维护完成后
gh workflow enable health-check.yml
```
