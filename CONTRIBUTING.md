# 贡献指南

## 开发环境搭建

### 前提条件

- **Bun** >= 1.0.0（包管理和开发运行时）
- **Node.js** >= 18.0.0（生产运行时）
- **mihomo**（clash-meta 内核）— 放在 `~/.config/miobridge/bin/mihomo`
- **yq** (mikefarah/yq v4) — 放在 `~/.config/miobridge/bin/yq`
- **sing-box**（可选，缺失时仪表盘仍可渲染）

### 快速开始

```bash
git clone https://github.com/imal1/miobridge.git
cd miobridge
bun install
bun run dev
```

服务启动在 `http://localhost:3001`。

### 项目结构

```
miobridge/
├── frontend/                  # Next.js 全栈应用
│   ├── src/
│   │   ├── server/            # 后端 service 层（框架无关）
│   │   │   ├── config/        # 配置读取（yq 解析 config.yaml）
│   │   │   ├── services/      # 核心 service 单例
│   │   │   ├── utils/         # Winston logger
│   │   │   └── types/
│   │   ├── pages/             # Next.js Pages Router
│   │   │   ├── index.tsx      # 仪表盘（SSR）
│   │   │   └── api/           # API routes
│   │   ├── components/        # React 组件
│   │   ├── lib/               # 前端 API 客户端
│   │   └── styles/            # Botanical Garden 主题
│   └── next.config.js
├── config/                    # systemd / nginx 模板
├── scripts/                   # 部署和管理脚本
├── docs/                      # 项目文档
├── .claude/                   # Claude Code 配置
│   ├── roadmap/               # 版本路线图
│   └── memory/                # AI 记忆系统
└── .github/workflows/         # CI/CD 流水线
```

## 分支策略

- `main` — 生产分支，始终保持可部署状态
- `feature/*` — 功能分支，从 `main` 分出
- `fix/*` — 修复分支

### 工作流程

1. 从 `main` 创建分支：`git checkout -b feature/my-feature`
2. 开发和测试
3. 提交代码（遵循 Conventional Commits）
4. 推送到 GitHub：`git push origin feature/my-feature`
5. 创建 PR 到 `main`
6. CI 门禁通过后合并

## 代码风格

### TypeScript

- 严格模式（`tsconfig.json` 中 `strict: true`）
- 所有函数参数和返回值显式类型标注
- 避免 `any`，必要时使用 `unknown`

### Linting

```bash
bun run lint        # 检查
bun run lint:fix    # 自动修复
```

使用 oxlint，规则配置在 `oxlint.json`。

### 设计系统

遵循 **Botanical Garden** 设计系统（详见 `CLAUDE.md` Design System 章节）：

- 所有颜色使用 CSS 变量（`var(--primary)` 等），禁止 Tailwind 颜色类
- 图标使用 `@iconify/react` 的 Phosphor 集（`ph:` 前缀）
- 不使用 `shadow-sm`/`shadow-md`，使用 `var(--shadow-card)` 等 token

## 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>: <description>
```

| 前缀 | 用途 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | Bug 修复 |
| `docs:` | 文档变更 |
| `refactor:` | 重构 |
| `chore:` | 构建/工具/依赖 |
| `test:` | 测试 |
| `ci:` | CI/CD 变更 |

## PR 流程

1. 创建 PR 到 `main` 分支
2. PR 标题遵循 Conventional Commits 格式
3. CI 门禁（`ci.yml`）自动运行：lint → typecheck → build
4. 全部通过后请求 review
5. Review 通过后合并

## AI 协作

### CLAUDE.md

项目根目录的 `CLAUDE.md` 是 AI 助手的入口文档，包含架构、约定、命令等完整信息。AI 在每次 session 开始时自动加载。

### Memory 系统

`.claude/memory/` 目录包含持久化的项目记忆文件，AI 在新 session 中自动加载。修 bug 或做架构决策后，AI 会主动更新对应记忆文件。

### 自定义命令

Claude Code 中可用：

- `/miobridge:deploy` — 一键部署到生产环境
- `/miobridge:diag` — 运行完整诊断
- `/miobridge:release` — 创建版本发布

## 获取帮助

- [README.md](README.md) — 项目概述
- [CLAUDE.md](CLAUDE.md) — AI 协作者指南
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) — 部署指南
- [docs/CI-CD.md](docs/CI-CD.md) — CI/CD 文档
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — 故障排除
- [GitHub Issues](https://github.com/imal1/miobridge/issues)