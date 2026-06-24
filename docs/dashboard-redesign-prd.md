# Product Requirements Document: MioBridge 仪表盘重构

**Version**: 1.1
**Date**: 2026-06-18
**Author**: Sarah (Product Owner)
**Quality Score**: 93/100
**Status**: Ready for Development

---

## Executive Summary

将 MioBridge 仪表盘从「单页长滚动全部模块」重构为**侧边栏导航 + 多页面路由**架构（Next.js Pages Router），并加入**呼吸折叠、导航指示器弹跳滑动、内容区编排入场**三层协同动画。核心目标是让小团队用户打开首页就能一览所有关键状态，同时通过可折叠侧边栏在 3 个功能页面间流畅切换。

关键指标：
- 状态概览 6 项核心指标在首屏**无需滚动**即可看完
- 从进入页面到完成"更新并下载"操作的点击次数 ≤ 3
- 侧边栏折叠切换在 300ms 内完成（弹性缓出）

---

## Problem Statement

**Current Situation**: 当前 Dashboard 将所有模块（4 张状态卡片 + 服务状态 + 文件信息 + 6 个操作按钮 + API 端点表格）都堆在一个长页面上。用户需要滚动才能看到不同区域的全部内容。状态、操作、文档三类信息混杂，缺乏明确的视觉层级。

**Proposed Solution**: 重构为侧边栏导航布局，按功能域分页，并加入三层动画系统：
- **仪表盘**（首页 `/`）：状态概览 4 卡片 + 服务状态 + 文件信息 — 一屏尽收
- **操作**（`/actions`）：更新订阅、下载文件、刷新状态等操作集合
- **API 文档**（`/api-docs`）：端点表格独立展示
- **订阅转换**（任何页面可按需打开）：ConvertModal 弹框

**Business Impact**: 小团队成员各取所需 — 有人只看仪表盘确认状态，有人去操作页执行任务，无需在冗长页面中定位目标。

---

## Success Metrics

**Primary KPIs:**
- **首屏信息完整度**: 仪表盘页 Contentful Paint 时所有 6 个核心指标可见
- **操作效率**: "更新订阅"操作从进入仪表盘到触发 ≤ 2 次点击
- **动画性能**: 侧边栏折叠/展开 + 页面切换过渡在 60fps 运行（无掉帧）

**Validation**: 部署后在桌面端（1280px+）和移动端（375px）分别验证首屏可见性和动画流畅度。

---

## User Personas

### Primary: 运维管理员
- **Role**: 负责维护订阅转换服务的团队成员
- **Goals**: 快速确认服务健康状态，偶尔更新订阅、下载配置文件
- **Pain Points**: 当前页面需要滚动才能找到操作按钮；状态和操作混在一起
- **Technical Level**: Intermediate — 理解代理协议和 API 概念

### Secondary: 配置调试者
- **Role**: 偶尔需要测试转换结果的团队成员
- **Goals**: 粘贴原始链接，查看转换后的 YAML 输出，调试配置
- **Pain Points**: ConvertModal 在长页面底部，不够显眼
- **Technical Level**: Advanced — 熟悉 YAML 和代理协议

---

## User Stories & Acceptance Criteria

### Story 1: 打开首页立即掌握全局状态

**As a** 运维管理员
**I want to** 打开仪表盘首页就能看到所有关键服务的运行状态
**So that** 我不用滚动就能确认一切正常

**Acceptance Criteria:**
- [ ] 首页展示 4 张状态卡片（订阅文件 / Clash 配置 / 节点数量 / 运行时间），桌面端一横排排列
- [ ] 下方并行展示"核心服务"和"文件信息"两张卡片
- [ ] 所有数据在 SSR 首屏 HTML 中已存在（非客户端加载后填充）
- [ ] 30 秒自动轮询继续生效，静默刷新数据
- [ ] 首次进入时 StatCard 按 stagger-slide-up 依次入场

### Story 2: 通过侧边栏在多页面间切换（含动画）

**As a** 运维管理员
**I want to** 通过可折叠侧边栏在不同功能页面间快速切换
**So that** 我可以专注当前任务，不被其他内容干扰

**Acceptance Criteria:**
- [ ] 侧边栏包含 4 个导航项：仪表盘、操作、API 文档 + 底部折叠按钮 (ph:sidebar)
- [ ] 桌面端默认展开（240px），点击折叠按钮缩小为图标模式（64px），动画弹性缓出 300ms
- [ ] 活跃导航项指示器：前端绿色小圆点弹跳滑入 + 文字颜色 fern 化 + 背景微亮，过渡 200ms ease-out
- [ ] 折叠模式下导航项仅显示图标 + tooltip 提示
- [ ] 点击导航项通过 `next/link` 切换页面，内容区 `fadeIn` 入场
- [ ] 移动端侧边栏收起为顶部汉堡菜单，点击展开全屏抽屉（从左侧滑入，200ms cubic-bezier）

### Story 3: 在操作页面集中执行管理操作

**As a** 运维管理员
**I want to** 在操作页面执行更新、下载、转换等操作
**So that** 操作区域有足够空间展示操作进度和结果

**Acceptance Criteria:**
- [ ] 更新订阅按钮 + 进度动画（更新中 / 完成 / 失败状态）
- [ ] 更新完成后展示结果摘要（节点数、Clash 生成状态、备份信息）
- [ ] 下载文件区：3 个下载卡片（subscription.txt / clash.yaml / raw.txt），各显示文件大小和更新时间
- [ ] "在线转换"按钮打开 ConvertModal（弹框入场 scale + 背景模糊扩散）
- [ ] 操作结果保留到 React Context，跨页面切换不清除

### Story 4: API 文档独立展示

**As a** 配置调试者
**I want to** 查看完整的 API 端点列表和快速测试
**So that** 我可以快速了解可用接口并测试

**Acceptance Criteria:**
- [ ] API 端点表格：方法 Badge + 端点路径 + 描述 + 操作按钮
- [ ] 每个端点有"测试"或"下载"按钮可直接触发
- [ ] HTTP 方法 Badge 用不同颜色区分（GET: fern, POST: marigold）
- [ ] 表格 hover 行背景过渡 (muted) 150ms

---

## Animation Spec

### 三层协同动画系统

**Layer 1 — 侧边栏呼吸折叠 (240px ↔ 64px)**
```
展开:
  width: 240px, ease-out 300ms cubic-bezier(0.16, 1, 0.3, 1)
  opacity: 1 → 导航文字 fadeIn 100ms delay
  顶部 Logo 文字 slide in from left 150ms

折叠:
  width: 64px,  ease-out 300ms cubic-bezier(0.16, 1, 0.3, 1)
  导航文字 fadeOut 100ms
  Logo 文字缩入，仅保留植物图标 (sway 动画持续)
```

**Layer 2 — 导航指示器弹跳滑动**
```
活跃项:
  left-indicator (4px 宽 fern 色竖条): slideIn Y + elastic overshoot
  background: transparent → var(--muted), 200ms ease-out
  icon color: muted → fern, 150ms
  label color: muted → foreground, 150ms

导航切换:
  指示器从旧项 Y 位置滑动到新项 Y 位置, 250ms cubic-bezier(0.34, 1.56, 0.64, 1)
```

**Layer 3 — 内容区编排入场**
```
页面首次加载: stagger-slide-up (4 卡片依次, 60ms/层)
导航切换: content fadeIn 200ms + 内部元素 stagger-slide-up
ConvertModal 打开: scale(0.95)→1 + backdrop 模糊 200ms
```

### 动画禁用
- `prefers-reduced-motion: reduce` 时所有动画时长降至 0.01ms

---

## Functional Requirements

### Core Features

#### Feature 1: AppLayout Shell — 可折叠侧边栏 + 内容区

- **Description**: `AppLayout` 组件包裹 `_app.tsx`，提供侧边栏导航 + 动画系统。侧边栏折叠状态持久化到 `localStorage` key `sidebar-collapsed`。
- **Components**:
  - `AppLayout.tsx`: 主布局容器，管理 collapsed state + 路由感知
  - `Sidebar.tsx`: 侧边栏 UI + 导航项 + 动画
  - `MobileDrawer.tsx`: 移动端抽屉
- **User flow**:
  1. 用户打开任意页面 → AppLayout 渲染侧边栏（桌面常驻 / 移动汉堡菜单） + 右侧内容区
  2. 侧边栏顶部显示应用 Logo（植物图标 sway + "MioBridge"）
  3. 导航项：仪表盘（ph:gauge）、操作（ph:lightning）、API 文档（ph:globe）
  4. 侧边栏底部：折叠按钮 (ph:sidebar) + 主题切换按钮 + 版本号
  5. 折叠状态下仅显示图标，hover 显示 tooltip
- **Edge cases**: 侧边栏折叠/展开状态从 localStorage 恢复（避免 SSR hydration 闪烁）；折叠动画期间导航项不响应点击避免误触
- **Responsive**:
  - ≥1024px: 侧边栏常驻，可折叠
  - <1024px: 顶部固定 bar（56px 高）含汉堡菜单 + 应用标题 + 主题按钮，抽屉从左侧滑入覆盖

#### Feature 2: 仪表盘页 `/`

- **Description**: 状态概览首页
- **Layout**: 2 行
  - Row 1: 4 张 StatCard（订阅文件 / Clash 配置 / 节点数量 / 运行时间）
  - Row 2: "核心服务" + "文件信息" 并排
- **Data source**: `getServerSideProps` → `mioBridgeService.getStatus()`
- **Polling**: 客户端 30s 轮询，静默更新不触发入场动画
- **Edge cases**: SSR 失败时显示 garden-alert-danger + 手动刷新按钮

#### Feature 3: 操作页 `/actions`

- **Description**: 集中管理所有写操作和下载
- **Layout**: 3 张卡片
  - 卡片 1: 「更新订阅」— 按钮 + 进度指示 + 上次结果摘要
  - 卡片 2: 「下载文件」— 3 个文件行（名称 + 大小 + 更新时间 + 下载按钮）
  - 卡片 3: 「订阅转换」— 描述 + 打开 ConvertModal 按钮
- **State 跨页保留**: `updateResult` 存入 React Context (`AppContext`)，切换页面不清除

#### Feature 4: ConvertModal（全局弹框）

- **Description**: 订阅转换弹框，任意页可按需打开
- **实现**: 复用现有 `ConvertModal.tsx`，仅增加入场动画 `scale(0.95)→1 + 背景模糊`
- **调用方式**: 通过 `AppContext` 提供 `openConvertModal()` 方法，任意子页面调用

#### Feature 5: API 文档页 `/api-docs`

- **Description**: 完整 API 端点表格（6 个端点）
- **Layout**: 单张 Card + Table
- **交互**: 每个端点有操作按钮（测试 / 下载）

### Out of Scope

- 用户认证 / 登录系统
- 操作历史记录持久化
- 实时 WebSocket 推送（保持 30s 轮询）
- 批量操作（批量下载等）

---

## Technical Constraints

### Performance
- 首屏 SSR `getServerSideProps` < 500ms（同进程调用，已验证）
- 客户端路由切换 < 100ms（Next.js `next/link` 纯 CSR）
- 侧边栏折叠动画仅依赖 CSS transition（不触发 React re-render）
- `AppLayout` 使用 `React.memo` + `useMemo` 稳定引用，避免不必要的子树渲染

### Security
- 所有 API 调用使用同源相对路径
- 文件下载通过 `window.open` 新标签页

### Integration
- Service 层零改动
- API routes 零改动
- `apiService` 零改动

### Technology Stack
- Next.js 15 Pages Router + React 19
- Tailwind CSS v4 + Botanical Garden CSS 变量
- `@iconify/react` Phosphor 图标集
- 无新依赖

---

## MVP Scope & Phasing

### Phase 1: MVP (本次交付)

1. **AppLayout + Sidebar**: 可折叠侧边栏 + 导航指示器动画 + 移动端抽屉
2. **AppContext**: 全局状态（updateResult + openConvertModal + sidebarCollapsed）
3. **仪表盘页 (`/`)**: 纯状态展示（SSR）
4. **操作页 (`/actions`)**: 更新 / 下载 / 转换入口
5. **API 文档页 (`/api-docs`)**: 端点表格
6. **动画集成**: stagger-slide-up 入场 + 侧边栏呼吸折叠 + 指示器弹跳

### Phase 2: 增强（后续迭代）

- 操作历史时间线
- 节点详情列表
- Ping 延迟测试

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 移动端汉堡菜单 + 抽屉实现复杂度 | Medium | Low | 纯 CSS `translateX` + `React.createPortal`，不引入 Headless UI |
| 操作页状态在页面切换后丢失 | Low | Medium | 将 updateResult 提升到 `AppContext`（React Context） |
| 折叠动画在低端设备上掉帧 | Low | Low | 纯 CSS transition width，GPU 加速；reduced-motion 禁用 |

---

## Dependencies & Blockers

**Dependencies:**
- 无外部依赖 — 纯现有代码重构

**Known Blockers:**
- 无

---

## Appendix

### Glossary
- **StatCard**: 左边框彩色条 + 图标 + 大数值 + 副文本的指标卡片
- **ConvertModal**: 订阅转换弹框，左侧输入原始链接文本，右侧 Monaco Editor 展示 YAML
- **Garden Card**: 统一卡片组件 (`garden-card` CSS class)
- **呼吸折叠**: 侧边栏 240px ↔ 64px 弹性切换，配合文字/图标淡入淡出
- **弹跳滑入**: 导航指示器带弹性 overshoot 的 Y 轴滑动效果 (`cubic-bezier(0.34, 1.56, 0.64, 1)`)

### Component Tree
```
_app.tsx
└── ThemeProvider
    └── AppProvider (AppContext: updateResult, openConvertModal, sidebarCollapsed)
        └── AppLayout
            ├── Sidebar (Desktop: persistent + collapsible)
            │   ├── Logo (plant icon sway + text)
            │   ├── NavItem: 仪表盘 (ph:gauge)
            │   ├── NavItem: 操作 (ph:lightning)
            │   ├── NavItem: API 文档 (ph:globe)
            │   ├── Spacer
            │   ├── CollapseToggle (ph:sidebar)
            │   └── ThemeToggle
            ├── MobileHeader (Mobile: hamburger + title + theme)
            ├── MobileDrawer (Mobile: overlay drawer)
            └── <main> Content Area
                ├── / → Dashboard (SSR)
                ├── /actions → ActionsPage
                ├── /api-docs → ApiDocsPage
                └── ConvertModal (global, triggered via context)
```

### Page Route Map
```
/              → pages/index.tsx     (SSR with getServerSideProps)
/actions       → pages/actions.tsx   (CSR)
/api-docs      → pages/api-docs.tsx  (CSR)
```

### References
- [CLAUDE.md](../../CLAUDE.md) — 项目架构约定
- [globals.css](../../frontend/src/styles/globals.css) — Botanical Garden 设计 token + 动画定义
- [api.ts](../../frontend/src/lib/api.ts) — API 客户端类型定义

---

*This PRD was created through interactive requirements gathering with quality scoring to ensure comprehensive coverage of business, functional, UX, and technical dimensions.*
