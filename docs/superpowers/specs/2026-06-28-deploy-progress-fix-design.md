# MioBridge 部署进度推送重构 & Bug 修复

日期：2026-06-28 | 状态：待实现

## 问题诊断

### Bug 1：SSE 卡在"等待部署开始..."

**根因**：`deploy.ts:68-72` — `deployToNode()` 的 fire-and-forget promise 只在 catch 中打 log，从不更新 `deployProgressStore`。当 SSH 连接超时、认证失败或 dev server OOM 时，SSE 客户端永远卡在 `connect: pending`。

```typescript
// 当前代码
deployPromise.then((result) => {
  logger.info(...)
}).catch((err) => {
  logger.error(...)  // ← 只打 log，不更新 store！
})
```

### Bug 2：generateAgentYaml 硬编码 kernel 类型

`deployManager.ts:311` — kernel 参数写死 `'sing-box'`，非 sing-box 节点（如 xray）的 agent 配置错误。

### Bug 3：hostVerifier 永远返回 true

`deployManager.ts:175` — 跳过主机密钥验证，存在 MITM 风险。

### 架构问题：伪 SSE 不可扩展

当前"SSE"实际是 `setInterval` + 共享内存 Map 的轮询伪装。每个部署占用一个长连接 + 一个 timer。20 节点同时部署 = 20 个长期 HTTP 连接，Next.js Pages Router API routes 会被占满。

## 设计方案（已确认）

### 1. 聚合轮询替代 SSE

删除 SSE 端点，改为普通 JSON GET 端点：

**新端点**：`GET /api/cluster/deploy/status?nodes=id1,id2,id3`

不传 `nodes` 参数时返回所有进行中的部署。

响应格式：
```json
{
  "deployments": {
    "tokyo-xray-01": {
      "step": "agent",
      "status": "running",
      "message": "上传 Agent 二进制...",
      "progress": 60
    }
  },
  "timestamp": "2026-06-28T17:30:00Z"
}
```

前端一个 `setInterval(500ms)`，一次请求拿所有节点状态。1 节点和 20 节点开销相同。

### 2. Progress Store 精简

从 `Map<nodeId, DeployStep[]>`（全量历史数组）改为 `Map<nodeId, DeployStatus>`（单条当前状态）：

```typescript
interface DeployStatus {
  nodeId: string;
  step: string;
  status: 'pending' | 'running' | 'success' | 'error';
  message: string;
  progress: number;
  startedAt: number;  // Date.now()，用于 TTL 清理
}
```

`done` 或 `error` 状态 5 分钟后自动清理。每次 deploy 覆盖写入一条。

### 3. Fire-and-forget 异常处理

`deploy.ts` catch 中更新 progress store 为 error 状态，确保前端能收到结束信号。

### 4. hostVerifier 自动记录 host key

首次连接时自动保存 host key 到 `nodes.yaml` 的 `hostKey` 字段，后续连接验证。

### 5. kernel 类型从 nodes.yaml 传入

`DeployTarget` 加 `kernel` 字段，`deploy.ts` 从 `node.kernel` 传入，不再硬编码。

### 6. 清理无意义字段

删除 `NodeConfig.port`（SSH 固定 22，agent API 固定 3001，无需配置）。
删除 `NodeSshConfig.port`，代码中硬编码 22。

## 改动清单

| 文件 | 改动 |
|------|------|
| `deploy.ts` | catch 中更新 progress store 为 error；传 kernel 字段 |
| `deployProgressStore.ts` | 改为单条 DeployStatus + 5 分钟 TTL |
| `deployManager.ts` | generateAgentYaml 用实际 kernel；hostVerifier 记录 host key；DeployTarget 加 kernel |
| `nodeManager.ts` | NodeConfig 删 port；NodeSshConfig 删 port；YAML 解析/写入适配 |
| 新建 `status.ts` | `GET /api/cluster/deploy/status` 聚合轮询端点 |
| `progress.ts` | 删除或重定向到 status |
| 前端组件 | EventSource → setInterval + fetch |
| `nodes.yaml` | 删除 port 字段 |
| 测试文件 | 适配新 schema |

## 不做

- **WebSocket**：需要自定义 server，破坏 `output: 'standalone'` 模式
- **节点删除功能**：超出本次范围
- **agent 二进制增量更新**：92MB 全量上传对首次部署可接受
