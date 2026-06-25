---
name: project-architecture
description: MioBridge 项目架构决策及原因
metadata:
  type: project
---

# 项目架构决策

## 技术栈

- **后端框架**：Next.js Pages Router + Node.js runtime（standalone 输出）
- **转换引擎**：mihomo（clash-meta 内核），本地命令行调用
- **配置解析**：mikefarah/yq v4
- **前端**：React + Tailwind CSS + shadcn/ui（Botanical Garden 主题）
- **日志**：Winston
- **定时任务**：node-cron
- **部署**：systemd + Nginx + GitHub Actions（原子软链接切换）

## 关键架构决策

### 1. Next.js 全栈 SSR（2026-06 迁移）

从「Express 后端 + Next 静态导出前端」迁移为单一 Next.js 全栈应用。

**原因**：
- 双进程运维复杂，需分别管理端口和生命周期
- SSR 需要后端数据，双进程只能通过 HTTP 自调用，增加延迟
- `getServerSideProps` 同进程直接调用 service 单例，零网络开销
- standalone 输出支持单目录部署，一个入口启动全栈

**影响**：
- 所有后端逻辑在 `frontend/src/server/` 下，通过 `@/server/...` 引用
- API routes 是薄 handler，直接复用 service 层
- instrumentation.ts 负责启动初始化（node-cron、目录创建、二进制检查）

### 2. mihomo 本地命令行调用

使用 mihomo 而非 subconverter 作为转换引擎。

**原因**：
- 原生支持 vless reality、hysteria2、tuic 等新协议
- 本地命令行调用比 HTTP 调用 subconverter 更轻量
- 输出与 Clash Meta 内核完全兼容

**影响**：
- `mihomoService.ts` 封装所有 mihomo CLI 调用
- 需要 `~/.config/miobridge/bin/mihomo` 二进制文件

### 3. Service 单例模式

所有后端 service 使用 `getInstance()` 单例模式。

**原因**：
- 避免重复初始化（配置读取、二进制检测）
- 在 SSR 和 API routes 间共享同一实例
- 框架无关设计，service 不依赖 Next.js

**Service 列表**：
- `MioBridgeService` — 订阅转换编排
- `MihomoService` — mihomo CLI 封装
- `SingBoxService` — sing-box 节点提取
- `YamlService` — 配置解析和 YAML 操作

### 4. Pages Router 而非 App Router

2026-06 迁移时选择 Pages Router。

**原因**：
- App Router 的 `instrumentation.ts` Node runtime 稳定性不足
- `getServerSideProps` SSR 模式更成熟
- `output: 'standalone'` 在 Pages Router 下经过充分验证
- 未来可在 App Router 稳定后迁移

### 5. 外部文件 URL 兼容

`/subscription.txt`、`/clash.yaml`、`/raw.txt`、`/health` 这些外部 URL 通过 `next.config.js` 的 `rewrites` 映射到内部 API routes，保持与旧版客户端的兼容性。