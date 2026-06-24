# 迁移指南：从 Subconverter 到 Mihomo

> **历史文档** — 本迁移已于 2026-06 完成。当前版本 (v1.1.0+) 使用 mihomo 作为转换内核，不再需要 subconverter。

## 迁移概述

| 项目 | 旧 (subconverter) | 新 (mihomo) |
|------|-------------------|-------------|
| 转换内核 | subconverter 外部服务 | mihomo (clash-meta) 本地命令行 |
| 协议支持 | 不支持 vless/hysteria2/tuic | 全协议支持 |
| 外部依赖 | 需要运行 subconverter 进程 | 仅需 mihomo 二进制文件 |
| 部署方式 | Express.js 后端 | Next.js 全栈 SSR |
| 配置格式 | `.env` 文件 | `config.yaml` (yq 解析) |

## 当前架构

项目现在是单一 Next.js 全栈应用（Pages Router, `output: 'standalone'`）。后端逻辑在 `frontend/src/server/services/` 下，包括：

- `mihomoService.ts` — mihomo 调用、协议解析、Clash 配置生成
- `singBoxService.ts` — sing-box 交互
- `subscriptionService.ts` — 订阅更新和状态管理
- `yamlService.ts` — config.yaml 配置管理

mihomo 二进制文件位于 `~/.config/subscription/bin/mihomo`，由安装脚本自动下载。

## 协议支持

| 协议 | 支持 | 说明 |
|------|------|------|
| vless | ✅ | 含 reality 流控 (xtls-rprx-vision) |
| vmess | ✅ | 含 ws/h2/grpc 传输 |
| trojan | ✅ | 含 ws/grpc 传输 |
| shadowsocks | ✅ | 含 base64 用户信息 |
| hysteria2 | ✅ | 含 obfs 混淆 |
| tuic | ✅ | 含 congestion-control |

## API 端点变更

| 旧端点 | 新端点 | 说明 |
|--------|--------|------|
| `GET /` → API 文档 | `GET /` → Web 仪表盘 (SSR) | 现在是可视化界面 |
| `GET /api/diagnose/subconverter` | `GET /api/diagnose/mihomo` | 诊断目标改为 mihomo |
| `subconverterRunning` | `mihomoAvailable` | 状态字段名变更 |

## 配置迁移

旧 `.env` 格式：
```bash
PORT=3000
SING_BOX_CONFIGS=vless,hysteria2,trojan,tuic,vmess
SUBCONVERTER_URL=http://localhost:25500
```

新 `config.yaml` 格式：
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
```

注意：
- `SUBCONVERTER_URL` 不再需要
- 端口默认值变为 3001
- 配置格式从 `.env` 变为 `config.yaml`

## 部署变更

旧流程：服务器上 `git clone` → `manage.sh setup` → 手动构建和部署。

新流程：GitHub Actions 自动构建 → SSH 推送产物 → `server-deploy.sh` 原子部署 → systemd 重启。

详见 [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md)。
