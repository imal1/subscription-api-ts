# Project Structure

本文档描述 Subscription API TS 的目录结构和代码组织。

## 整体架构

项目是单一 Next.js 全栈应用（Pages Router，`output: 'standalone'`），没有独立的 Express 后端。后端逻辑在 `frontend/src/server/` 下，以框架无关的单例 service 形式组织。

```
miobridge/
├── frontend/                              # Next.js 全栈应用（唯一应用）
│   ├── src/
│   │   ├── server/                        # 后端逻辑（框架无关）
│   │   │   ├── config/index.ts            # 配置管理（读取 config.yaml）
│   │   │   ├── services/                  # 业务服务（单例模式）
│   │   │   │   ├── mioBridgeService.ts # 订阅更新 + 状态查询
│   │   │   │   ├── mihomoService.ts       # mihomo 转换 + 协议解析
│   │   │   │   ├── singBoxService.ts      # sing-box 交互
│   │   │   │   └── yamlService.ts         # YAML 配置管理
│   │   │   ├── types/index.ts             # TypeScript 类型定义
│   │   │   ├── utils/logger.ts            # Winston 日志
│   │   │   └── version.ts                 # 版本号（从 package.json）
│   │   ├── pages/                         # Next.js 页面 & API 路由
│   │   │   ├── index.tsx                  # 仪表盘首页 (SSR)
│   │   │   ├── actions.tsx                # 操作页面
│   │   │   ├── api-docs.tsx               # API 文档页面
│   │   │   ├── _app.tsx                   # Next.js App 入口
│   │   │   └── api/                       # API 路由
│   │   │       ├── health.ts
│   │   │       ├── status.ts
│   │   │       ├── update.ts
│   │   │       ├── convert.ts
│   │   │       ├── configs.ts
│   │   │       ├── file/[name].ts
│   │   │       ├── diagnose/mihomo.ts
│   │   │       ├── test/protocols.ts
│   │   │       └── yaml/*.ts
│   │   ├── components/                    # React 组件
│   │   │   ├── Dashboard.tsx              # 仪表盘主组件
│   │   │   ├── ConvertModal.tsx           # 在线转换弹窗
│   │   │   ├── ThemeProvider.tsx          # 主题管理
│   │   │   ├── ThemeToggle.tsx            # 主题切换按钮
│   │   │   ├── layout/                    # 布局组件
│   │   │   │   ├── AppLayout.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   ├── MobileHeader.tsx
│   │   │   │   └── MobileDrawer.tsx
│   │   │   ├── shared/                    # 共享组件
│   │   │   │   ├── StatCard.tsx
│   │   │   │   ├── StatusBadge.tsx
│   │   │   │   ├── SectionHeading.tsx
│   │   │   │   ├── InfoRow.tsx
│   │   │   │   └── MethodBadge.tsx
│   │   │   └── ui/                        # 基础 UI 组件 (shadcn/ui)
│   │   ├── context/AppContext.tsx          # 全局状态
│   │   ├── lib/
│   │   │   ├── api.ts                     # API 客户端 (ky)
│   │   │   ├── configApi.ts               # 配置 API
│   │   │   └── utils.ts                   # 工具函数
│   │   ├── styles/globals.css             # 全局样式 (Botanical Garden)
│   │   └── instrumentation*.ts            # 启动钩子 (node-cron)
│   ├── next.config.js                     # standalone + rewrites + env
│   └── package.json                       # 前端依赖
├── scripts/
│   ├── server-deploy.sh                   # 原子部署脚本（CI 调用）
│   ├── manage.sh                          # 服务器管理脚本
│   └── lib/                               # 脚本库
├── config/
│   ├── nginx.conf.template                # Nginx 配置模板
│   └── miobridge.service.template # systemd 单元模板
├── .github/workflows/deploy.yml           # GitHub Actions 部署
├── agent/                                 # 远程节点 Agent 子包
├── docs/
│   ├── DEPLOYMENT.md                      # 部署指南
│   ├── CI-CD.md                           # CI/CD 流水线说明
│   └── superpowers/remaining-gaps.md      # 尚未落地的 Agent 生命周期缺口
├── CHANGELOG.md                           # 变更日志
├── TROUBLESHOOTING.md                     # 故障排除
├── MIGRATION_TO_MIHOMO.md                 # mihomo 迁移指南（历史）
├── package.json                           # 根 monorepo 配置
└── tsconfig.json                          # TypeScript 配置
```

## 关键目录说明

### `frontend/src/server/`

框架无关的后端逻辑。所有 service 均为单例（`getInstance()`），API 路由是薄 handler 层，直接调用 service。

### `frontend/src/pages/api/`

Next.js API 路由。每个文件对应一个端点，通过 `@/server/services/` 引用后端 service。API 响应统一包装为：

```json
{ "success": true, "data": <payload>, "timestamp": "..." }
```

### `scripts/server-deploy.sh`

自包含的原子部署脚本，由 GitHub Actions 通过 SSH 调用。流程：解压 → 软链接切换 → systemctl restart → 健康检查 → 失败回滚。

### `.claude/`

AI 辅助开发相关文件：
- `CLAUDE.md` — 项目架构和约定的完整说明
- `roadmap/` — 从 v0.1 到 v1.0 的开发路线图

## 运行时目录

部署后服务器上的目录结构：

```
~/.config/miobridge/
├── config.yaml          # 主配置文件
├── dist → releases/<id> # 软链接 → 当前版本
├── releases/            # 历史版本
├── www/                 # 静态文件（订阅文件、Clash 配置）
│   ├── subscription.txt
│   ├── clash.yaml
│   └── raw.txt
├── log/                 # 日志文件
├── backup/              # 订阅备份
├── bin/                 # 外部二进制（mihomo, yq）
│   ├── mihomo
│   └── yq
└── mihomo/              # mihomo 配置目录
```

## 文件命名约定

- TypeScript/TSX：`camelCase.ts` / `camelCase.tsx`
- 配置文件：`kebab-case.yaml`
- Shell 脚本：`kebab-case.sh`
- 文档：`UPPER_CASE.md`
- Service 模板：`kebab-case.service`
