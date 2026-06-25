---
name: bug-fixes
description: MioBridge 历史 bug 及修复方案
metadata:
  type: project
---

# 历史 Bug 及修复方案

记录每个 bug 的症状、原因和修复方案，避免重复踩坑。

## v1.1.0 已修复

### 1. yq YAML 输出格式错误 — clash.yaml 永远无法生成

**日期**：2026-06-24
**严重程度**：高

**症状**：`/clash.yaml` 返回 404，仪表盘"Clash 配置"卡片永远显示"未生成"，即使更新成功。

**原因**：`yq eval -P` 默认输出 JSON 格式而非 YAML。在 `yamlService` 中调用 yq 时未指定 `-o yaml` 参数，导致输出 JSON 字符串，后续 YAML 处理失败。

**修复**：在所有 yq 输出命令中添加 `-o yaml` 参数。
**文件**：`frontend/src/server/services/yamlService.ts`

### 2. 仪表盘状态轮询丢失

**日期**：2026-06-24
**严重程度**：高

**症状**：仪表盘首次 SSR 加载正常（状态、节点数正确显示），但 30 秒客户端轮询后所有状态变为"未生成"、节点数变为 0。

**原因**：API 响应格式为 `{ success: true, data: {...} }`，但前端 `api.ts` 中的客户端请求函数直接使用 `response` 对象，未解包 `response.data` 字段。

**修复**：在 `api.ts` 中对 API 响应进行 `.data` 解包。
**文件**：`frontend/src/lib/api.ts`

### 3. 版本号不一致

**日期**：2026-06-24
**严重程度**：中

**症状**：项目中三处硬编码了不同的版本号（`package.json`、config 模板、仪表盘页脚），更新版本时容易遗漏。

**修复**：统一从 `package.json` 读取版本号。
**涉及文件**：`config.yaml.example`、仪表盘组件

### 4. 部署版本不可见

**日期**：2026-06-24
**严重程度**：低

**症状**：无法确认服务器运行的是哪个 git commit，排查问题时难以确定代码版本。

**修复**：在 GitHub Actions 构建环境中注入 `NEXT_PUBLIC_GIT_COMMIT`，仪表盘页脚自动显示 commit hash。
**文件**：`.github/workflows/deploy.yml`、仪表盘页脚组件
