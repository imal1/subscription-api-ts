# 部署进度推送重构 & Bug 修复 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复部署进度 SSE 卡死、fire-and-forget 异常丢失、host key 验证缺失、kernel 硬编码等 5 个 bug，并用聚合轮询替代伪 SSE。

**Architecture:** 将 `deployProgressStore` 从全量历史数组改为单条 `DeployStatus` + 5 分钟 TTL；删除 SSE 端点，新增 `GET /api/cluster/deploy/status` 聚合轮询端点；前端用 `setInterval` + `fetch` 替代 `EventSource`；`hostVerifier` 首次连接自动保存 host key；`kernel` 从 `nodes.yaml` 传入而非硬编码；删除 `NodeConfig.port` 和 `NodeSshConfig.port`。

**Tech Stack:** TypeScript, Next.js Pages Router, React, vitest, ssh2

## Global Constraints

- 不引入 WebSocket（破坏 `output: 'standalone'` 模式）
- 不删除节点功能（超出范围）
- 不实现 agent 增量更新
- `NodeConfig.port` 和 `NodeSshConfig.port` 必须删除（SSH 固定 22，agent API 固定 3001，远程 API 固定 443）
- 所有现有测试必须适配新 schema 并通过

---

### Task 1: 更新类型定义 + 重写 deployProgressStore

**Files:**
- Modify: `frontend/src/server/types/index.ts` (lines 78-93, 138-146)
- Modify: `frontend/src/server/services/deployProgressStore.ts` (entire file)

**Interfaces:**
- Produces: `DeployStatus` interface (used by Tasks 2, 3, 5, 7)
- Produces: `getDeployStatus(nodeId)`, `setDeployStatus(nodeId, status)`, `getAllDeployStatuses()`, `clearDeployStatus(nodeId)` (used by Tasks 2, 3, 5, 7)
- Consumes: nothing

- [ ] **Step 1: 从 types/index.ts 删除 port 字段**

在 `NodeConfig` 接口中删除 `port: number;` 行（第 82 行）。
在 `NodeSshConfig` 接口中删除 `port: number;` 行（第 141 行）。

```typescript
// NodeConfig — 删除 port 后：
export interface NodeConfig {
  id: string;
  name: string;
  host: string;
  // port: number;  ← 删除此行
  secret: string;
  kernel: KernelType;
  location: string;
  enabled: boolean;
  ssh?: NodeSshConfig;
  agent?: NodeAgentInfo;
  kernelInfo?: NodeKernelInfo;
}

// NodeSshConfig — 删除 port 后：
export interface NodeSshConfig {
  user: string;
  // port: number;  ← 删除此行
  keyPath: string;
  hostKey: string;
  password?: string;
}
```

在 types/index.ts 末尾添加 `DeployStatus` 接口：

```typescript
/** 部署进度状态（单条当前状态，非历史数组） */
export interface DeployStatus {
  nodeId: string;
  step: string;
  status: 'pending' | 'running' | 'success' | 'error';
  message: string;
  progress: number;
  startedAt: number;  // Date.now()，用于 TTL 清理
}
```

- [ ] **Step 2: 重写 deployProgressStore.ts**

```typescript
import type { DeployStatus } from '../types';

/** In-memory deploy progress store — single current status per node, 5-min TTL */
const deployProgress = new Map<string, DeployStatus>();
const TTL_MS = 5 * 60 * 1000; // 5 minutes

function cleanup(): void {
  const now = Date.now();
  for (const [nodeId, status] of deployProgress) {
    if (now - status.startedAt > TTL_MS) {
      deployProgress.delete(nodeId);
    }
  }
}

export function getDeployStatus(nodeId: string): DeployStatus | null {
  cleanup();
  return deployProgress.get(nodeId) || null;
}

export function getAllDeployStatuses(): DeployStatus[] {
  cleanup();
  return Array.from(deployProgress.values());
}

export function setDeployStatus(nodeId: string, status: DeployStatus): void {
  deployProgress.set(nodeId, status);
}

export function clearDeployStatus(nodeId: string): void {
  deployProgress.delete(nodeId);
}
```

- [ ] **Step 3: 运行测试验证类型编译通过**

```bash
cd /home/imali/MioBridge/frontend && bun run test 2>&1 | tail -30
```

Expected: 类型错误（因为其他文件还在引用 `port` 和旧的 store API），但 deployProgressStore 本身不应报错。

- [ ] **Step 4: Commit**

```bash
git add frontend/src/server/types/index.ts frontend/src/server/services/deployProgressStore.ts
git commit -m "refactor: add DeployStatus type, rewrite deployProgressStore with TTL, remove port fields from NodeConfig/NodeSshConfig"
```

---

### Task 2: 修复 deployManager.ts（kernel 传参 + hostVerifier 记录 host key + 删除 port）

**Files:**
- Modify: `frontend/src/server/services/deployManager.ts`

**Interfaces:**
- Consumes: `DeployStatus` from Task 1 (types/index.ts)
- Consumes: `NodeConfig` without `port`, `NodeSshConfig` without `port` from Task 1
- Produces: `DeployTarget` now has `kernel: string` field (used by Task 3)

- [ ] **Step 1: DeployTarget 加 kernel 字段，删 ssh.port**

```typescript
// deployManager.ts line 34-45 — 修改 DeployTarget
export interface DeployTarget {
  nodeId: string;
  ssh: {
    host: string;
    user: string;
    keyPath: string;
    hostKey: string;
    password?: string;
  };
  kernel?: string;       // ← 新增：内核类型
  agentPort?: number;
}
```

- [ ] **Step 2: connectSsh 中 hostVerifier 自动记录 host key**

修改 `connectSsh` 方法（line 167-176），替换 `hostVerifier: () => true` 为自动保存逻辑：

```typescript
// 替换 line 167-176：
if (target.ssh.hostKey) {
  connectOpts.hostHash = 'sha256';
  connectOpts.hostVerifier = (hashedKey: Buffer) => {
    return hashedKey.toString('base64') === target.ssh.hostKey;
  };
} else {
  // First connect: auto-record host key for future verification
  connectOpts.hostVerifier = (hashedKey: Buffer) => {
    const keyStr = hashedKey.toString('base64');
    logger.info(`DeployManager: 首次连接 ${target.ssh.host}，记录 host key: ${keyStr.substring(0, 16)}...`);
    // Store the key for this session (will be persisted to nodes.yaml by caller)
    (target.ssh as any).recordedHostKey = keyStr;
    return true;
  };
}
```

- [ ] **Step 3: connectSsh 中 SSH port 硬编码 22**

修改 line 143-145：

```typescript
const connectOpts: any = {
  host: target.ssh.host,
  port: 22,  // ← 硬编码，不再从 target.ssh.port 读取
  username: target.ssh.user || 'root',
```

- [ ] **Step 4: deployToNode 中 kernel 判断改用 target.kernel**

修改 line 97，替换硬编码的 kernel 推断：

```typescript
// 替换 line 97：
// const kernelType = target.nodeId.includes('xray') ? 'xray' : 'sing-box';
const kernelType = target.kernel || 'sing-box';
```

- [ ] **Step 5: uploadAgent 中 generateAgentYaml 调用传 target.kernel**

修改 line 307-312：

```typescript
const agentYaml = this.generateAgentYaml(
  target.nodeId,
  target.nodeId,
  secret,
  target.kernel || 'sing-box',  // ← 用 target.kernel，不再硬编码 'sing-box'
);
```

- [ ] **Step 6: verifyAgent 中 agentPort 默认值确认**

line 368 已经是 `const port = target.agentPort || 3001;`，无需修改。

- [ ] **Step 7: 运行测试**

```bash
cd /home/imali/MioBridge/frontend && npx vitest run src/server/services/__tests__/deployManager.test.ts 2>&1 | tail -30
```

Expected: 类型错误（测试文件引用 `port` 字段），但 deployManager.ts 自身逻辑正确。

- [ ] **Step 8: Commit**

```bash
git add frontend/src/server/services/deployManager.ts
git commit -m "fix: pass kernel from DeployTarget, auto-record hostKey on first connect, hardcode SSH port 22"
```

---

### Task 3: 修复 deploy.ts（catch → error 更新 store + 传 kernel + 删 port）

**Files:**
- Modify: `frontend/src/pages/api/cluster/deploy.ts`

**Interfaces:**
- Consumes: `DeployStatus`, `NodeConfig` (no port) from Task 1
- Consumes: `DeployTarget` with `kernel` from Task 2
- Consumes: `setDeployStatus` from Task 1

- [ ] **Step 1: 重写 deploy.ts — catch 中更新 progress store 为 error，传 kernel**

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { DeployManager } from '@/server/services/deployManager';
import type { DeployStep } from '@/server/services/deployManager';
import { setDeployStatus, getDeployStatus } from '@/server/services/deployProgressStore';
import { logger } from '@/server/utils/logger';
import type { ApiResponse, DeployStatus } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    if (!nodeId) {
      return res.status(400).json({ success: false, error: '缺少 nodeId', timestamp: new Date().toISOString() });
    }

    const nodeManager = NodeManager.getInstance();
    const deployManager = DeployManager.getInstance();
    const nodes = await nodeManager.loadNodes();
    const node = nodes.find(n => n.id === nodeId);

    if (!node) {
      return res.status(404).json({ success: false, error: `节点 ${nodeId} 不存在`, timestamp: new Date().toISOString() });
    }

    if (!node.ssh) {
      return res.status(400).json({ success: false, error: '节点未配置 SSH 信息', timestamp: new Date().toISOString() });
    }

    // Initialize progress tracking — single DeployStatus
    setDeployStatus(nodeId, {
      nodeId,
      step: 'connect',
      status: 'pending',
      message: '等待部署开始...',
      progress: 0,
      startedAt: Date.now(),
    });

    // Start deploy asynchronously
    const deployPromise = deployManager.deployToNode(
      {
        nodeId: node.id,
        ssh: {
          host: node.host,
          user: node.ssh.user,
          keyPath: node.ssh.keyPath,
          hostKey: node.ssh.hostKey,
          password: node.ssh.password,
        },
        kernel: node.kernel,     // ← 从 node 传入 kernel
        agentPort: 3001,
      },
      (step: DeployStep) => {
        // Update progress store with current step
        setDeployStatus(nodeId, {
          nodeId,
          step: step.step,
          status: step.status,
          message: step.message,
          progress: step.progress,
          startedAt: Date.now(),
        });
      },
    );

    // Return immediately with 202 Accepted
    res.status(202).json({
      success: true,
      message: `节点 ${node.name} 部署已启动`,
      timestamp: new Date().toISOString(),
    });

    // Wait for deploy to finish (in background, after response sent)
    deployPromise.then((result) => {
      logger.info(`Deploy API: 节点 ${nodeId} 部署完成: ${result.success ? '成功' : '失败'} - ${result.message}`);
      // Update store with final state
      const current = getDeployStatus(nodeId);
      setDeployStatus(nodeId, {
        nodeId,
        step: result.success ? 'done' : 'verify',
        status: result.success ? 'success' : 'error',
        message: result.message,
        progress: result.success ? 100 : (current?.progress || 90),
        startedAt: current?.startedAt || Date.now(),
      });
    }).catch((err) => {
      logger.error(`Deploy API: 节点 ${nodeId} 部署异常: ${err.message}`);
      // ← Bug fix: 更新 progress store 为 error 状态
      const current = getDeployStatus(nodeId);
      setDeployStatus(nodeId, {
        nodeId,
        step: 'connect',
        status: 'error',
        message: `部署异常: ${err.message}`,
        progress: current?.progress || 0,
        startedAt: current?.startedAt || Date.now(),
      });
    });
  } catch (error: any) {
    logger.error('部署失败:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/pages/api/cluster/deploy.ts
git commit -m "fix: update deploy progress store on error, pass kernel from node config"
```

---

### Task 4: 修复 nodeManager.ts（删除 port 引用）

**Files:**
- Modify: `frontend/src/server/services/nodeManager.ts`

**Interfaces:**
- Consumes: `NodeConfig` without `port`, `NodeSshConfig` without `port` from Task 1

- [ ] **Step 1: writeNodeToYaml 中删除 port 行**

删除 line 82: `lines.push(\`    port: ${node.port}\`);`
删除 line 91: `lines.push(\`      port: ${node.ssh.port}\`);`

修改后 writeNodeToYaml 中 node entry 部分（lines 79-95）：

```typescript
// Build node entry
lines.push(`  - id: "${node.id}"`);
if (node.name) lines.push(`    name: "${node.name}"`);
if (node.host) lines.push(`    host: "${node.host}"`);
// port line deleted
if (node.secret) lines.push(`    secret: "${node.secret}"`);
if (node.kernel) lines.push(`    kernel: "${node.kernel}"`);
if (node.location) lines.push(`    location: "${node.location}"`);
lines.push(`    enabled: ${node.enabled}`);

if (node.ssh) {
  lines.push(`    ssh:`);
  lines.push(`      user: "${node.ssh.user}"`);
  // ssh port line deleted
  if (node.ssh.keyPath) lines.push(`      keyPath: "${node.ssh.keyPath}"`);
  if (node.ssh.hostKey) lines.push(`      hostKey: "${node.ssh.hostKey}"`);
  if (node.ssh.password) lines.push(`      password: "${node.ssh.password}"`);
}
```

- [ ] **Step 2: parseNodesYaml 中删除 port 解析**

删除 line 225（ssh port 解析）：
```typescript
// 删除: else if (trimmed.startsWith('port:')) current.ssh!.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 22;
```

删除 lines 244-245（node port 解析）：
```typescript
// 删除: } else if (trimmed.startsWith('port:') && !line.includes('ssh')) {
// 删除:   current.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 443;
```

同时修改 ssh 默认值构造（line 218）：
```typescript
// 修改前：
current.ssh = { user: 'root', port: 22, keyPath: '', hostKey: '', password: '' };
// 修改后：
current.ssh = { user: 'root', keyPath: '', hostKey: '', password: '' };
```

- [ ] **Step 3: fetchRemoteStatus / fetchRemoteHealth / fetchRemoteUpdate 中删除 port 引用**

三处 URL 构造从 `https://${node.host}:${node.port}/...` 改为 `https://${node.host}/...`：

```typescript
// fetchRemoteStatus line 326:
const url = `https://${node.host}/api/status`;

// fetchRemoteUpdate line 382:
const url = `https://${node.host}/api/update`;

// fetchRemoteHealth line 414:
const url = `https://${node.host}/health`;
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/server/services/nodeManager.ts
git commit -m "refactor: remove NodeConfig.port and NodeSshConfig.port from nodeManager"
```

---

### Task 5: 新建 status.ts 聚合轮询端点 + 删除 progress.ts

**Files:**
- Create: `frontend/src/pages/api/cluster/deploy/status.ts`
- Delete: `frontend/src/pages/api/cluster/deploy/progress.ts`

**Interfaces:**
- Consumes: `getAllDeployStatuses`, `getDeployStatus` from Task 1 (deployProgressStore)
- Consumes: `DeployStatus` from Task 1 (types/index.ts)

- [ ] **Step 1: 创建 status.ts**

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { getAllDeployStatuses, getDeployStatus } from '@/server/services/deployProgressStore';
import type { ApiResponse, DeployStatus } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'GET') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  const nodesParam = (req.query.nodes as string) || '';
  const nodeIds = nodesParam ? nodesParam.split(',').map(s => s.trim()).filter(Boolean) : [];

  let deployments: Record<string, DeployStatus>;

  if (nodeIds.length > 0) {
    // Return only requested nodes
    deployments = {};
    for (const nodeId of nodeIds) {
      const status = getDeployStatus(nodeId);
      if (status) {
        deployments[nodeId] = status;
      }
    }
  } else {
    // Return all in-progress deployments
    const all = getAllDeployStatuses();
    deployments = {};
    for (const s of all) {
      deployments[s.nodeId] = s;
    }
  }

  res.status(200).json({
    success: true,
    data: {
      deployments,
      timestamp: new Date().toISOString(),
    },
    timestamp: new Date().toISOString(),
  });
}
```

- [ ] **Step 2: 删除 progress.ts**

```bash
rm /home/imali/MioBridge/frontend/src/pages/api/cluster/deploy/progress.ts
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/pages/api/cluster/deploy/status.ts
git rm frontend/src/pages/api/cluster/deploy/progress.ts
git commit -m "feat: replace SSE deploy progress with aggregation polling endpoint"
```

---

### Task 6: 修复 nodes.ts API（删除 port 引用）

**Files:**
- Modify: `frontend/src/pages/api/cluster/nodes.ts`

**Interfaces:**
- Consumes: `NodeConfig` without `port`, `NodeSshConfig` without `port` from Task 1

- [ ] **Step 1: 删除 port 和 sshPort 引用**

```typescript
// 修改 line 15 — 删除 port, sshPort:
const { name, host, kernel, location, sshUser, sshKey, sshPassword } = req.body || {};

// 修改 lines 23-46 — 删除 port 和 sshPort:
const nodeConfig: NodeConfig = {
  id: '',
  name,
  host,
  secret: '',
  kernel: kernel || 'sing-box',
  location: location || '',
  enabled: true,
  ssh: {
    user: sshUser || 'root',
    keyPath: sshKey || '',
    hostKey: '',
    password: sshPassword || '',
  },
  agent: {
    deployed: false,
    version: '',
    status: 'not_deployed',
    lastDeploy: '',
  },
};
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/pages/api/cluster/nodes.ts
git commit -m "refactor: remove port fields from nodes API handler"
```

---

### Task 7: 修复前端组件（EventSource → setInterval + fetch）

**Files:**
- Modify: `frontend/src/lib/api.ts` (lines 227-230)
- Modify: `frontend/src/components/Dashboard.tsx` (lines 28, 62-69, 198-206)
- Modify: `frontend/src/components/cluster/DeployProgressDialog.tsx` (lines 8, 37, 41)

**Interfaces:**
- Consumes: `DeployStatus` from Task 1 (types/index.ts)

- [ ] **Step 1: api.ts — 替换 getDeployProgressUrl 为 fetchDeployStatus**

```typescript
// 替换 line 227-230:
// 获取部署状态（聚合轮询）
async fetchDeployStatus(nodeIds?: string[]): Promise<ApiResponse> {
  try {
    const params = nodeIds && nodeIds.length > 0
      ? `?nodes=${nodeIds.map(encodeURIComponent).join(',')}`
      : '';
    return await apiClient.get(`api/cluster/deploy/status${params}`).json<ApiResponse>();
  } catch (error) {
    return this.handleError(error);
  }
},
```

- [ ] **Step 2: Dashboard.tsx — 用 setInterval + fetch 替换 SSE 部署进度**

修改 `handleDeploy` callback（lines 62-69）和 deploy progress 状态管理：

```typescript
// 修改 line 28 — 状态类型改为 DeployStatus:
const [deployProgress, setDeployProgress] = useState<{ nodeName: string; status: DeployStatus } | null>(null);

// 修改 handleDeploy (lines 62-69):
const handleDeploy = useCallback(async (nodeId: string) => {
  setDeployProgress({
    nodeName: nodeId,
    status: { nodeId, step: 'connect', status: 'running', message: '正在连接...', progress: 0, startedAt: Date.now() },
  });
  try {
    await apiService.deployNode(nodeId);
    // Start polling for progress
    const pollInterval = setInterval(async () => {
      try {
        const result = await apiService.fetchDeployStatus([nodeId]);
        const data = (result.data as any);
        const nodeStatus = data?.deployments?.[nodeId];
        if (nodeStatus) {
          setDeployProgress(prev => prev ? { ...prev, status: nodeStatus } : null);
          if (nodeStatus.status === 'success' || nodeStatus.status === 'error') {
            clearInterval(pollInterval);
          }
        }
      } catch {
        // ignore poll errors
      }
    }, 500);
    // Store interval ID for cleanup
    (window as any).__deployPollInterval = pollInterval;
  } catch (err) {
    setError(err instanceof Error ? err.message : '部署失败');
    setDeployProgress(null);
  }
}, []);
```

修改 DeployProgressDialog 调用（lines 198-206）：

```typescript
{/* Deploy Progress Dialog */}
{deployProgress && (
  <DeployProgressDialog
    isOpen={!!deployProgress}
    nodeName={deployProgress.nodeName}
    currentStatus={deployProgress.status}
    onClose={() => {
      const interval = (window as any).__deployPollInterval;
      if (interval) { clearInterval(interval); delete (window as any).__deployPollInterval; }
      setDeployProgress(null);
    }}
  />
)}
```

- [ ] **Step 3: DeployProgressDialog.tsx — 适配 DeployStatus 单条状态**

```typescript
// 修改 imports:
import type { DeployStatus } from '@/server/types';

// 修改 props interface:
interface DeployProgressDialogProps {
  isOpen: boolean;
  nodeName: string;
  currentStatus: DeployStatus;  // ← 单条状态替代 steps 数组
  onClose: () => void;
}

// 修改组件逻辑:
export function DeployProgressDialog({ isOpen, nodeName, currentStatus, onClose }: DeployProgressDialogProps) {
  if (!isOpen) return null;

  const isDone = currentStatus.step === 'done' || currentStatus.status === 'error';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={isDone ? onClose : undefined}>
      <div className="garden-card p-6 max-w-md w-full mx-4" onClick={e => e.stopPropagation()}>
        <div className="flex items-center gap-3 mb-4">
          <Icon icon="ph:rocket-launch-bold" className="w-6 h-6" style={{ color: 'var(--primary)' }} />
          <h3 className="text-lg font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
            正在部署 {nodeName}
          </h3>
        </div>

        {/* Progress bar */}
        <div className="mb-4 h-2 rounded-full overflow-hidden" style={{ backgroundColor: 'var(--muted)' }}>
          <div
            className="h-full rounded-full transition-all duration-500"
            style={{
              width: `${currentStatus.progress || 0}%`,
              backgroundColor: currentStatus.status === 'error' ? 'var(--terracotta)' : 'var(--fern)',
            }}
          />
        </div>

        {/* Current step */}
        <div className="flex items-center gap-3 mb-4">
          <Icon
            icon={currentStatus.status === 'running' ? 'ph:spinner-bold' : STATUS_ICONS[currentStatus.status] || 'ph:circle'}
            className={`w-5 h-5 ${currentStatus.status === 'running' ? 'animate-spin' : ''}`}
            style={{ color: STATUS_COLORS[currentStatus.status] || 'var(--muted-foreground)' }}
          />
          <span className="text-sm" style={{ color: currentStatus.status === 'pending' ? 'var(--muted-foreground)' : 'var(--foreground)' }}>
            {currentStatus.message || STEP_LABELS[currentStatus.step] || currentStatus.step}
          </span>
        </div>

        {isDone && (
          <button onClick={onClose}
            className="w-full px-4 py-2 rounded-lg text-sm font-medium transition-all"
            style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
            {currentStatus.status === 'error' ? '关闭' : '完成'}
          </button>
        )}
      </div>
    </div>
  );
}
```

保留文件顶部的 `STEP_LABELS`、`STATUS_ICONS`、`STATUS_COLORS` 常量不变。

- [ ] **Step 4: Commit**

```bash
git add frontend/src/lib/api.ts frontend/src/components/Dashboard.tsx frontend/src/components/cluster/DeployProgressDialog.tsx
git commit -m "refactor: replace SSE deploy progress with polling-based fetch"
```

---

### Task 8: 适配所有测试文件

**Files:**
- Modify: `frontend/src/server/services/__tests__/deployManager.test.ts`
- Modify: `frontend/src/server/services/__tests__/deploy-integration.test.ts`
- Modify: `frontend/src/server/__tests__/api/deploy.test.ts`

**Interfaces:**
- Consumes: All types and APIs from Tasks 1-7

- [ ] **Step 1: 适配 deployManager.test.ts — 删除 port 字段**

`writeNodesYaml` helper (lines 10-38): 删除 `if (n.port) lines.push(\`    port: ${n.port}\`);` 行（line 17）。
删除 ssh port 行 (line 24): `lines.push(\`      port: ${n.ssh.port}\`);`

测试用例中删除 port 引用：
- line 66: 删除 `port: 22,`
- line 80: 删除 `port: 443,`
- line 90: 删除 `port: 22,`
- line 113: 删除 `port: 22,`
- line 139: 删除 `port: 443,`
- line 148: 删除 `port: 22,`

同时更新 ssh 默认值构造中的 port 引用（如果有的话）。

- [ ] **Step 2: 适配 deploy-integration.test.ts — 删除 port 字段**

`makeNode` helper (line 9): 删除 `port: 443,`

```typescript
function makeNode(overrides: Partial<NodeConfig> = {}): NodeConfig {
  return {
    id: 'n1', name: 'Test', host: '10.0.0.1', secret: 'sec',
    kernel: 'sing-box', location: 'test', enabled: true, ...overrides,
  };
}
```

所有测试中创建的 `ssh` 对象删除 `port` 字段：
- line 27: 删除 `port: 22,`
- line 40: 删除 `port: 22,`
- line 44: 删除 `port: 2222,`
- line 88, 92, 122, 130: 删除 `port: 22,`

- [ ] **Step 3: 适配 deploy.test.ts — 更新 progress import**

```typescript
// 修改 line 9-10 — progress.ts 已删除，改为 status.ts:
it('deploy/status handler should be importable', async () => {
  const mod = await import('@/pages/api/cluster/deploy/status');
  expect(typeof mod.default).toBe('function');
});
```

- [ ] **Step 4: 运行全部测试**

```bash
cd /home/imali/MioBridge/frontend && bun run test 2>&1 | tail -50
```

Expected: 所有测试通过（162 tests passing，适配后可能有少量增减）。

- [ ] **Step 5: Commit**

```bash
git add frontend/src/server/services/__tests__/deployManager.test.ts frontend/src/server/services/__tests__/deploy-integration.test.ts frontend/src/server/__tests__/api/deploy.test.ts
git commit -m "test: adapt tests for port removal and SSE→polling refactor"
```

---

### Task 9: 清理 AddNodeForm 中的 port 字段（如有）

**Files:**
- Modify: `frontend/src/components/cluster/AddNodeForm.tsx` (检查是否有 port 输入)

**Interfaces:**
- Consumes: `NodeFormData` without `port` and `sshPort`

- [ ] **Step 1: 检查 AddNodeForm 中的 port 字段**

```bash
grep -n "port" /home/imali/MioBridge/frontend/src/components/cluster/AddNodeForm.tsx
```

如果 `NodeFormData` 接口中有 `port` 和 `sshPort` 字段，删除它们。如果有对应的表单输入框，删除输入框。

如果文件不包含 port 字段则跳过此任务。

- [ ] **Step 2: 同步更新 Dashboard.tsx 中的 handleAddNode**

确保 `handleAddNode` 中调用 `apiService.addNode` 时不传 `port` 和 `sshPort`。

- [ ] **Step 3: Commit (如有改动)**

```bash
git add frontend/src/components/cluster/AddNodeForm.tsx
git commit -m "refactor: remove port fields from AddNodeForm"
```

---

### Task 10: 最终验证 + push

- [ ] **Step 1: 运行完整测试套件**

```bash
cd /home/imali/MioBridge/frontend && bun run test 2>&1
```

Expected: 所有测试通过，无类型错误。

- [ ] **Step 2: TypeScript 编译检查**

```bash
cd /home/imali/MioBridge/frontend && npx tsc --noEmit 2>&1 | head -30
```

Expected: 无类型错误。

- [ ] **Step 3: Push 到 GitHub**

```bash
cd /home/imali/MioBridge && git push origin main
```
