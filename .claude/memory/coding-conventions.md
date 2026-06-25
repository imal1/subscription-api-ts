---
name: coding-conventions
description: MioBridge 代码风格和约定
metadata:
  type: project
---

# 代码风格和约定

## 语言和工具

- **语言**：TypeScript（严格模式）
- **运行时**：Bun（开发） / Node.js 20+（生产）
- **Linter**：oxlint（`frontend/src/`）
- **包管理**：Bun workspaces（monorepo）

## 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

| 前缀 | 用途 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | Bug 修复 |
| `docs:` | 文档变更 |
| `refactor:` | 重构（无功能变更） |
| `chore:` | 构建/工具/依赖 |
| `test:` | 测试 |
| `ci:` | CI/CD 变更 |
| `style:` | 代码格式 |

格式：`<type>: <description>`（英文描述）

## TypeScript 约定

- 严格模式（`tsconfig.json` 中 `strict: true`）
- 所有函数参数和返回值显式类型标注
- 避免 `any`，必要时使用 `unknown`
- 使用 `@/server/...` 路径别名引用后端模块

## 后端 Service 约定

- 所有 service 使用 `getInstance()` 单例模式
- Service 不依赖 Next.js，框架无关
- 新增后端能力优先加到 service 层，再用薄 API route 暴露
- Node 专属模块（`path`, `fs`, `child_process`）只能在 `server/`、`api/`、`instrumentation-node` 中使用

## 前端约定

- 使用 Botanical Garden 设计系统（见 CLAUDE.md Design System 章节）
- 所有颜色使用 CSS 变量（`var(--xxx)`），禁止 Tailwind 颜色类
- 图标使用 `@iconify/react` 的 Phosphor 集（`ph:` 前缀）
- SSR 首屏数据通过 `getServerSideProps` 同进程调用 service

## 文件命名

- Service 文件：`camelCase.ts`（如 `mioBridgeService.ts`）
- API routes：`kebab-case.ts`（如 `api/health.ts`）
- 组件文件：`PascalCase.tsx`（如 `Dashboard.tsx`）
- 配置文件：`kebab-case.yaml` 或 `kebab-case.json`

## oxlint 规则

配置在 `oxlint.json`：
- 基于 `eslint:recommended` 的 TypeScript 规则
- 禁止 `console.log`（生产代码中应使用 Winston logger）
- 禁止未使用的变量
