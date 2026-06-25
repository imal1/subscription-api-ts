# MioBridge AI Memory Index

本目录包含 MioBridge 项目的持久化 AI 记忆文件，Claude Code 在新 session 中自动加载。

## 记忆文件列表

- [project-architecture.md](project-architecture.md) — 项目架构决策及原因
- [deployment-flow.md](deployment-flow.md) — 部署流程（systemd + nginx + CI/CD）
- [ci-cd-pipeline.md](ci-cd-pipeline.md) — GitHub Actions 流水线详解
- [bug-fixes.md](bug-fixes.md) — 历史 bug 及修复方案
- [config-patterns.md](config-patterns.md) — 配置约定和默认值
- [coding-conventions.md](coding-conventions.md) — 代码风格和约定

## 维护规则

每次完成以下操作后，必须更新对应的记忆文件：

| 操作 | 更新文件 |
|------|---------|
| 修复 bug | bug-fixes.md |
| 架构决策 / 技术选型变更 | project-architecture.md |
| CI/CD 流程变更 | ci-cd-pipeline.md |
| 部署流程变更 | deployment-flow.md |
| 配置约定变更 | config-patterns.md |
| 代码风格变更 | coding-conventions.md |

更新方式：追加新条目到对应文件，保持时间倒序（最新在前）。