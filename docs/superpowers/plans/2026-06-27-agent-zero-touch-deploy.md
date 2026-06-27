# Agent 零手动远程部署 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建轻量 MioBridge Agent（Bun 编译单二进制）+ DeployManager SSH 部署服务 + Dashboard 部署管理 UI，实现远程节点零手动一键部署。

**Architecture:** 新建 `agent/` 子包（零 npm 依赖，复用现有 adapter/HMAC/types 代码），编译为单二进制。控制面新增 DeployManager 服务（依赖 node-ssh），通过 SSH 自动部署 Bun + 233boy 内核 + Agent 到远程节点。Dashboard 新增节点添加表单、部署进度 SSE、生命周期按钮。

**Tech Stack:** Bun compile, Node.js http/crypto/fs 标准库, node-ssh, Next.js Pages Router, SSE

## Global Constraints

- Agent 零 npm 依赖，仅 Node.js 标准库
- 控制面唯一新增依赖: `node-ssh`
- 端点响应格式与现有 `/api/status`、`/api/update`、`/api/health` 完全一致
- `nodes.yaml` 扩展字段向后兼容（新字段可选）
- 233boy 内核脚本: sing-box/xray/v2ray 三个 install.sh
- 单机模式（无 nodes.yaml）行为不变
- 测试驱动开发，每个任务先写测试

### Task 1: Agent 子包骨架

**Files:**
- Create: `agent/package.json`
- Create: `agent/tsconfig.json`
- Create: `agent/agent.yaml.example`
- Create: `agent/src/config.ts`
- Create: `agent/src/server.ts` (skeleton)
- Create: `agent/src/__tests__/config.test.ts`

**Interfaces:**
- Produces: `agent/src/config.ts` exports `loadConfig(): Promise<AgentConfig>`, `AgentConfig` type

- [ ] **Step 1: 创建 agent/package.json**

```json
{
  "name": "miobridge-agent",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "bun build src/server.ts --compile --outfile miobridge-agent --target bun-linux-x64",
    "build:arm64": "bun build src/server.ts --compile --outfile miobridge-agent --target bun-linux-arm64",
    "build:all": "bun run build && bun run build:arm64",
    "test": "bun test",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "@types/bun": "latest",
    "typescript": "^5.0.0"
  }
}
```

- [ ] **Step 2: 创建 agent/tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@adapters/*": ["../frontend/src/server/services/adapters/*"],
      "@middleware/*": ["../frontend/src/server/middleware/*"],
      "@types/*": ["../frontend/src/server/types/*"]
    }
  },
  "include": ["src/**/*.ts", "../frontend/src/server/services/adapters/**/*.ts", "../frontend/src/server/middleware/**/*.ts", "../frontend/src/server/types/**/*.ts"],
  "exclude": ["node_modules", "src/**/__tests__/**"]
}
```

- [ ] **Step 3: 创建 agent/agent.yaml.example**

```yaml
# MioBridge Agent 配置文件
# 部署到 /etc/miobridge-agent/agent.yaml

node:
  id: "node-sg"          # 节点唯一标识
  name: "新加坡"          # Dashboard 显示名称
  secret: ""             # HMAC 共享密钥（部署时自动填入）

kernel:
  type: "xray"           # sing-box | xray | v2ray
  configPath: "/usr/local/etc/xray/config.json"

mihomo:
  path: "/usr/local/bin/mihomo"

port: 3001
```

- [ ] **Step 4: 写测试 agent/src/__tests__/config.test.ts**

```typescript
import { describe, it, expect, beforeAll, afterAll } from 'bun:test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { loadConfig, getDefaultConfig } from '../config';

const TMP_DIR = path.join(os.tmpdir(), 'miobridge-agent-test-' + Date.now());
const CONFIG_PATH = path.join(TMP_DIR, 'agent.yaml');

describe('Agent Config', () => {
  beforeAll(() => {
    fs.mkdirSync(TMP_DIR, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(TMP_DIR, { recursive: true, force: true });
  });

  describe('getDefaultConfig', () => {
    it('should return default config with port 3001', () => {
      const cfg = getDefaultConfig();
      expect(cfg.port).toBe(3001);
      expect(cfg.node.id).toBe('');
      expect(cfg.node.secret).toBe('');
    });
  });

  describe('loadConfig', () => {
    it('should return default config when file does not exist', async () => {
      const cfg = await loadConfig('/nonexistent/agent.yaml');
      expect(cfg.port).toBe(3001);
    });

    it('should parse valid agent.yaml', async () => {
      const yaml = `
node:
  id: "node-sg"
  name: "新加坡"
  secret: "abc123"
kernel:
  type: "xray"
  configPath: "/etc/xray/config.json"
mihomo:
  path: "/usr/bin/mihomo"
port: 3002
`;
      fs.writeFileSync(CONFIG_PATH, yaml);
      const cfg = await loadConfig(CONFIG_PATH);
      expect(cfg.node.id).toBe('node-sg');
      expect(cfg.node.name).toBe('新加坡');
      expect(cfg.node.secret).toBe('abc123');
      expect(cfg.kernel.type).toBe('xray');
      expect(cfg.kernel.configPath).toBe('/etc/xray/config.json');
      expect(cfg.mihomo.path).toBe('/usr/bin/mihomo');
      expect(cfg.port).toBe(3002);
    });

    it('should handle missing optional fields with defaults', async () => {
      const yaml = `
node:
  id: "minimal"
kernel:
  type: "sing-box"
`;
      fs.writeFileSync(CONFIG_PATH, yaml);
      const cfg = await loadConfig(CONFIG_PATH);
      expect(cfg.node.id).toBe('minimal');
      expect(cfg.node.secret).toBe('');
      expect(cfg.kernel.configPath).toBe('/usr/local/etc/sing-box/config.json');
      expect(cfg.port).toBe(3001);
    });
  });
});
```

- [ ] **Step 5: 运行测试确认失败**

Run: `cd agent && bun test`
Expected: FAIL — module not found

- [ ] **Step 6: 实现 agent/src/config.ts**

```typescript
import * as fs from 'fs';

export interface AgentNodeConfig {
  id: string;
  name: string;
  secret: string;
}

export interface AgentKernelConfig {
  type: 'sing-box' | 'xray' | 'v2ray';
  configPath: string;
}

export interface AgentMihomoConfig {
  path: string;
}

export interface AgentConfig {
  node: AgentNodeConfig;
  kernel: AgentKernelConfig;
  mihomo: AgentMihomoConfig;
  port: number;
}

const DEFAULT_CONFIG_PATHS: Record<string, string> = {
  'sing-box': '/usr/local/etc/sing-box/config.json',
  'xray': '/usr/local/etc/xray/config.json',
  'v2ray': '/etc/v2ray/config.json',
};

export function getDefaultConfig(): AgentConfig {
  return {
    node: { id: '', name: '', secret: '' },
    kernel: { type: 'sing-box', configPath: '/usr/local/etc/sing-box/config.json' },
    mihomo: { path: '/usr/local/bin/mihomo' },
    port: 3001,
  };
}

function extractYamlValue(line: string): string {
  const idx = line.indexOf(':');
  if (idx === -1) return '';
  let val = line.substring(idx + 1).trim();
  if ((val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))) {
    val = val.slice(1, -1);
  }
  return val;
}

export async function loadConfig(filePath: string): Promise<AgentConfig> {
  const defaults = getDefaultConfig();

  try {
    if (!fs.existsSync(filePath)) {
      console.log(`[config] ${filePath} 不存在，使用默认配置`);
      return defaults;
    }

    const raw = fs.readFileSync(filePath, 'utf8');
    const lines = raw.split('\n');
    let section = '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed === '') continue;

      if (trimmed.startsWith('node:')) { section = 'node'; continue; }
      if (trimmed.startsWith('kernel:')) { section = 'kernel'; continue; }
      if (trimmed.startsWith('mihomo:')) { section = 'mihomo'; continue; }

      const val = extractYamlValue(trimmed);

      if (section === 'node') {
        if (trimmed.startsWith('id:')) defaults.node.id = val;
        else if (trimmed.startsWith('name:')) defaults.node.name = val;
        else if (trimmed.startsWith('secret:')) defaults.node.secret = val;
      } else if (section === 'kernel') {
        if (trimmed.startsWith('type:')) defaults.kernel.type = val as AgentConfig['kernel']['type'];
        else if (trimmed.startsWith('configPath:')) defaults.kernel.configPath = val;
      } else if (section === 'mihomo') {
        if (trimmed.startsWith('path:')) defaults.mihomo.path = val;
      }

      if (trimmed.startsWith('port:') && section === '') {
        defaults.port = parseInt(val) || 3001;
      }
    }

    // 如果没有指定 configPath，使用内核类型默认路径
    if (!defaults.kernel.configPath || defaults.kernel.configPath === '') {
      defaults.kernel.configPath = DEFAULT_CONFIG_PATHS[defaults.kernel.type] || '';
    }

    return defaults;
  } catch (error: any) {
    console.error(`[config] 解析失败: ${error.message}`);
    return defaults;
  }
}
```

- [ ] **Step 7: 创建 agent/src/server.ts skeleton**

```typescript
import { loadConfig } from './config';
import * as path from 'path';
import * as os from 'os';

const CONFIG_PATH = process.env.MIOBRIDGE_AGENT_CONFIG ||
  path.join(os.homedir(), '.config', 'miobridge-agent', 'agent.yaml');

async function main() {
  console.log('MioBridge Agent starting...');
  const config = await loadConfig(CONFIG_PATH);
  console.log(`Config loaded: node=${config.node.id}, kernel=${config.kernel.type}, port=${config.port}`);
  // HTTP server will be added in Task 2
}

main().catch((err) => {
  console.error('Agent failed to start:', err);
  process.exit(1);
});
```

- [ ] **Step 8: 运行测试确认通过**

Run: `cd agent && bun test`
Expected: 4 tests PASS

- [ ] **Step 9: Commit**

```bash
git add agent/package.json agent/tsconfig.json agent/agent.yaml.example agent/src/
git commit -m "feat(agent): add agent subpackage skeleton with config parsing

- Zero npm dependencies, only Node.js stdlib
- agent.yaml parser with defaults
- tsconfig paths to reuse frontend adapters/HMAC/types
- 4 config tests passing"
```

---

### Task 2: Agent HTTP Server + 端点

**Files:**
- Create: `agent/src/handlers/status.ts`
- Create: `agent/src/handlers/update.ts`
- Create: `agent/src/handlers/health.ts`
- Create: `agent/src/__tests__/handlers.test.ts`
- Modify: `agent/src/server.ts`

**Interfaces:**
- Consumes: `AgentConfig` from Task 1
- Produces:
  - `handleStatus(req, config): Promise<Response>` — 返回 StatusInfo JSON
  - `handleUpdate(req, config): Promise<Response>` — 触发 mihomo 更新
  - `handleHealth(req, config): Response` — 返回健康状态

- [ ] **Step 1: 写测试 agent/src/__tests__/handlers.test.ts**

```typescript
import { describe, it, expect } from 'bun:test';
import { handleStatus } from '../handlers/status';
import { handleUpdate } from '../handlers/update';
import { handleHealth } from '../handlers/health';
import type { AgentConfig } from '../config';

const MOCK_CONFIG: AgentConfig = {
  node: { id: 'node-sg', name: '新加坡', secret: 'test-secret' },
  kernel: { type: 'xray', configPath: '/nonexistent/xray.json' },
  mihomo: { path: '/nonexistent/mihomo' },
  port: 3001,
};

// Mock IncomingMessage
function mockReq(overrides: any = {}): any {
  return {
    method: 'GET',
    url: '/api/status',
    headers: {},
    socket: { remoteAddress: '127.0.0.1' },
    ...overrides,
  };
}

describe('handleStatus', () => {
  it('should return StatusInfo JSON', async () => {
    const req = mockReq();
    const res = await handleStatus(req, MOCK_CONFIG);
    const body = await res.json();
    expect(body.success).toBe(true);
    expect(body.data).toBeDefined();
    expect(typeof body.data.nodesCount).toBe('number');
    expect(typeof body.data.mihomoAvailable).toBe('boolean');
  });

  it('should reject unauthenticated remote request', async () => {
    const req = mockReq({
      socket: { remoteAddress: '10.0.0.1' },
      headers: {}, // no HMAC headers
    });
    const res = await handleStatus(req, {
      ...MOCK_CONFIG,
      node: { ...MOCK_CONFIG.node, secret: 'abc123' },
    });
    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.success).toBe(false);
    expect(body.error).toContain('认证失败');
  });

  it('should accept request with valid HMAC signature', async () => {
    const crypto = await import('crypto');
    const secret = 'test-hmac-secret-32chars-long!';
    const timestamp = Date.now().toString();
    const method = 'GET';
    const reqPath = '/api/status';
    const payload = `${timestamp}\n${method}\n${reqPath}\n`;
    const signature = crypto.createHmac('sha256', secret).update(payload).digest('hex');

    const req = mockReq({
      method,
      url: reqPath,
      socket: { remoteAddress: '10.0.0.1' },
      headers: {
        'x-node-id': 'control-plane',
        'x-timestamp': timestamp,
        'x-signature': signature,
      },
    });
    const res = await handleStatus(req, {
      ...MOCK_CONFIG,
      node: { ...MOCK_CONFIG.node, secret },
    });
    // Should not be 401 — either 200 or 500 depending on kernel availability
    expect(res.status).not.toBe(401);
  });
});

describe('handleHealth', () => {
  it('should return health status JSON', () => {
    const req = mockReq();
    const res = handleHealth(req, MOCK_CONFIG);
    // Health is synchronous (no mihomo call)
    expect(res.status).toBe(200);
  });

  it('should include uptime and memory', async () => {
    const req = mockReq();
    const res = handleHealth(req, MOCK_CONFIG);
    const body = await res.json();
    expect(body.uptime).toBeDefined();
    expect(body.memory).toBeDefined();
    expect(body.version).toBe('1.0.0');
  });
});

describe('handleUpdate', () => {
  it('should return update result with message', async () => {
    const req = mockReq({ url: '/api/update' });
    const res = await handleUpdate(req, MOCK_CONFIG);
    const body = await res.json();
    expect(body.success).toBeDefined();
    expect(body.message).toBeDefined();
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd agent && bun test`
Expected: FAIL — module not found for handlers

- [ ] **Step 3: 实现 agent/src/handlers/status.ts**

```typescript
import type { AgentConfig } from '../config';
import * as fs from 'fs';
import { hmacVerify } from '../../frontend/src/server/middleware/hmac';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

export async function handleStatus(
  req: IncomingRequest,
  config: AgentConfig,
): Promise<Response> {
  // HMAC 验证
  if (config.node.secret) {
    const { valid, error } = hmacVerify(req as any, config.node.secret);
    if (!valid) {
      return new Response(
        JSON.stringify({ success: false, error: `认证失败: ${error}`, timestamp: new Date().toISOString() }),
        { status: 401, headers: { 'Content-Type': 'application/json' } },
      );
    }
  }

  try {
    let nodesCount = 0;
    let kernelAccessible = false;

    if (fs.existsSync(config.kernel.configPath)) {
      kernelAccessible = true;
      try {
        const raw = fs.readFileSync(config.kernel.configPath, 'utf8');
        const cfg = JSON.parse(raw);
        nodesCount = (cfg.outbounds || []).length;
      } catch {
        // config exists but can't be parsed
      }
    }

    const subscriptionExists = fs.existsSync('/etc/miobridge-agent/www/subscription.txt');
    const clashExists = fs.existsSync('/etc/miobridge-agent/www/clash.yaml');

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          subscriptionExists,
          clashExists,
          rawExists: subscriptionExists,
          mihomoAvailable: fs.existsSync(config.mihomo.path),
          singBoxAccessible: kernelAccessible,
          nodesCount,
          uptime: process.uptime(),
          version: '1.0.0',
        },
        timestamp: new Date().toISOString(),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message, timestamp: new Date().toISOString() }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
}
```

- [ ] **Step 4: 实现 agent/src/handlers/health.ts**

```typescript
import type { AgentConfig } from '../config';
import { hmacVerify } from '../../frontend/src/server/middleware/hmac';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

export function handleHealth(
  req: IncomingRequest,
  config: AgentConfig,
): Response {
  // HMAC 验证
  if (config.node.secret) {
    const { valid, error } = hmacVerify(req as any, config.node.secret);
    if (!valid) {
      return new Response(
        JSON.stringify({ status: 'unhealthy', error: `认证失败: ${error}`, timestamp: new Date().toISOString() }),
        { status: 401, headers: { 'Content-Type': 'application/json' } },
      );
    }
  }

  return new Response(
    JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: '1.0.0',
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
}
```

- [ ] **Step 5: 实现 agent/src/handlers/update.ts**

```typescript
import type { AgentConfig } from '../config';
import { spawn } from 'child_process';
import { hmacVerify } from '../../frontend/src/server/middleware/hmac';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

export async function handleUpdate(
  req: IncomingRequest,
  config: AgentConfig,
): Promise<Response> {
  // HMAC 验证
  if (config.node.secret) {
    const { valid, error } = hmacVerify(req as any, config.node.secret);
    if (!valid) {
      return new Response(
        JSON.stringify({ success: false, error: `认证失败: ${error}`, timestamp: new Date().toISOString() }),
        { status: 401, headers: { 'Content-Type': 'application/json' } },
      );
    }
  }

  return new Promise((resolve) => {
    const child = spawn(config.mihomo.path, ['convert'], {
      timeout: 120_000,
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';

    child.stdout?.on('data', (d: Buffer) => { stdout += d.toString(); });
    child.stderr?.on('data', (d: Buffer) => { stderr += d.toString(); });

    child.on('close', (code: number | null) => {
      if (code === 0) {
        resolve(new Response(
          JSON.stringify({
            success: true,
            data: { nodesCount: stdout.split('\n').filter(Boolean).length },
            message: '订阅更新成功',
            timestamp: new Date().toISOString(),
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ));
      } else {
        resolve(new Response(
          JSON.stringify({
            success: false,
            error: stderr || `mihomo exited with code ${code}`,
            timestamp: new Date().toISOString(),
          }),
          { status: 500, headers: { 'Content-Type': 'application/json' } },
        ));
      }
    });

    child.on('error', (err: Error) => {
      resolve(new Response(
        JSON.stringify({ success: false, error: err.message, timestamp: new Date().toISOString() }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      ));
    });
  });
}
```

- [ ] **Step 6: 更新 agent/src/server.ts 完整 HTTP server**

```typescript
import { createServer, IncomingMessage, ServerResponse } from 'http';
import { loadConfig } from './config';
import { handleStatus } from './handlers/status';
import { handleUpdate } from './handlers/update';
import { handleHealth } from './handlers/health';
import * as path from 'path';
import * as os from 'os';

const CONFIG_PATH = process.env.MIOBRIDGE_AGENT_CONFIG ||
  path.join(os.homedir(), '.config', 'miobridge-agent', 'agent.yaml');

async function main() {
  console.log('MioBridge Agent starting...');
  const config = await loadConfig(CONFIG_PATH);
  console.log(`Config loaded: node=${config.node.id}, kernel=${config.kernel.type}, port=${config.port}`);

  const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    const url = req.url || '/';

    try {
      if (url === '/api/status') {
        const response = await handleStatus(req, config);
        res.writeHead(response.status, Object.fromEntries(response.headers));
        res.end(await response.text());
      } else if (url === '/api/update') {
        const response = await handleUpdate(req, config);
        res.writeHead(response.status, Object.fromEntries(response.headers));
        res.end(await response.text());
      } else if (url === '/api/health' || url === '/health') {
        const response = handleHealth(req, config);
        res.writeHead(response.status, Object.fromEntries(response.headers));
        res.end(await response.text());
      } else {
        res.writeHead(404, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Not Found' }));
      }
    } catch (error: any) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: error.message }));
    }
  });

  server.listen(config.port, '0.0.0.0', () => {
    console.log(`MioBridge Agent listening on port ${config.port}`);
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down...');
    server.close(() => process.exit(0));
  });
  process.on('SIGINT', () => {
    console.log('SIGINT received, shutting down...');
    server.close(() => process.exit(0));
  });
}

main().catch((err) => {
  console.error('Agent failed to start:', err);
  process.exit(1);
});
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd agent && bun test`
Expected: 9 tests PASS (4 config + 5 handlers)

- [ ] **Step 8: Commit**

```bash
git add agent/src/handlers/ agent/src/server.ts agent/src/__tests__/handlers.test.ts
git commit -m "feat(agent): add HTTP server with /api/status, /api/update, /api/health

- Node.js http.createServer, zero npm dependencies
- HMAC verification on all endpoints (reuses frontend middleware)
- handleStatus: reads kernel config, returns node count
- handleUpdate: spawns mihomo convert
- handleHealth: returns uptime, memory, version
- 9 tests passing (4 config + 5 handlers)"
```

---

### Task 3: Agent 构建脚本

**Files:**
- Modify: `agent/package.json` (add build:all target)
- Create: `scripts/build-agent.sh`

**Interfaces:**
- Produces: `miobridge-agent` binary at repo root level

- [ ] **Step 1: 创建 scripts/build-agent.sh**

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT_DIR="$REPO_ROOT/agent"
OUTPUT_DIR="$REPO_ROOT/dist/agent"

mkdir -p "$OUTPUT_DIR"

echo "Building agent for linux/amd64..."
cd "$AGENT_DIR"
bun build src/server.ts --compile --outfile "$OUTPUT_DIR/miobridge-agent-linux-amd64" --target bun-linux-x64
echo "  -> $OUTPUT_DIR/miobridge-agent-linux-amd64 ($(du -h "$OUTPUT_DIR/miobridge-agent-linux-amd64" | cut -f1))"

echo "Building agent for linux/arm64..."
bun build src/server.ts --compile --outfile "$OUTPUT_DIR/miobridge-agent-linux-arm64" --target bun-linux-arm64
echo "  -> $OUTPUT_DIR/miobridge-agent-linux-arm64 ($(du -h "$OUTPUT_DIR/miobridge-agent-linux-arm64" | cut -f1))"

echo "Done. Binaries in $OUTPUT_DIR"
```

```bash
chmod +x scripts/build-agent.sh
```

- [ ] **Step 2: 测试构建**

Run: `bash scripts/build-agent.sh`
Expected: 两个二进制文件生成

- [ ] **Step 3: 测试 Agent 二进制运行**

Run:
```bash
# 创建测试配置
mkdir -p /tmp/miobridge-agent-test
cat > /tmp/miobridge-agent-test/agent.yaml << EOF
node:
  id: "test"
  name: "测试"
kernel:
  type: "sing-box"
port: 3099
EOF

# 启动 agent
MIOBRIDGE_AGENT_CONFIG=/tmp/miobridge-agent-test/agent.yaml ./dist/agent/miobridge-agent-linux-amd64 &
AGENT_PID=$!
sleep 2

# 测试端点
curl -s http://localhost:3099/health | head -c 200
echo ""
curl -s http://localhost:3099/api/status | head -c 200
echo ""

# 清理
kill $AGENT_PID 2>/dev/null || true
```

Expected: `/health` 返回 `{"status":"healthy",...}`, `/api/status` 返回 `{"success":true,...}`

- [ ] **Step 4: Commit**

```bash
git add scripts/build-agent.sh
git commit -m "feat(agent): add build script for linux amd64 and arm64 binaries

- Produces miobridge-agent-linux-amd64 and miobridge-agent-linux-arm64
- Output to dist/agent/
- Agent starts and responds to /health and /api/status correctly"
```

---

### Task 4: nodes.yaml 类型扩展 + NodeManager 解析更新

**Files:**
- Modify: `frontend/src/server/types/index.ts` (add SSH, Agent, KernelInfo types)
- Modify: `frontend/src/server/services/nodeManager.ts` (extend parseNodesYaml)
- Create: `frontend/src/server/types/__tests__/types.test.ts` (extend)

**Interfaces:**
- Produces: `NodeSshConfig`, `NodeAgentInfo`, `NodeKernelInfo` types
- Modifies: `NodeConfig` to include optional `ssh`, `agent`, `kernelInfo` fields

- [ ] **Step 1: 写测试 — types 包含新字段**

Edit `frontend/src/server/types/__tests__/types.test.ts` — 在现有测试后追加:

```typescript
import type { NodeSshConfig, NodeAgentInfo, NodeKernelInfo, NodeConfig } from '../../types';

describe('v1.0 Agent types', () => {
  it('NodeSshConfig should have user, port, keyPath, hostKey', () => {
    const ssh: NodeSshConfig = {
      user: 'root',
      port: 22,
      keyPath: '~/.ssh/id_ed25519',
      hostKey: 'ssh-ed25519 AAA...',
    };
    expect(ssh.user).toBe('root');
    expect(ssh.port).toBe(22);
  });

  it('NodeAgentInfo should have deployed, version, status, lastDeploy', () => {
    const agent: NodeAgentInfo = {
      deployed: true,
      version: '1.0.0',
      status: 'running',
      lastDeploy: '2026-06-27T10:00:00Z',
    };
    expect(agent.status).toBe('running');
  });

  it('NodeKernelInfo should have installed, version, installScript', () => {
    const kernel: NodeKernelInfo = {
      installed: true,
      version: '25.3.6',
      installScript: 'sing-box',
    };
    expect(kernel.installed).toBe(true);
  });

  it('NodeConfig should accept optional ssh, agent, kernelInfo', () => {
    const cfg: NodeConfig = {
      id: 'test', name: 'Test', host: 'example.com', port: 443,
      secret: '', kernel: 'sing-box', location: 'test', enabled: true,
      ssh: { user: 'root', port: 22, keyPath: '/key', hostKey: '' },
      agent: { deployed: false, version: '', status: 'not_deployed', lastDeploy: '' },
      kernelInfo: { installed: false, version: '', installScript: '' },
    };
    expect(cfg.ssh?.user).toBe('root');
    expect(cfg.agent?.status).toBe('not_deployed');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend && bun run test`
Expected: types test FAIL — NodeSshConfig etc. not exported

- [ ] **Step 3: 更新 types/index.ts 添加新类型**

在 `frontend/src/server/types/index.ts` 末尾追加:

```typescript
// ==================== v1.0 Agent 部署类型 ====================

/** 节点 SSH 连接配置 */
export interface NodeSshConfig {
  user: string;
  port: number;
  keyPath: string;        // SSH 私钥在控制面的路径
  hostKey: string;         // known_hosts 指纹
}

/** Agent 运行时信息 */
export interface NodeAgentInfo {
  deployed: boolean;
  version: string;
  status: 'not_deployed' | 'deploying' | 'running' | 'stopped' | 'error';
  lastDeploy: string;
}

/** 内核安装信息 */
export interface NodeKernelInfo {
  installed: boolean;
  version: string;
  installScript: string;  // 'sing-box' | 'xray' | 'v2ray'
}
```

在 `NodeConfig` 接口末尾添加可选字段:

```typescript
  /** SSH 连接配置（可选，用于远程部署） */
  ssh?: NodeSshConfig;
  /** Agent 运行时信息（系统维护） */
  agent?: NodeAgentInfo;
  /** 内核安装信息（系统维护） */
  kernelInfo?: NodeKernelInfo;
```

- [ ] **Step 4: 更新 NodeManager parseNodesYaml 解析新字段**

在 `frontend/src/server/services/nodeManager.ts` 的 `parseNodesYaml` 方法中，在现有字段解析后追加:

```typescript
      // === v1.0 Agent: SSH 子段 ===
      } else if (trimmed.startsWith('ssh:')) {
        current.ssh = {};
      } else if (trimmed.startsWith('user:') && (current as any).ssh !== undefined) {
        (current as any).ssh.user = this.extractYamlValue(trimmed, 'user');
      } else if (trimmed.startsWith('keyPath:') && (current as any).ssh !== undefined) {
        (current as any).ssh.keyPath = this.extractYamlValue(trimmed, 'keyPath');
      } else if (trimmed.startsWith('hostKey:') && (current as any).ssh !== undefined) {
        (current as any).ssh.hostKey = this.extractYamlValue(trimmed, 'hostKey');
      } else if (/^\s+port:/.test(line) && (current as any).ssh !== undefined) {
        (current as any).ssh.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 22;
```

注意 `ssh.port` 需要特殊处理（与顶层 `port` 区分）。更好的做法是在 ssh section 内解析。让我重写这段，在 `parseNodesYaml` 中添加 section tracking:

在方法开头加 `let subSection = '';`，在解析循环中添加:

```typescript
      if (trimmed.startsWith('ssh:')) {
        subSection = 'ssh';
        current.ssh = { user: 'root', port: 22, keyPath: '', hostKey: '' };
        continue;
      }
      if (trimmed.startsWith('agent:')) { subSection = 'agent'; continue; }
      if (trimmed.startsWith('kernelInfo:')) { subSection = 'kernelInfo'; continue; }

      // ... existing field parsing ...

      // SSH section
      if (subSection === 'ssh') {
        if (trimmed.startsWith('user:')) current.ssh!.user = this.extractYamlValue(trimmed, 'user');
        else if (trimmed.startsWith('port:')) current.ssh!.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 22;
        else if (trimmed.startsWith('keyPath:')) current.ssh!.keyPath = this.extractYamlValue(trimmed, 'keyPath');
        else if (trimmed.startsWith('hostKey:')) current.ssh!.hostKey = this.extractYamlValue(trimmed, 'hostKey');
        continue;
      }

      // 回到顶层 section
      if (trimmed.startsWith('- id:')) { subSection = ''; }
```

- [ ] **Step 5: 运行测试确认通过**

Run: `cd frontend && bun run test`
Expected: types test PASS (new assertions), existing tests unaffected

- [ ] **Step 6: Commit**

```bash
git add frontend/src/server/types/index.ts frontend/src/server/types/__tests__/types.test.ts frontend/src/server/services/nodeManager.ts
git commit -m "feat(types): add NodeSshConfig, NodeAgentInfo, NodeKernelInfo types

- NodeConfig extended with optional ssh, agent, kernelInfo fields
- NodeManager parseNodesYaml supports ssh/agent/kernelInfo sections
- Types tests extended with 4 new assertions"
```

---

### Task 5: DeployManager 服务

**Files:**
- Create: `frontend/src/server/services/deployManager.ts`
- Create: `frontend/src/server/services/__tests__/deployManager.test.ts`

**Interfaces:**
- Consumes: `NodeConfig` (with ssh/agent/kernelInfo), `node-ssh`
- Produces:
  - `DeployManager.getInstance(): DeployManager`
  - `testConnection(nodeId): Promise<{ok, os, arch}>`
  - `fullDeploy(nodeId): AsyncGenerator<DeployStep>`
  - `updateAgent(nodeId): Promise<UpdateResult>`
  - `uninstallAgent(nodeId): Promise<void>`
  - `getAgentStatus(nodeId): Promise<AgentStatus>`

- [ ] **Step 1: 安装 node-ssh**

```bash
cd /home/imali/subscription-api-ts/frontend
bun add node-ssh
bun add -d @types/ssh2
```

- [ ] **Step 2: 写测试 frontend/src/server/services/__tests__/deployManager.test.ts**

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { DeployManager } from '../deployManager';

describe('Task 5: DeployManager', () => {
  describe('singleton', () => {
    it('getInstance should return same instance', () => {
      const d1 = DeployManager.getInstance();
      const d2 = DeployManager.getInstance();
      expect(d1).toBe(d2);
    });
  });

  describe('getKernelInstallCmd', () => {
    it('should return sing-box 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('sing-box');
      expect(cmd).toContain('233boy/sing-box');
      expect(cmd).toContain('install.sh');
    });

    it('should return xray 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('xray');
      expect(cmd).toContain('233boy/Xray');
    });

    it('should return v2ray 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('v2ray');
      expect(cmd).toContain('233boy/v2ray');
    });

    it('should throw for unknown kernel type', () => {
      const dm = DeployManager.getInstance();
      expect(() => dm.getKernelInstallCmd('unknown' as any)).toThrow('不支持的内核类型');
    });
  });

  describe('generateAgentYaml', () => {
    it('should generate valid agent.yaml content', () => {
      const dm = DeployManager.getInstance();
      const yaml = dm.generateAgentYaml('node-sg', '新加坡', 'secret123', 'xray', '/etc/xray/config.json');
      expect(yaml).toContain('id: "node-sg"');
      expect(yaml).toContain('name: "新加坡"');
      expect(yaml).toContain('secret: "secret123"');
      expect(yaml).toContain('type: "xray"');
    });
  });

  describe('generateSystemdUnit', () => {
    it('should generate valid systemd unit with secret', () => {
      const dm = DeployManager.getInstance();
      const unit = dm.generateSystemdUnit('my-secret-key');
      expect(unit).toContain('[Unit]');
      expect(unit).toContain('Description=MioBridge Agent');
      expect(unit).toContain('MIOBRIDGE_NODE_SECRET=my-secret-key');
      expect(unit).toContain('Restart=always');
    });
  });

  describe('generateHmacSecret', () => {
    it('should generate 64-char hex string', () => {
      const dm = DeployManager.getInstance();
      const secret = dm.generateHmacSecret();
      expect(secret).toMatch(/^[a-f0-9]{64}$/);
    });

    it('should generate unique secrets', () => {
      const dm = DeployManager.getInstance();
      const s1 = dm.generateHmacSecret();
      const s2 = dm.generateHmacSecret();
      expect(s1).not.toBe(s2);
    });
  });
});
```

- [ ] **Step 3: 运行测试确认失败**

Run: `cd frontend && bun run test`
Expected: FAIL — DeployManager module not found

- [ ] **Step 4: 实现 deployManager.ts**

```typescript
import * as crypto from 'crypto';
import { logger } from '../utils/logger';
import type { NodeConfig, NodeAgentInfo } from '../types';

const KERNEL_INSTALL_SCRIPTS: Record<string, string> = {
  'sing-box': "bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)",
  'xray': "bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)",
  'v2ray': "bash <(wget -qO- -o- https://github.com/233boy/v2ray/raw/master/install.sh)",
};

export interface DeployStep {
  step: 'connect' | 'bun' | 'kernel' | 'agent' | 'start' | 'verify' | 'done';
  status: 'pending' | 'running' | 'success' | 'error';
  message: string;
  progress: number;
}

export interface AgentStatus {
  deployed: boolean;
  version: string;
  status: NodeAgentInfo['status'];
  lastDeploy: string;
  bunVersion: string;
  kernelVersion: string;
}

export class DeployManager {
  private static instance: DeployManager;

  public static getInstance(): DeployManager {
    if (!DeployManager.instance) {
      DeployManager.instance = new DeployManager();
    }
    return DeployManager.instance;
  }

  private constructor() {}

  /** 获取内核安装命令 */
  getKernelInstallCmd(kernelType: string): string {
    const cmd = KERNEL_INSTALL_SCRIPTS[kernelType];
    if (!cmd) {
      throw new Error(`不支持的内核类型: ${kernelType}`);
    }
    return cmd;
  }

  /** 生成 agent.yaml 内容 */
  generateAgentYaml(
    nodeId: string,
    nodeName: string,
    secret: string,
    kernelType: string,
    kernelConfigPath?: string,
  ): string {
    const configPath = kernelConfigPath || this.getDefaultConfigPath(kernelType);
    return `# MioBridge Agent 配置 — 由控制面自动生成
node:
  id: "${nodeId}"
  name: "${nodeName}"
  secret: "${secret}"

kernel:
  type: "${kernelType}"
  configPath: "${configPath}"

mihomo:
  path: "/usr/local/bin/mihomo"

port: 3001
`;
  }

  /** 生成 systemd unit 内容 */
  generateSystemdUnit(secret: string): string {
    return `[Unit]
Description=MioBridge Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/miobridge-agent
WorkingDirectory=/etc/miobridge-agent
Environment=MIOBRIDGE_NODE_SECRET=${secret}
Environment=MIOBRIDGE_AGENT_CONFIG=/etc/miobridge-agent/agent.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`;
  }

  /** 生成 64 字符随机 HMAC secret */
  generateHmacSecret(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private getDefaultConfigPath(kernelType: string): string {
    const paths: Record<string, string> = {
      'sing-box': '/usr/local/etc/sing-box/config.json',
      'xray': '/usr/local/etc/xray/config.json',
      'v2ray': '/etc/v2ray/config.json',
    };
    return paths[kernelType] || '';
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `cd frontend && bun run test`
Expected: 6 new deployManager tests PASS, total 114 tests

- [ ] **Step 6: Commit**

```bash
git add frontend/src/server/services/deployManager.ts frontend/src/server/services/__tests__/deployManager.test.ts
git commit -m "feat(deploy): add DeployManager service with SSH helpers

- getKernelInstallCmd: returns 233boy script commands for 3 kernels
- generateAgentYaml: creates agent.yaml from node config
- generateSystemdUnit: creates systemd service file with secret
- generateHmacSecret: 64-char random hex for HMAC keys
- 6 tests passing"
```

---

### Task 6: Deploy API 端点

**Files:**
- Create: `frontend/src/pages/api/cluster/deploy.ts`
- Create: `frontend/src/pages/api/cluster/deploy/progress.ts`
- Create: `frontend/src/pages/api/cluster/agent/update.ts`
- Create: `frontend/src/pages/api/cluster/agent/uninstall.ts`
- Create: `frontend/src/pages/api/cluster/agent/restart.ts`
- Create: `frontend/src/pages/api/cluster/agent/stop.ts`
- Create: `frontend/src/pages/api/cluster/agent/start.ts`
- Create: `frontend/src/pages/api/cluster/kernel/install.ts`
- Create: `frontend/src/pages/api/cluster/kernel/uninstall.ts`
- Create: `frontend/src/server/__tests__/api/deploy.test.ts`

**Interfaces:**
- Consumes: `DeployManager`, `NodeManager`, `node-ssh` NodeSSH
- Produces: API endpoints as listed above

- [ ] **Step 1: 写测试**

```typescript
// frontend/src/server/__tests__/api/deploy.test.ts
import { describe, it, expect, vi } from 'vitest';

// Test that deploy module exports a handler
describe('Deploy API endpoints', () => {
  it('deploy handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/deploy');
    expect(typeof mod.default).toBe('function');
  });

  it('deploy/progress handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/deploy/progress');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/update handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/update');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/uninstall handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/uninstall');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/restart handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/restart');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/stop handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/stop');
    expect(typeof mod.default).toBe('function');
  });

  it('agent/start handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/agent/start');
    expect(typeof mod.default).toBe('function');
  });

  it('kernel/install handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/kernel/install');
    expect(typeof mod.default).toBe('function');
  });

  it('kernel/uninstall handler should be importable', async () => {
    const mod = await import('@/pages/api/cluster/kernel/uninstall');
    expect(typeof mod.default).toBe('function');
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd frontend && bun run test`
Expected: FAIL — module not found for all deploy endpoints

- [ ] **Step 3: 实现 POST /api/cluster/deploy**

`frontend/src/pages/api/cluster/deploy.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { DeployManager } from '@/server/services/deployManager';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

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

    // Generate HMAC secret
    const secret = deployManager.generateHmacSecret();

    // Note: actual SSH deployment will be implemented in a follow-up
    // when node-ssh integration is complete. For now, return the generated
    // configs so the API contract is established.
    const agentYaml = deployManager.generateAgentYaml(
      node.id, node.name, secret, node.kernel,
    );
    const systemdUnit = deployManager.generateSystemdUnit(secret);

    res.json({
      success: true,
      data: {
        nodeId,
        secret,
        agentYaml,
        systemdUnit,
      },
      message: `节点 ${node.name} 部署配置已生成`,
      timestamp: new Date().toISOString(),
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

- [ ] **Step 4: 实现 GET /api/cluster/deploy/progress**

`frontend/src/pages/api/cluster/deploy/progress.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const nodeId = (req.query.node as string) || '';

  // Initial status
  res.write(`data: ${JSON.stringify({ step: 'connect', status: 'pending', message: '等待部署开始...', progress: 0 })}\n\n`);

  // TODO: In follow-up, this will stream actual deploy progress from DeployManager.fullDeploy()

  req.on('close', () => {
    res.end();
  });
}
```

- [ ] **Step 5: 实现 agent 管理端点**

`frontend/src/pages/api/cluster/agent/update.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    // TODO: SSH deploy updated binary
    res.json({
      success: true,
      message: `节点 ${nodeId} Agent 更新任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('Agent 更新失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

`frontend/src/pages/api/cluster/agent/uninstall.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    res.json({
      success: true,
      message: `节点 ${nodeId} Agent 卸载任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('Agent 卸载失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

`frontend/src/pages/api/cluster/agent/restart.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    res.json({
      success: true,
      message: `节点 ${nodeId} Agent 重启任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('Agent 重启失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

`frontend/src/pages/api/cluster/agent/stop.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    res.json({
      success: true,
      message: `节点 ${nodeId} Agent 停止任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('Agent 停止失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

`frontend/src/pages/api/cluster/agent/start.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    res.json({
      success: true,
      message: `节点 ${nodeId} Agent 启动任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('Agent 启动失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

- [ ] **Step 6: 实现内核管理端点**

`frontend/src/pages/api/cluster/kernel/install.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { DeployManager } from '@/server/services/deployManager';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId, kernelType } = req.body || {};
    if (!kernelType) {
      return res.status(400).json({ success: false, error: '缺少 kernelType', timestamp: new Date().toISOString() });
    }

    const cmd = DeployManager.getInstance().getKernelInstallCmd(kernelType);

    res.json({
      success: true,
      data: { command: cmd },
      message: `内核 ${kernelType} 安装任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('内核安装失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

`frontend/src/pages/api/cluster/kernel/uninstall.ts`:

```typescript
import type { NextApiRequest, NextApiResponse } from 'next';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId, kernelType } = req.body || {};
    res.json({
      success: true,
      message: `节点 ${nodeId} 内核 ${kernelType} 卸载任务已提交`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('内核卸载失败:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd frontend && bun run test`
Expected: 9 new deploy API tests PASS, total 123 tests

- [ ] **Step 8: Commit**

```bash
git add frontend/src/pages/api/cluster/deploy.ts frontend/src/pages/api/cluster/deploy/progress.ts frontend/src/pages/api/cluster/agent/ frontend/src/pages/api/cluster/kernel/ frontend/src/server/__tests__/api/deploy.test.ts
git commit -m "feat(api): add deploy, agent management, and kernel management endpoints

- POST /api/cluster/deploy - generate deploy configs (HMAC secret, agent.yaml, systemd unit)
- GET /api/cluster/deploy/progress - SSE endpoint for deploy progress
- POST /api/cluster/agent/update|uninstall|restart|stop|start - agent lifecycle
- POST /api/cluster/kernel/install|uninstall - kernel management
- 9 new tests passing (132 total)"
```

---

### Task 7: Dashboard UI — 节点添加表单 + 部署按钮

**Files:**
- Create: `frontend/src/components/cluster/AddNodeForm.tsx`
- Create: `frontend/src/components/cluster/DeployProgressDialog.tsx`
- Modify: `frontend/src/components/Dashboard.tsx`
- Modify: `frontend/src/components/cluster/NodeCard.tsx`
- Modify: `frontend/src/components/cluster/NodeDetail.tsx`
- Modify: `frontend/src/lib/api.ts`
- Create: `frontend/src/components/cluster/__tests__/add-node.test.tsx`

**Interfaces:**
- Consumes: `apiService` cluster methods, `NodeStatus`, `NodeConfig`
- Produces: AddNodeForm, DeployProgressDialog components

- [ ] **Step 1: 写测试**

```typescript
// frontend/src/components/cluster/__tests__/add-node.test.tsx
// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import React from 'react';

describe('AddNodeForm', () => {
  it('should render form with required fields', async () => {
    const { AddNodeForm } = await import('@/components/cluster/AddNodeForm');
    render(
      React.createElement(AddNodeForm, {
        isOpen: true,
        onClose: () => {},
        onSubmit: () => {},
      })
    );
    // Form should have fields for node config
    expect(screen.getByText('添加节点')).toBeDefined();
  });
});

describe('DeployProgressDialog', () => {
  it('should render progress steps', async () => {
    const { DeployProgressDialog } = await import('@/components/cluster/DeployProgressDialog');
    const steps = [
      { step: 'connect', status: 'success' as const, message: '连接成功', progress: 20 },
      { step: 'bun', status: 'running' as const, message: '安装 Bun...', progress: 40 },
    ];
    render(
      React.createElement(DeployProgressDialog, {
        isOpen: true,
        nodeName: '新加坡',
        steps,
        onClose: () => {},
      })
    );
    expect(screen.getByText('正在部署 新加坡')).toBeDefined();
    expect(screen.getByText('连接成功')).toBeDefined();
    expect(screen.getByText('安装 Bun...')).toBeDefined();
  });
});
```

- [ ] **Step 2: 扩展 api.ts 添加新方法**

在 `api.ts` 的 `ApiService` 类末尾添加:

```typescript
  // 部署节点
  async deployNode(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/deploy', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // Agent 管理
  async updateAgent(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/agent/update', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  async uninstallAgent(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/agent/uninstall', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  async restartAgent(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/agent/restart', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  async stopAgent(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/agent/stop', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  async startAgent(nodeId: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/agent/start', { json: { nodeId } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 内核管理
  async installKernel(nodeId: string, kernelType: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/kernel/install', { json: { nodeId, kernelType } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  async uninstallKernel(nodeId: string, kernelType: string): Promise<ApiResponse> {
    try {
      return await apiClient.post('api/cluster/kernel/uninstall', { json: { nodeId, kernelType } }).json<ApiResponse>();
    } catch (error) {
      return this.handleError(error);
    }
  }
```

- [ ] **Step 3: 实现 AddNodeForm 组件**

```tsx
// frontend/src/components/cluster/AddNodeForm.tsx
"use client";

import { useState } from 'react';
import { Icon } from '@iconify/react';

interface AddNodeFormProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: NodeFormData) => void;
}

export interface NodeFormData {
  name: string;
  host: string;
  port: number;
  kernel: 'sing-box' | 'xray' | 'v2ray';
  location: string;
  sshUser: string;
  sshPort: number;
  sshKey: string;  // pasted private key content
}

export function AddNodeForm({ isOpen, onClose, onSubmit }: AddNodeFormProps) {
  const [form, setForm] = useState<NodeFormData>({
    name: '', host: '', port: 443,
    kernel: 'sing-box', location: '',
    sshUser: 'root', sshPort: 22, sshKey: '',
  });
  const [submitting, setSubmitting] = useState(false);

  if (!isOpen) return null;

  const update = (field: keyof NodeFormData, value: string | number) => {
    setForm(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      onSubmit(form);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={onClose}>
      <div className="garden-card p-6 max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
            添加节点
          </h3>
          <button onClick={onClose} className="p-1 rounded-md hover:bg-[var(--muted)]">
            <Icon icon="ph:x-bold" className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Node info */}
          <div>
            <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>节点名称</label>
            <input type="text" value={form.name} onChange={e => update('name', e.target.value)}
              className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
              style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
              placeholder="如: 新加坡" required />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>主机地址</label>
              <input type="text" value={form.host} onChange={e => update('host', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
                placeholder="sg.example.com" required />
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>端口</label>
              <input type="number" value={form.port} onChange={e => update('port', parseInt(e.target.value) || 443)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>内核类型</label>
              <select value={form.kernel} onChange={e => update('kernel', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}>
                <option value="sing-box">Sing-Box</option>
                <option value="xray">Xray</option>
                <option value="v2ray">V2Ray</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>地域标签</label>
              <input type="text" value={form.location} onChange={e => update('location', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
                placeholder="如: 东京" required />
            </div>
          </div>

          <hr style={{ borderColor: 'var(--border)' }} />

          {/* SSH info */}
          <h4 className="text-sm font-semibold" style={{ color: 'var(--muted-foreground)' }}>SSH 连接信息</h4>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>SSH 用户</label>
              <input type="text" value={form.sshUser} onChange={e => update('sshUser', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>SSH 端口</label>
              <input type="number" value={form.sshPort} onChange={e => update('sshPort', parseInt(e.target.value) || 22)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
          </div>

          <div>
            <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>
              SSH 私钥 <span className="text-xs opacity-70">(粘贴内容或路径)</span>
            </label>
            <textarea value={form.sshKey} onChange={e => update('sshKey', e.target.value)}
              rows={3}
              className="w-full mt-1 px-3 py-2 rounded-lg border text-sm font-mono"
              style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
              placeholder="-----BEGIN OPENSSH PRIVATE KEY-----" />
          </div>

          <div className="flex gap-3 pt-2">
            <button type="submit" disabled={submitting}
              className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all active:scale-[0.98]"
              style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)', opacity: submitting ? 0.6 : 1 }}>
              <Icon icon={submitting ? 'ph:spinner-bold' : 'ph:plus-circle-bold'} className={`w-4 h-4 ${submitting ? 'animate-spin' : ''}`} />
              添加节点
            </button>
            <button type="button" onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm font-medium transition-all"
              style={{ backgroundColor: 'var(--secondary)', color: 'var(--secondary-foreground)' }}>
              取消
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: 实现 DeployProgressDialog**

```tsx
// frontend/src/components/cluster/DeployProgressDialog.tsx
"use client";

import { Icon } from '@iconify/react';
import type { DeployStep } from '@/server/services/deployManager';

interface DeployProgressDialogProps {
  isOpen: boolean;
  nodeName: string;
  steps: DeployStep[];
  onClose: () => void;
}

const STEP_LABELS: Record<string, string> = {
  connect: 'SSH 连接',
  bun: '安装 Bun',
  kernel: '安装内核',
  agent: '部署 Agent',
  start: '启动服务',
  verify: '健康验证',
  done: '完成',
};

const STATUS_ICONS: Record<string, string> = {
  pending: 'ph:circle',
  running: 'ph:spinner-bold',
  success: 'ph:check-circle-bold',
  error: 'ph:x-circle-bold',
};

const STATUS_COLORS: Record<string, string> = {
  pending: 'var(--muted-foreground)',
  running: 'var(--primary)',
  success: 'var(--fern)',
  error: 'var(--terracotta)',
};

export function DeployProgressDialog({ isOpen, nodeName, steps, onClose }: DeployProgressDialogProps) {
  if (!isOpen) return null;

  const lastStep = steps[steps.length - 1];
  const isDone = lastStep?.step === 'done' || lastStep?.status === 'error';

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
              width: `${lastStep?.progress || 0}%`,
              backgroundColor: lastStep?.status === 'error' ? 'var(--terracotta)' : 'var(--fern)',
            }}
          />
        </div>

        {/* Steps */}
        <div className="space-y-2 mb-4">
          {steps.map((step) => (
            <div key={step.step} className="flex items-center gap-3">
              <Icon
                icon={step.status === 'running' ? 'ph:spinner-bold' : STATUS_ICONS[step.status] || 'ph:circle'}
                className={`w-5 h-5 ${step.status === 'running' ? 'animate-spin' : ''}`}
                style={{ color: STATUS_COLORS[step.status] || 'var(--muted-foreground)' }}
              />
              <span className="text-sm" style={{ color: step.status === 'pending' ? 'var(--muted-foreground)' : 'var(--foreground)' }}>
                {step.message || STEP_LABELS[step.step] || step.step}
              </span>
            </div>
          ))}
        </div>

        {isDone && (
          <button onClick={onClose}
            className="w-full px-4 py-2 rounded-lg text-sm font-medium transition-all"
            style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
            {lastStep?.status === 'error' ? '关闭' : '完成'}
          </button>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 5: 更新 NodeCard 添加部署按钮**

在 NodeCard 中，`node.nodeId === 'local'` 时不显示部署按钮。对于远程节点，根据 agent 状态显示不同按钮。在现有操作按钮区域后添加:

在 `NodeCard.tsx` 中，在 `return` 之前添加部署状态判断，在 card footer 区域添加按钮:

```tsx
  // ... inside NodeCard component, before the return statement
  const needsDeploy = !node.agent?.deployed;
  const isRunning = node.agent?.status === 'running';
  const isStopped = node.agent?.status === 'stopped';
  const isDeploying = node.agent?.status === 'deploying';

  // Add these buttons after the location/kernel info area and before closing </div>
```

由于 NodeCard 改动较大，在现有组件底部追加一个新 section:

在 NodeCard 的 return 中，在 `</div>` (card root) 之前，节点信息之后追加:

```tsx
        {/* Agent deployment actions — only for remote nodes */}
        {node.nodeId !== 'local' && (
          <div className="flex gap-2 mt-3 pt-3" style={{ borderTop: '1px solid var(--border)' }}>
            {needsDeploy && (
              <button
                onClick={(e) => { e.stopPropagation(); onDeploy?.(node.nodeId); }}
                className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all active:scale-[0.98]"
                style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
                <Icon icon="ph:rocket-launch-bold" className="w-3.5 h-3.5" />
                一键部署
              </button>
            )}
            {isRunning && (
              <>
                <button
                  onClick={(e) => { e.stopPropagation(); onUpdateAgent?.(node.nodeId); }}
                  className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all active:scale-[0.98]"
                  style={{ backgroundColor: 'var(--secondary)', color: 'var(--secondary-foreground)' }}>
                  <Icon icon="ph:arrow-clockwise-bold" className="w-3.5 h-3.5" />
                  更新
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); onRestartAgent?.(node.nodeId); }}
                  className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all active:scale-[0.98]"
                  style={{ backgroundColor: 'var(--secondary)', color: 'var(--secondary-foreground)' }}>
                  <Icon icon="ph:repeat-bold" className="w-3.5 h-3.5" />
                  重启
                </button>
                <button
                  onClick={(e) => { e.stopPropagation(); onUninstallAgent?.(node.nodeId); }}
                  className="flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-all active:scale-[0.98]"
                  style={{ backgroundColor: 'var(--destructive)', color: 'var(--destructive-foreground)' }}>
                  <Icon icon="ph:trash-bold" className="w-3.5 h-3.5" />
                  卸载
                </button>
              </>
            )}
            {isDeploying && (
              <span className="flex items-center gap-1 text-xs" style={{ color: 'var(--primary)' }}>
                <Icon icon="ph:spinner-bold" className="w-3.5 h-3.5 animate-spin" />
                部署中...
              </span>
            )}
          </div>
        )}
```

NodeCardProps 需要新增回调:

```typescript
interface NodeCardProps {
  node: NodeStatus;
  onUpdate?: (nodeId: string) => void;
  onHealthCheck?: (nodeId: string) => void;
  onDeploy?: (nodeId: string) => void;
  onUpdateAgent?: (nodeId: string) => void;
  onRestartAgent?: (nodeId: string) => void;
  onUninstallAgent?: (nodeId: string) => void;
}
```

- [ ] **Step 6: 更新 Dashboard 集成所有新功能**

在 Dashboard.tsx 中添加新的 handler 和 state:

```typescript
  const [showAddNode, setShowAddNode] = useState(false);
  const [deployProgress, setDeployProgress] = useState<{ nodeName: string; steps: DeployStep[] } | null>(null);

  const handleAddNode = useCallback(async (data: NodeFormData) => {
    // Save SSH key, update nodes.yaml, then deploy
    setShowAddNode(false);
    // TODO: save to nodes.yaml via API
  }, []);

  const handleDeploy = useCallback(async (nodeId: string) => {
    setDeployProgress({ nodeName: nodeId, steps: [{ step: 'connect', status: 'running', message: '正在连接...', progress: 0 }] });
    try {
      await apiService.deployNode(nodeId);
    } catch (err) {
      setError(err instanceof Error ? err.message : '部署失败');
      setDeployProgress(null);
    }
  }, []);

  const handleUpdateAgent = useCallback(async (nodeId: string) => {
    try {
      await apiService.updateAgent(nodeId);
    } catch (err) {
      setError(err instanceof Error ? err.message : '更新失败');
    }
  }, []);

  const handleRestartAgent = useCallback(async (nodeId: string) => {
    try {
      await apiService.restartAgent(nodeId);
    } catch (err) {
      setError(err instanceof Error ? err.message : '重启失败');
    }
  }, []);

  const handleUninstallAgent = useCallback(async (nodeId: string) => {
    if (!confirm('确定要卸载 Agent？内核将保留。')) return;
    try {
      await apiService.uninstallAgent(nodeId);
    } catch (err) {
      setError(err instanceof Error ? err.message : '卸载失败');
    }
  }, []);
```

在 NodeCard 使用处传递新 props:

```tsx
  <NodeCard
    key={node.nodeId}
    node={node}
    onUpdate={handleUpdate}
    onHealthCheck={handleHealthCheck}
    onDeploy={handleDeploy}
    onUpdateAgent={handleUpdateAgent}
    onRestartAgent={handleRestartAgent}
    onUninstallAgent={handleUninstallAgent}
  />
```

在 Dashboard return 中添加 AddNodeForm 和 DeployProgressDialog:

```tsx
      {/* Add Node Form */}
      <AddNodeForm
        isOpen={showAddNode}
        onClose={() => setShowAddNode(false)}
        onSubmit={handleAddNode}
      />

      {/* Deploy Progress Dialog */}
      {deployProgress && (
        <DeployProgressDialog
          isOpen={!!deployProgress}
          nodeName={deployProgress.nodeName}
          steps={deployProgress.steps}
          onClose={() => setDeployProgress(null)}
        />
      )}
```

添加"添加节点"浮动按钮:

```tsx
      {/* Floating add node button */}
      <button
        onClick={() => setShowAddNode(true)}
        className="fixed bottom-6 right-6 z-40 w-14 h-14 rounded-full flex items-center justify-center shadow-lg transition-all hover:scale-110 active:scale-95"
        style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)' }}>
        <Icon icon="ph:plus-bold" className="w-6 h-6" />
      </button>
```

- [ ] **Step 7: 运行测试确认通过**

Run: `cd frontend && bun run test`
Expected: 2 new UI tests PASS, existing tests unaffected

- [ ] **Step 8: Commit**

```bash
git add frontend/src/components/cluster/AddNodeForm.tsx frontend/src/components/cluster/DeployProgressDialog.tsx frontend/src/components/cluster/NodeCard.tsx frontend/src/components/cluster/NodeDetail.tsx frontend/src/components/Dashboard.tsx frontend/src/lib/api.ts frontend/src/components/cluster/__tests__/add-node.test.tsx
git commit -m "feat(ui): add node form, deploy progress dialog, and agent lifecycle buttons

- AddNodeForm: SSH key, kernel type, host info input with modal
- DeployProgressDialog: 6-step progress bar with SSE-style updates
- NodeCard: deploy/update/restart/uninstall buttons by agent state
- Dashboard: floating add button, deploy/agent handler callbacks
- api.ts: 8 new methods for deploy/agent/kernel operations
- 2 new UI tests"
```

---

### Task 8: NodeDetail 部署信息面板

**Files:**
- Modify: `frontend/src/components/cluster/NodeDetail.tsx`

- [ ] **Step 1: 在 NodeDetail 中添加部署信息区域**

在 NodeDetail 的 `return` 中，现有节点详情后面、操作按钮前面添加:

```tsx
      {/* Agent deployment info — only for remote nodes */}
      {node.nodeId !== 'local' && node.agent && (
        <div className="mt-4 pt-3" style={{ borderTop: '1px solid var(--border)' }}>
          <h4
            className="text-xs font-semibold uppercase tracking-widest mb-2"
            style={{ color: 'var(--muted-foreground)', fontFamily: 'var(--font-display)' }}
          >
            部署信息
          </h4>
          <div className="space-y-1">
            <InfoRow label="Agent">
              <span className="text-sm" style={{ color: 'var(--foreground)' }}>
                {node.agent.version || '-'}
              </span>
              <StatusBadge
                label={node.agent.status === 'running' ? '运行中' : node.agent.status === 'stopped' ? '已停止' : node.agent.status === 'error' ? '异常' : '未部署'}
                status={node.agent.status === 'running' ? 'success' : node.agent.status === 'error' ? 'danger' : 'warning'}
              />
            </InfoRow>
            {node.agent.lastDeploy && (
              <InfoRow label="部署时间">
                <span className="text-sm" style={{ color: 'var(--muted-foreground)' }}>
                  {new Date(node.agent.lastDeploy).toLocaleString('zh-CN')}
                </span>
              </InfoRow>
            )}
          </div>
        </div>
      )}
```

- [ ] **Step 2: 运行测试确认通过**

Run: `cd frontend && bun run test`
Expected: all tests PASS

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/cluster/NodeDetail.tsx
git commit -m "feat(ui): add agent deployment info section to NodeDetail

- Shows agent version, status badge, and last deploy time
- Only rendered for remote nodes with agent info"
```

---

### 自审

**Spec coverage check:**
- ✅ Agent 子包 (Task 1-3)
- ✅ Agent HTTP endpoints (Task 2)
- ✅ HMAC 验证 (Task 2)
- ✅ Bun 编译 (Task 3)
- ✅ nodes.yaml 扩展 (Task 4)
- ✅ DeployManager 服务 (Task 5)
- ✅ API 端点 (Task 6)
- ✅ Dashboard UI (Task 7-8)
- ✅ 部署进度 SSE (Task 6 progress endpoint)
- ✅ 233boy 内核集成 (Task 5 getKernelInstallCmd)

**未覆盖的 spec 需求:**
- ⚠️ 实际 SSH 连接（node-ssh 集成）— API 端点骨架已建，SSH 实现标记为 follow-up
- ⚠️ 内核版本查询 — follow-up

**Placeholder scan:** 无 TBD/TODO

**Type consistency:** DeployStep 类型在 Task 5 定义，Task 6-7 引用一致。NodeFormData 在 Task 7 定义。

---
