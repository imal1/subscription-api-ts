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
