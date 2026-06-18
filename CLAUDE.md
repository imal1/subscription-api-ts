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
      config/   ← 读取 ~/.config/subscription/config.yaml（经 yq），导出 config 单例
      services/ ← subscriptionService / mihomoService / singBoxService / yamlService（均为 getInstance 单例）
      utils/    ← winston logger
      types/
    pages/
      index.tsx                   ← getServerSideProps 直接调用 SubscriptionService.getStatus() → 首屏实时 SSR
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
- **配置来源**：`~/.config/subscription/config.yaml`，由 `yamlService` 经 `yq` 解析；缺失时回退默认值。数据/日志/备份目录均在 `~/.config/subscription` 下（绝对路径，与 cwd 无关）。
- **外部二进制**：`mihomo`、`yq`、`sing-box`，优先 `~/.config/subscription/bin/`，否则回退 `process.cwd()/bin` 或系统 PATH。
- 对外文件下载 URL `/subscription.txt`、`/clash.yaml`、`/raw.txt`、`/health` 通过 `next.config.js` 的 `rewrites` 映射到内部 API，保持兼容。

## 开发命令
```bash
bun install                 # 安装依赖（workspace，依赖提升到仓库根 node_modules）
bun run dev                 # = cd frontend && next dev -p 3001（本地开发，含 SSR + API）
bun run build               # = next build（产出 .next/standalone）
bun run start               # node frontend/.next/standalone/frontend/server.js
bun run lint                # oxlint frontend/src
```
本地需要可用的 `mihomo`/`yq`（放在 `~/.config/subscription/bin/`）；`sing-box` 缺失时仪表盘仍可渲染，仅显示「不可访问」。

## 生产部署（Linux，Node 运行时）
- 由 `scripts/manage.sh install` 驱动：构建 → 将 `.next/standalone` 整树复制到 `$DIST_DIR`（`~/.config/subscription/dist`），入口为 `$DIST_DIR/frontend/server.js`。
- systemd 单元用 **node** 运行 `server.js`（`Environment=PORT=<api_port> HOSTNAME=0.0.0.0 NODE_ENV=production`）。模板见 `config/subscription-api-ts.service.template`。
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
