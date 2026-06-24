# MioBridge

基于 Mihomo 内核的 sing-box → Clash 订阅转换服务 — 多协议节点自动聚合、转换，提供实时 Web 仪表盘。

## 功能特性

- 🔄 **自动转换** — 从 sing-box 获取节点，经 mihomo 内核转换为 Clash YAML 格式
- 🌟 **全协议支持** — vless (含 reality)、vmess、trojan、hysteria2、tuic、shadowsocks
- 🖥️ **Web 仪表盘** — Next.js SSR 实时状态监控，Botanical Garden 主题
- 🕒 **定时更新** — node-cron 定时自动刷新订阅
- 🚀 **原子部署** — GitHub Actions 推送 → SSH 远程部署 → 软链接切换 → 失败自动回滚
- 📝 **结构化日志** — Winston 日志系统，按级别和大小轮转
- 🔧 **零外部服务** — 不依赖 subconverter，mihomo 本地命令行调用

## 技术栈

| 层 | 技术 |
|----|------|
| 运行时 | Node.js >= 18（生产），Bun（开发/构建） |
| 框架 | Next.js (Pages Router, standalone 输出) |
| 前端 | React + Tailwind CSS + shadcn/ui |
| 转换内核 | mihomo (clash-meta) |
| 配置解析 | yq (mikefarah/yq v4) |
| 日志 | Winston |
| 定时任务 | node-cron |
| 部署 | systemd + Nginx + GitHub Actions |

## 系统要求

- Linux 服务器（Ubuntu 18.04+ / Debian 10+）
- Node.js >= 18
- sing-box（已安装并配置）
- mihomo + yq（自动安装到 `~/.config/miobridge/bin/`）

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/imal1/miobridge.git
cd miobridge
```

### 2. 安装依赖 & 构建

```bash
bun install
bun run build
```

### 3. 配置

配置文件位于 `~/.config/miobridge/config.yaml`。首次运行时会自动使用默认值，你也可以手动编辑：

```yaml
app:
  port: 3001
protocols:
  sing_box_configs:
    - vless
    - hysteria2
    - trojan
    - tuic
    - vmess
automation:
  auto_update_cron: "0 */2 * * *"
```

### 4. 启动

```bash
# 开发模式（端口 3001）
bun run dev

# 生产模式
bun run build && bun run start
```

访问 `http://localhost:3001` 查看仪表盘。

## 生产部署

推荐使用 GitHub Actions 自动部署。首次在服务器上完成一次性准备后，每次 `git push origin main` 自动触发部署。

### 服务器一次性准备

参见 [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) 完整指南，概要：

1. 安装 systemd 单元和 Nginx 反代配置
2. 配置 GitHub Secrets（`DEPLOY_HOST`、`DEPLOY_USER`、`DEPLOY_SSH_KEY` 等）
3. 配置 NOPASSWD sudoers 允许免密重启服务

### 部署流程

```
git push → GitHub Actions → Build (Next standalone) → SSH 上传 → 
server-deploy.sh 原子切换 → systemctl restart → 健康检查 → 完成
```

失败时自动回滚到上一个 release，保留最近 5 个版本。

## API 端点

| 端点 | 方法 | 说明 | 鉴权 |
|------|------|------|------|
| `/` | GET | Web 仪表盘 (SSR) | 无 |
| `/api/health` | GET | 健康检查 | 无 |
| `/api/status` | GET | 服务状态 | 无 |
| `/api/update` | GET | 触发订阅更新 | 无 |
| `/api/convert` | POST | 在线转换订阅内容 | 无 |
| `/api/configs` | GET | 获取配置列表 | 无 |
| `/subscription.txt` | GET | 订阅文件 (base64) | 无 |
| `/clash.yaml` | GET | Clash 配置文件 (YAML) | 无 |
| `/raw.txt` | GET | 原始节点列表 | 无 |

## 项目结构

```
frontend/                         ← Next.js 全栈应用
  src/
    server/                       ← 后端逻辑
      config/index.ts             ← 配置管理
      services/                   ← 业务服务（单例）
        mioBridgeService.ts
        mihomoService.ts
        singBoxService.ts
        yamlService.ts
      utils/logger.ts             ← Winston 日志
    pages/
      index.tsx                   ← 仪表盘 (SSR)
      api/                        ← API 路由
    components/                   ← React 组件
      Dashboard.tsx
      ConvertModal.tsx
      layout/
      ui/
  next.config.js                  ← standalone + rewrites
scripts/
  server-deploy.sh                ← 原子部署脚本
  manage.sh                       ← 管理脚本
.github/workflows/deploy.yml      ← CI/CD 流水线
.claude/roadmap/                  ← 开发路线图
docs/                             ← 文档
```

## 开发

```bash
bun install            # 安装依赖
bun run dev            # 开发模式 (next dev -p 3001)
bun run build          # 构建 (next build, standalone 输出)
bun run start          # 生产启动 (node server.js)
bun run lint           # 代码检查 (oxlint)
```

## 路线图

详见 [.claude/roadmap/](./.claude/roadmap/) — v0.1 已达成，v0.2 ~ v1.0 规划中。

## 故障排除

常见问题见 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)，部署问题见 [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)。

```bash
# 查看服务日志
sudo journalctl -u miobridge -f

# 查看应用日志
tail -f ~/.config/miobridge/log/combined.log

# 查看当前部署版本
readlink ~/.config/miobridge/dist
```

## 贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'feat: xxx'`)
4. 推送到分支 (`git push origin feature/xxx`)
5. 创建 Pull Request

提交遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范。

## 许可证

MIT © [imal1](https://github.com/imal1)

## 致谢

- [mihomo (clash-meta)](https://github.com/MetaCubeX/mihomo) — 规则处理引擎
- [sing-box](https://github.com/SagerNet/sing-box) — 通用代理平台
- [yq](https://github.com/mikefarah/yq) — YAML 处理工具
