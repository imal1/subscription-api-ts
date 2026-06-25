# CLAUDE.md

本文件为 Claude Code / 协作者提供本仓库的工作约定与架构说明。

## 项目定位

TypeScript 订阅转换服务：基于 **Mihomo** 内核，将多协议节点（vless/vmess/trojan/hysteria2/tuic/ss）转换为 Clash 配置，并提供一个仪表盘查看状态、触发更新、在线转换。

## 架构（2026-06 起：Next.js 全栈 SSR）

项目已从「Express 后端 + Next 静态导出前端」**完整迁移为单一 Next.js 全栈应用**（Pages Router，Node runtime，`output: 'standalone'`）。不再有独立的 Express 进程。

```
frontend/                         ← 唯一应用（Node 运行 next start / standalone server.js）
  next.config.js                  ← output:'standalone' + rewrites + outputFileTracingRoot(指向仓库根)
  src/
    instrumentation.ts            ← 启动钩子入口；仅 nodejs runtime 动态加载 instrumentation-node
    instrumentation-node.ts       ← 真正的初始化：ensureDirectories + mihomo/sing-box 检查 + node-cron 自动更新
    server/                       ← 框架无关的后端逻辑（从原 Express 迁入，直接复用）
      config/   ← 读取 ~/.config/miobridge/config.yaml（经 yq），导出 config 单例
      services/ ← mioBridgeService / mihomoService / singBoxService / yamlService（均为 getInstance 单例）
      utils/    ← winston logger
      types/
    pages/
      index.tsx                   ← getServerSideProps 直接调用 MioBridgeService.getStatus() → 首屏实时 SSR
      api/                        ← 由原 Express controller 改写的薄 handler，复用 server/services
        status.ts update.ts convert.ts configs.ts health.ts
        diagnose/mihomo.ts  test/protocols.ts  file/[name].ts
        yaml/{validate,frontend,config,generate}.ts
    components/                   ← Dashboard(接收 initialStatus)、ConvertModal、ui/*
    lib/                          ← 前端 API 客户端（ky）：api.ts / configApi.ts
```

### 关键约定
- **后端 service 是框架无关单例**：用 `XxxService.getInstance()`，通过 `@/server/...` 引用。新增后端能力优先加到 service 层，再用一个薄 API route 暴露。
- **SSR 数据**：页面首屏数据在 `getServerSideProps` 内**同进程直接调用 service**（不要自打 HTTP）。客户端组件保留 30s 轮询做实时刷新。
- **node 专属模块**（path/fs/child_process/winston/node-cron）只能在 server/、api/、instrumentation-node 中使用；`instrumentation.ts` 必须用 `NEXT_RUNTIME === 'nodejs'` 守卫后再动态 import，避免 Edge 编译失败。
- **定时任务**在 `instrumentation-node.ts` 用 node-cron 注册（`config.autoUpdateCron`，时区 Asia/Shanghai）。
- **配置来源**：`~/.config/miobridge/config.yaml`，由 `yamlService` 经 `yq` 解析；缺失时回退默认值。数据/日志/备份目录均在 `~/.config/miobridge` 下（绝对路径，与 cwd 无关）。
- **外部二进制**：`mihomo`、`yq`、`sing-box`，优先 `~/.config/miobridge/bin/`，否则回退 `process.cwd()/bin` 或系统 PATH。
- 对外文件下载 URL `/subscription.txt`、`/clash.yaml`、`/raw.txt`、`/health` 通过 `next.config.js` 的 `rewrites` 映射到内部 API，保持兼容。

## 开发命令
```bash
bun install                 # 安装依赖（workspace，依赖提升到仓库根 node_modules）
bun run dev                 # = cd frontend && next dev -p 3001（本地开发，含 SSR + API）
bun run build               # = next build（产出 .next/standalone）
bun run start               # node frontend/.next/standalone/frontend/server.js
bun run lint                # oxlint frontend/src
```
本地需要可用的 `mihomo`/`yq`（放在 `~/.config/miobridge/bin/`）；`sing-box` 缺失时仪表盘仍可渲染，仅显示「不可访问」。

## 生产部署（Linux，Node 运行时）
- 由 `scripts/manage.sh install` 驱动：构建 → 将 `.next/standalone` 整树复制到 `$DIST_DIR`（`~/.config/miobridge/dist`），入口为 `$DIST_DIR/frontend/server.js`。
- systemd 单元用 **node** 运行 `server.js`（`Environment=PORT=<api_port> HOSTNAME=0.0.0.0 NODE_ENV=production`）。模板见 `config/miobridge.service.template`。
- nginx 把所有请求（`/`、`/api/*`、`/_next/*`、文件下载）反代到 Next 单进程；模板见 `config/nginx.conf.template`。订阅文件可由 nginx 直接从 `$DATA_DIR` 提供以加速。
- standalone 不自动包含 `.next/static` 与 `public`，构建脚本（`scripts/lib/build.sh`）会手动拷入运行目录——改动构建流程时务必保留这一步。

## 注意
- 修改后端 service 后，dev 模式下若动到 `instrumentation*` 需重启 dev server。
- `next build` 在 monorepo 下会因多 lockfile 警告而误选 tracing 根，已通过 `outputFileTracingRoot` 固定到仓库根，勿删。

## Design System（2026-06：Botanical Garden）

项目采用 **Botanical Garden** 主题（源自 theme-factory），扁平化设计，强调清爽、有机的视觉感受。

### 色彩

| Token | Hex | 用途 |
|---|---|---|
| `--fern` | `#4a7c59` | 主色、成功状态、活跃指示器 |
| `--marigold` | `#f9a620` | 强调色、警告状态 |
| `--terracotta` | `#b7472a` | 危险/错误状态 |
| `--cream` | `#f5f3ed` | 浅色背景基色 |
| `--ink` | `#1a1d1a` | 正文色（浅色模式） |

CSS 变量以语义化 tokens 暴露（`--primary`, `--secondary`, `--accent`, `--destructive`, `--background` 等），分别映射到上述园艺色板。暗色模式通过 `.dark` class 激活（`--background: #1a221c`, `--card: #222b25`, `--primary: #8faa95` 等）。完整定义在 [globals.css](frontend/src/styles/globals.css)。

### 排版

| 角色 | 字体 |
|---|---|
| Display / 标题 | Georgia, Times New Roman, serif (`--font-display`) |
| Body / UI | -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif (`--font-body`) |
| 代码 / 数据 | JetBrains Mono, SF Mono, Cascadia Code, monospace (`--font-mono`) |

### 组件约定

- **Card**: 圆角 12px（`--radius-lg`），`1px solid var(--border)` 边框，`var(--shadow-card)` 阴影，hover 时阴影增强到 `var(--shadow-card-hover)`。使用 CSS class `garden-card`。
- **Button**: 圆角 8px（`rounded-lg`），内置 `active:scale-[0.98]` 按压反馈。Primary 按钮使用 `backgroundColor: var(--primary), color: var(--primary-foreground)`（Tailwind 类可能被 CSS 变量压低特异性时用 inline style 兜底）。
- **StatCard**: 卡片 + 左边 3px 彩色条（fern/marigold/terracotta/info），内用 `font-display` 显示大数值，`muted-foreground` 显示标签和副文本。
- **SectionHeading**: 底部 `4px` fern 色短装饰线（`.section-rule`），标题用 `font-display` + `font-semibold`。
- **StatusBadge**: 小圆角 chip，配 `live-dot`（8px 圆点，活跃时 fern 色带 `pulse-dot` 呼吸动画）。
- **Alert/Toast**: `.garden-alert` + variant class（`garden-alert-success`/`danger`），`slideUp` 入场动画。
- **Table**: `.garden-table`，左对齐，uppercase header，hover 行高亮。
- **Dialog**: 圆角 16px（`rounded-2xl`），`var(--card)` 背景 + `var(--border)` 边框。

### 动画

- **入场编排**: `.stagger-slide-up` 父容器，子元素依次 `slideUp`（0.4s cubic-bezier，60ms stagger，最多 8 层）。
- **呼吸**: `.animate-breathe`（3s ease-in-out opacity 循环），用于加载指示器。
- **标题装饰线**: `.animate-grow-line`（从 `scaleX(0)` 滑入，0.6s cubic-bezier）。
- **植物图标**: `animation: sway 4s ease-in-out infinite`（±1.5deg 轻摆）。
- **活跃状态点**: `live-dot-active`（`pulse-dot` 2s 扩散动画）。
- **按压反馈**: 所有按钮 `active:scale-[0.98]`。
- 所有动画在 `prefers-reduced-motion: reduce` 时禁用。

### 暗色模式

- 自动检测 `prefers-color-scheme: dark`（通过 `ThemeProvider` 中的 `matchMedia` 监听）。
- 手动切换按钮（`ThemeToggle`）：`ph:moon-bold` / `ph:sun-bold` 图标，旋转过渡。
- 偏好持久化到 `localStorage` key `subscription-dashboard-theme`。
- Monaco Editor 在 `ConvertModal` 中跟随主题切换 `vs` / `vs-dark`。

### 图标

使用 `@iconify/react` 的 Phosphor 图标集（`ph:` 前缀）。优先 Bold 变体（`ph:xxx-bold`）用于状态指示，Regular（`ph:xxx`）用于按钮和装饰。

### 不做什么

- 不使用 `bg-gray-50`、`text-gray-900` 等 Tailwind 颜色类——始终使用 CSS 变量（`var(--xxx)`）或语义 utility，确保暗色模式自动适配。
- 不写 `shadow-sm`/`shadow-md`——使用 `var(--shadow-card)` 等 token。
- 不引入第三方 CSS 框架之外的样式方案。
- 不在组件中硬编码色值——使用 token 或 CSS 变量。

## 项目决策记录

本节记录关键架构决策及其原因，帮助 AI 和贡献者理解"为什么这样做"而不仅是"怎么做的"。

### 为什么从 Express + Next 静态导出迁移到 Next.js 全栈 SSR？

**决策**（2026-06）：将 Express 后端和 Next.js 前端合并为单一 Next.js 全栈应用（Pages Router，`output: 'standalone'`）。

**原因**：
- 双进程（Express + Next）增加运维复杂度，需要分别管理端口和生命周期
- SSR 需要后端数据，双进程架构下只能通过 HTTP 自调用获取首屏数据，增加延迟
- `getServerSideProps` 同进程直接调用 service 单例，零网络开销
- standalone 输出模式支持单目录部署，`server.js` 一个入口启动全栈

### 为什么用 mihomo 而非 subconverter？

**决策**：使用 mihomo（clash-meta 内核）作为转换引擎，而非 subconverter。

**原因**：
- mihomo 原生支持 vless reality、hysteria2、tuic 等新协议，subconverter 对这些协议支持不完整
- 本地命令行调用（`child_process.exec`）比 HTTP 调用 subconverter 更轻量，无网络开销
- mihomo 输出 Clash 配置格式与 Clash Meta 内核完全兼容，无需二次处理
- 项目只需要转换功能，不需要 subconverter 的完整功能集

### 为什么用 yq 而非 js-yaml？

**决策**：使用 mikefarah/yq v4 命令行工具解析和生成 YAML，而非 Node.js YAML 库。

**原因**：
- sing-box 配置格式复杂，包含多文档和特殊语法，yq 对此处理更可靠
- yq 的 `eval` 和 `-o yaml` 组合能精确控制 YAML 输出格式
- 命令行调用模式与 mihomo 一致，保持外部工具调用的一致性
- **教训**：yq v4 默认 `eval -P` 输出 JSON 而非 YAML，必须显式加 `-o yaml`（v0.1 bug #1）

### 为什么用 Pages Router 而非 App Router？

**决策**（2026-06 迁移时）：使用 Next.js Pages Router 而非 App Router。

**原因**：
- 迁移时 App Router 的 `instrumentation.ts` 在 Node runtime 下的稳定性不足
- Pages Router 的 `getServerSideProps` 模式对 SSR 数据注入更成熟
- `output: 'standalone'` 在 Pages Router 下经过充分验证
- 未来可在 App Router 稳定性提升后考虑迁移

## 常见问题排查

基于 v0.1 开发经验和 `TROUBLESHOOTING.md` 提炼的快速排查指南。

### clash.yaml 不生成

**症状**：`/clash.yaml` 返回 404，仪表盘"Clash 配置"卡片显示"未生成"。

**原因**：yq 默认 `eval -P` 输出 JSON 而非 YAML，导致 YAML 生成失败。

**解决**：确保 yq 命令使用 `-o yaml` 参数。已在 v1.1.0 修复（commit `f387663`）。

**验证**：
```bash
~/.config/miobridge/bin/yq --version  # 应为 mikefarah/yq v4.x
curl -s http://localhost:3001/api/update | python3 -m json.tool
ls -la ~/.config/miobridge/www/clash.yaml
```

### 仪表盘状态轮询丢失

**症状**：仪表盘首次加载正常，30 秒后所有状态变为"未生成"、节点数变为 0。

**原因**：API 响应包含 `{ success, data }` 包装，但客户端 `api.ts` 未解包 `data` 字段。

**解决**：在 `frontend/src/lib/api.ts` 中对 API 响应进行 `response.data` 解包。已在 v1.1.0 修复。

### 部署版本不可见

**症状**：无法确认服务器运行的是哪个 commit。

**原因**：构建时未注入 commit hash。

**解决**：在 GitHub Actions 构建环境中设置 `NEXT_PUBLIC_GIT_COMMIT=${{ github.sha }}`，仪表盘页脚自动显示。

### 服务启动失败

**诊断**：
```bash
sudo systemctl status miobridge
sudo journalctl -u miobridge -n 50 --no-pager
ss -tlnp | grep 3001
```

**常见原因**：
- 端口被占用 → 修改 `config.yaml` 中 `app.port` 或终止占用进程
- 二进制缺失 → 确保 `~/.config/miobridge/bin/` 下有 `mihomo`、`yq`
- 权限问题 → `sudo chown -R $USER:$USER ~/.config/miobridge/`

### GitHub Actions 部署失败

| 错误 | 原因 | 解决 |
|------|------|------|
| `Permission denied (publickey)` | SSH key 问题 | 检查 `DEPLOY_SSH_KEY` secret |
| `sudo: a password is required` | NOPASSWD 未配置 | `sudo visudo -f /etc/sudoers.d/miobridge-deploy` |
| `Host key verification failed` | known_hosts 缺失 | 更新 `DEPLOY_KNOWN_HOSTS` secret |
| 健康检查超时回滚 | 服务未正常启动 | `journalctl -u miobridge -n 200` |

### 手动回滚

```bash
cd ~/.config/miobridge
ls -lt releases/
ln -sfn releases/<旧版本目录名> dist
sudo systemctl restart miobridge
```

## 外部依赖说明

### mihomo (clash-meta 内核)

- **用途**：订阅转换核心引擎，将节点列表转换为 Clash 配置
- **版本要求**：clash-meta 1.18.x+（需支持 vless reality、hysteria2、tuic）
- **获取方式**：从 [MetaCubeX/mihomo releases](https://github.com/MetaCubeX/mihomo/releases) 下载对应架构二进制
- **部署位置**：`~/.config/miobridge/bin/mihomo`
- **调用方式**：`child_process.exec('mihomo ...')`，本地命令行，无 HTTP 开销
- **降级行为**：不可用时订阅更新失败，仪表盘显示错误状态

### yq (mikefarah/yq v4)

- **用途**：解析 `config.yaml` 和操作 YAML 输出
- **版本要求**：v4.x（v3 不兼容，语法不同）
- **获取方式**：`wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64`
- **部署位置**：`~/.config/miobridge/bin/yq`
- **关键用法**：
  - `yq eval '.key' config.yaml` — 读取值
  - `yq eval -o yaml '.' input` — 确保 YAML 输出（非 JSON）
- **降级行为**：不可用时服务无法启动（config 解析失败）

### sing-box

- **用途**：代理节点管理，提供节点 URL 和配置信息
- **版本要求**：1.8.x+（需支持 vless reality）
- **获取方式**：从 [SagerNet/sing-box releases](https://github.com/SagerNet/sing-box/releases) 下载
- **部署位置**：系统 PATH 或 `~/.config/miobridge/bin/sing-box`
- **调用方式**：`child_process.exec('sing-box ...')`
- **降级行为**：不可用时仪表盘仍可渲染，但 sing-box 相关功能显示"不可访问"

## 环境变量速查

### 构建时变量（`NEXT_PUBLIC_*`）

| 变量 | 用途 | 设置方式 |
|------|------|---------|
| `NEXT_PUBLIC_GIT_COMMIT` | 仪表盘页脚显示 commit hash | GitHub Actions 自动注入 `${{ github.sha }}` |

### GitHub Actions Secrets

| Secret | 必填 | 说明 | 示例 |
|--------|------|------|------|
| `DEPLOY_HOST` | ✅ | 服务器地址 | `1.2.3.4` |
| `DEPLOY_USER` | ✅ | SSH 登录用户 | `imali` |
| `DEPLOY_SSH_KEY` | ✅ | 部署专用 SSH 私钥 | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `DEPLOY_KNOWN_HOSTS` | 推荐 | 服务器 host key | `ssh-keyscan -H <host>` 输出 |
| `DEPLOY_PORT` | 否 | 自定义 SSH 端口（默认 22） | `2222` |
| `DEPLOY_BASE_DIR` | 否 | 部署根目录（默认 `~/.config/miobridge`） | `/opt/subscription` |

### 生产环境变量（systemd）

| 变量 | 值 | 说明 |
|------|-----|------|
| `PORT` | `config.yaml` 中 `app.port` | 服务端口 |
| `HOSTNAME` | `0.0.0.0` | 监听地址 |
| `NODE_ENV` | `production` | 运行模式 |

## 数据流图

```
┌─────────────┐
│  sing-box   │  多个配置（vless, hysteria2, trojan, tuic, vmess）
│  configs    │
└──────┬──────┘
       │ singBoxService.getAllConfigUrls()
       │ child_process.exec('sing-box ...')
       ▼
┌─────────────┐
│  节点 URL    │  从 sing-box 输出中正则提取代理 URL
│  提取       │  (vless://..., vmess://..., trojan://..., hy2://..., tuic://...)
└──────┬──────┘
       │ mioBridgeService.extractAndConvert()
       ▼
┌─────────────┐
│   mihomo    │  child_process.exec('mihomo convert ...')
│   转换      │  输入：节点 URL 列表
│             │  输出：Clash 格式 YAML
└──┬──┬──┬────┘
   │  │  │
   │  │  └──→ raw.txt          原始节点列表（每行一个 URL）
   │  │
   │  └─────→ subscription.txt  Base64 编码的节点列表（订阅格式）
   │
   └────────→ clash.yaml        Clash 配置文件（YAML 格式）

┌─────────────┐
│  Next.js     │  getServerSideProps → MioBridgeService.getStatus()
│  SSR         │  首屏数据同进程直接调用 service，不经过 HTTP
│  仪表盘      │  客户端 30s 轮询 /api/status 保持实时
└─────────────┘
```

## GitHub Actions 集成

项目使用三个 GitHub Actions workflow 构成完整的 CI/CD 流水线：

### ci.yml — PR 门禁
- **触发**：PR 到 `main` 分支
- **流程**：`lint (oxlint)` → `typecheck (tsc --noEmit)` → `build (next build)`
- **结果**：全部通过才允许 merge

### deploy.yml — 自动部署
- **触发**：push 到 `main` 分支 + `workflow_dispatch` 手动触发
- **流程**：Checkout → Setup Bun/Node → Install → Build → Assemble → Pack → SSH Deploy → Health Check → Summary
- **部署原理**：原子软链接切换（`dist → releases/<id>`）+ 健康检查 + 失败自动回滚
- **本地触发**：`gh workflow run deploy.yml` 或 `/miobridge:deploy`

### health-check.yml — 定时监控
- **触发**：`cron: "*/5 * * * *"` 每 5 分钟 + `workflow_dispatch` 手动
- **流程**：SSH → `curl /api/health` → 失败则 `systemctl restart` + 二次检查 → 报告
- **告警**：GitHub Step Summary 记录每次检查结果

### 本地与 CI 的协作

```bash
# 本地触发部署
gh workflow run deploy.yml --ref main

# 查看部署状态
gh run watch $(gh run list -w deploy.yml -L1 --json databaseId -q '.[0].databaseId')

# 查看健康检查历史
gh run list -w health-check.yml -L5
```

## 开发命令

## 记忆维护

`.claude/memory/` 目录包含持久化的项目记忆文件。每次完成以下操作后，必须更新对应的记忆文件：

| 操作 | 更新文件 | 更新方式 |
|------|---------|---------|
| 修复 bug | `.claude/memory/bug-fixes.md` | 在文件顶部追加新条目（日期、症状、原因、修复） |
| 架构决策 / 技术选型变更 | `.claude/memory/project-architecture.md` | 追加新的决策条目 |
| CI/CD workflow 变更 | `.claude/memory/ci-cd-pipeline.md` | 更新对应章节 |
| 部署流程变更 | `.claude/memory/deployment-flow.md` | 更新对应章节 |
| 配置约定变更 | `.claude/memory/config-patterns.md` | 更新对应配置项 |
| 代码风格 / lint 规则变更 | `.claude/memory/coding-conventions.md` | 更新对应约定 |

### 更新格式

记忆文件使用 frontmatter 格式：
```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary>
metadata:
  type: project
---
```

索引文件 `.claude/memory/MEMORY.md` 维护所有记忆文件的链接列表。新增记忆文件时同步更新索引。
