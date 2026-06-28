# Changelog

本文档记录 Subscription API TS 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，版本号遵循语义化版本规范。

## [1.2.0] — 2026-06-28

### Added
- **零接触多节点部署（Agent）**：Agent 子包（`agent/`），含 HTTP 服务器（`/api/status`、`/api/update`、`/api/health`）、配置解析、Linux amd64/arm64 构建脚本
- **DeployManager 服务**：SSH 远程部署管理，支持节点注册、代理生命周期、内核管理
- **节点 SSH 类型**：`NodeSshConfig`、`NodeAgentInfo`、`NodeKernelInfo` 类型定义
- **CLI 部署命令**：`deploy`、`deploy:status`、`deploy:rollback` 等命令行工具
- **UpdateChecker 服务**：版本检查与自动更新管理
- **部署 UI 组件**：`AddNodeForm`（添加节点表单）、`DeployProgressDialog`（部署进度弹窗）、节点详情中的 Agent 信息区域、Agent 生命周期按钮
- **部署相关 API**：`/api/deploy/*`、`/api/agent/*`、`/api/kernel/*` 端点
- SSH 完成设计文档与实现计划

### Fixed
- **Vitest JSX 解析失败**：`tsconfig.json` 使用 `jsx: "preserve"`（Next.js 要求），vitest 的 esbuild 无法解析 JSX。添加 `@vitejs/plugin-react` 插件用 Babel 处理 JSX 转换，同时排除 `../agent/**` 下的 Bun 专用测试。修复后 162 个测试全部通过（之前 3 个文件、7 个测试失败）

## [1.1.0] — 2026-06-24

### Added
- 开发路线图（`.claude/roadmap/`），规划 v0.2 ~ v1.0
- 部署版本可见性：仪表盘页脚显示 git commit hash 和构建时间
- 统一版本号来源：`server/version.ts` 从 `package.json` 读取
- `gitCommit` 和 `buildTime` 字段加入 `/api/status` 响应

### Fixed
- **仪表盘状态轮询丢失**：`api.ts` 的 `getStatus()` 和 `updateSubscription()` 未解包 API 响应的 `data` 字段，导致 30s 轮询后所有状态显示"未生成"/0
- **clash.yaml 永远无法生成**：`mihomoService.ts` 中 `yq eval -P` 输出 JSON 而非 YAML，缺少 `-o yaml` 参数
- 版本号不一致：三处硬编码版本号统一为 `package.json` 的 `version`

### Changed
- `mioBridgeService.getStatus()` 返回类型从 `Promise<any>` 改为 `Promise<StatusInfo>`
- `next.config.js` 注入 `NEXT_PUBLIC_GIT_COMMIT` 和 `NEXT_PUBLIC_BUILD_TIME`
- `/api/health` 和 `config/index.ts` 的默认版本号改为从 `version.ts` 读取

## [1.0.0] — 2026-06-18

### Added
- 完整迁移到 Next.js 全栈架构（Pages Router + standalone 输出）
- Web 仪表盘（Botanical Garden 主题，SSR + 30s 客户端轮询）
- 原子部署：`server-deploy.sh` + GitHub Actions SSH 推送
- mihomo 转换内核替代 subconverter
- 协议解析：vless (含 reality)、vmess、trojan、hysteria2、tuic、shadowsocks
- 定时订阅更新（node-cron）
- Winston 结构化日志
- `config.yaml` 配置管理（经 yq 解析）
- API 端点：`/api/health`、`/api/status`、`/api/update`、`/api/convert`、`/api/configs`
- 文件端点：`/subscription.txt`、`/clash.yaml`、`/raw.txt`
- `CLAUDE.md` 项目文档（架构说明、开发命令、设计系统）

## [0.x] — 2026-06 之前

### Added
- TypeScript + Express.js 初始架构
- subconverter 集成
- systemd 服务管理
- Nginx 反代配置
- 基础订阅转换功能
