# MioBridge Agent — 零手动远程节点部署

**状态**: 设计稿 | **日期**: 2026-06-27 | **作者**: imal1

---

## 概述

为 MioBridge v1.0 多节点系统提供零手动部署能力。轻量 Agent 以 Bun 编译单二进制形式部署到远程节点，复用现有 adapter/HMAC/types 代码。控制面通过 Web Dashboard 一键完成：Bun 安装 → 内核安装（233boy 脚本）→ Agent 部署 → systemd 启动 → 健康验证。后续更新、重启、卸载全部在 Dashboard 操作。

---

## 目标

1. **Agent 零依赖**：Bun 编译为单二进制，远程节点无需 Node.js/Bun/npm
2. **代码复用**：Adapter、HMAC 中间件、Types 直接 import 现有源码
3. **一键部署**：Dashboard 输入 SSH 信息 → 点"部署" → 全自动完成
4. **内核集成**：自动安装 233boy sing-box/xray/v2ray 脚本
5. **全生命周期管理**：部署、更新、重启、卸载、状态查看均在 Web 端

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│                     控制面 (MioBridge)                         │
│                                                               │
│  ┌──────────────────┐  ┌───────────────────────────────────┐ │
│  │ Dashboard        │  │ DeployManager (单例 Service)       │ │
│  │                  │  │                                    │ │
│  │ 节点部署卡片      │◀─│ deployAgent(nodeId)                │ │
│  │ 部署进度条        │  │ updateAgent(nodeId)                │ │
│  │ 内核/Agent 状态   │  │ uninstallAgent(nodeId)             │ │
│  │ 操作按钮          │  │ installKernel(nodeId, type)        │ │
│  └──────────────────┘  │ getAgentStatus(nodeId)              │ │
│                         └───────────────┬───────────────────┘ │
│                                         │                      │
│  ┌─────────────────────────────────────┼─────────────────────┐ │
│  │ agent/  (monorepo 子包)             │                     │ │
│  │                                     │                     │ │
│  │  src/server.ts      ← HTTP server   │                     │ │
│  │  src/hmac.ts        ← 复用 middleware                    │ │
│  │  src/adapters/      ← 复用 adapters/                     │ │
│  │  src/types.ts       ← 复用 types/                        │ │
│  │  agent.yaml          ← 子节点配置                         │ │
│  └─────────────────────────────────────┼─────────────────────┘ │
│                                        │                       │
│  ┌─────────────────────────────────────┼─────────────────────┐ │
│  │ Nginx                               │                     │ │
│  │  /agent/miobridge-agent  → 二进制下载                      │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────┼──────────────────────────┘
                                       │
                          SSH (node-ssh)
                                       │
              ┌────────────────────────┼────────────────────────┐
              │                        │                        │
              ▼                        ▼                        ▼
        ┌──────────┐            ┌──────────┐            ┌──────────┐
        │ Node B   │            │ Node C   │            │ Node D   │
        │ xray     │            │ v2ray    │            │ sing-box │
        │ 东京     │            │ 新加坡   │            │ 洛杉矶   │
        │          │            │          │            │          │
        │ Bun      │            │ Bun      │            │ Bun      │
        │ Agent    │            │ Agent    │            │ Agent    │
        │ :3001    │            │ :3001    │            │ :3001    │
        │          │            │          │            │          │
        │ Nginx    │            │ Nginx    │            │ Nginx    │
        │  └─▶443  │            │  └─▶443  │            │  └─▶443  │
        └──────────┘            └──────────┘            └──────────┘
```

---

## 组件设计

### 1. Agent 子包 (`agent/`)

**位置**: 仓库根目录 `agent/`

**依赖**: 零 npm 依赖，仅 Node.js 标准库 + 复用 `frontend/src/server/` 源码

```
agent/
  package.json           ← name: "miobridge-agent", 零 dependencies
  tsconfig.json          ← paths 指向 ../frontend/src/server/
  agent.yaml.example     ← 配置模板
  src/
    server.ts            ← HTTP server 入口 (~150行)
    config.ts            ← agent.yaml 解析器 (~40行)
    handlers/
      status.ts          ← GET /api/status
      update.ts          ← GET /api/update
      health.ts          ← GET /api/health
```

#### 端点规范

与现有 `/api/status`、`/api/update`、`/api/health` 响应格式完全一致，确保 NodeManager 的 `fetchRemoteStatus` 等函数无需修改。

| 端点 | 方法 | 响应 |
|------|------|------|
| `/api/status` | GET | `{ success, data: StatusInfo, timestamp }` |
| `/api/update` | GET | `{ success, data: UpdateResult, message, timestamp }` |
| `/api/health` | GET | `{ status, uptime, memory, version, timestamp }` |

#### HMAC 验证

复用 `frontend/src/server/middleware/hmac.ts` 的 `hmacVerify()` 函数。通过 `MIOBRIDGE_NODE_SECRET` 环境变量控制（未设置时跳过验证，兼容开发调试）。

#### agent.yaml 格式

```yaml
node:
  id: "node-sg"
  name: "新加坡"
  secret: ""               # HMAC 共享密钥，部署时自动填入

kernel:
  type: "xray"             # sing-box | xray | v2ray
  configPath: "/usr/local/etc/xray/config.json"

mihomo:
  path: "/usr/local/bin/mihomo"

port: 3001
```

#### 构建命令

```bash
cd agent
bun build src/server.ts --compile --outfile miobridge-agent --target bun-linux-x64
```

产物 `miobridge-agent` 约 50MB，零依赖，直接执行。

#### systemd unit 模板

```ini
[Unit]
Description=MioBridge Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/miobridge-agent
WorkingDirectory=/etc/miobridge-agent
Environment=MIOBRIDGE_NODE_SECRET=<secret>
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

### 2. DeployManager 服务

**位置**: `frontend/src/server/services/deployManager.ts`

**依赖**: `node-ssh`（控制面唯一新增 npm 依赖）

```
DeployManager (单例)
├── 属性
│   └── sshPool: Map<nodeId, NodeSSH>
│
├── SSH 连接管理
│   ├── connect(nodeId): Promise<NodeSSH>
│   ├── disconnect(nodeId): Promise<void>
│   └── testConnection(nodeId): Promise<{ ok, os, arch }>
│
├── 部署操作
│   ├── fullDeploy(nodeId): AsyncGenerator<DeployStep>
│   │     ├── step 1: 连接 + OS/架构检测
│   │     ├── step 2: 安装 Bun
│   │     ├── step 3: 安装内核 (233boy 脚本)
│   │     ├── step 4: 部署 Agent (scp 二进制 + 配置 + systemd)
│   │     ├── step 5: 启动服务
│   │     └── step 6: 健康验证
│   ├── updateAgent(nodeId): Promise<UpdateResult>
│   ├── uninstallAgent(nodeId): Promise<void>
│   ├── uninstallAll(nodeId): Promise<void>  ← Agent + 内核全卸载
│   ├── restartAgent(nodeId): Promise<void>
│   ├── stopAgent(nodeId): Promise<void>
│   └── startAgent(nodeId): Promise<void>
│
├── 内核管理
│   ├── installKernel(nodeId, type): AsyncGenerator<DeployStep>
│   ├── uninstallKernel(nodeId): Promise<void>
│   └── getKernelVersion(nodeId): Promise<string>
│
└── 状态查询
    ├── getAgentStatus(nodeId): Promise<AgentStatus>
    └── getAgentVersion(nodeId): Promise<string>
```

#### 233boy 内核安装命令

| 内核 | 安装命令 |
|------|---------|
| sing-box | `bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)` |
| xray | `bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)` |
| v2ray | `bash <(wget -qO- -o- https://github.com/233boy/v2ray/raw/master/install.sh)` |

#### 部署步骤与进度上报

```typescript
interface DeployStep {
  step: 'connect' | 'bun' | 'kernel' | 'agent' | 'start' | 'verify' | 'done';
  status: 'pending' | 'running' | 'success' | 'error';
  message: string;
  progress: number;  // 0-100
}
```

进度通过 SSE 推送到 Dashboard，实现实时进度条。

---

### 3. Dashboard UI 扩展

#### 节点卡片按钮（按部署状态）

| 节点状态 | 显示按钮 |
|---------|---------|
| 全新（仅配 SSH） | 🚀 一键部署 |
| 部署中 | ⏳ 进度条：装 Bun → 装内核 → 部署 Agent → 启动 |
| 运行中 | 🔄 更新 · ⏸️ 停止 · 🔃 重启 · 🗑️ 卸载 |
| 已停止 | ▶️ 启动 · 🗑️ 卸载 |
| 离线/异常 | 🔍 诊断 · 🔄 重新部署 |

#### NodeDetail 面板新增分区

```
┌─ 部署信息 ──────────────────┐
│ Agent:    v1.0.0 ✅ 运行中  │
│ Bun:      v1.2.0           │
│ 内核:     Xray v25.3.6     │
│ 部署时间: 06-27 10:00      │
│ 运行时间: 3h 12m           │
│ 内存:     28MB             │
└────────────────────────────┘
```

#### 部署进度弹窗

```
┌─ 正在部署 新加坡 ──────────┐
│                            │
│ ✅ 连接成功 (Ubuntu 22.04) │
│ ✅ 安装 Bun v1.2.0         │
│ ⏳ 安装 Xray...            │
│ ⬜ 部署 Agent              │
│ ⬜ 启动服务                │
│ ⬜ 健康验证                │
│                            │
│ ████████░░░░ 40%           │
└────────────────────────────┘
```

---

### 4. 新 API 端点

| 端点 | 方法 | 功能 | 需要 SSH |
|------|------|------|:---:|
| `POST /api/cluster/deploy` | POST | 完整部署（Bun + 内核 + Agent） | ✅ |
| `POST /api/cluster/agent/update` | POST | 更新 Agent 二进制 | ✅ |
| `POST /api/cluster/agent/uninstall` | POST | 卸载 Agent（保留内核） | ✅ |
| `POST /api/cluster/agent/restart` | POST | 重启 Agent | ✅ |
| `POST /api/cluster/agent/stop` | POST | 停止 Agent | ✅ |
| `POST /api/cluster/agent/start` | POST | 启动 Agent | ✅ |
| `POST /api/cluster/kernel/install` | POST | 安装/重装内核 | ✅ |
| `POST /api/cluster/kernel/uninstall` | POST | 卸载内核 | ✅ |
| `GET /api/cluster/deploy/status` | GET | 查看节点部署状态 | ❌ |

#### 部署状态 SSE 端点

```
GET /api/cluster/deploy/progress?node=node-sg
→ SSE stream: data: {"step":"bun","status":"running","message":"安装 Bun...","progress":40}
```

---

### 5. nodes.yaml 扩展

```yaml
nodes:
  - id: "node-sg"
    name: "新加坡"
    host: "sg.example.com"
    port: 443
    secret: "<64-char-hex>"
    kernel: "xray"
    location: "新加坡"
    enabled: true

    # === 新增：SSH 连接信息 ===
    ssh:
      user: "root"
      port: 22
      # SSH 私钥存储路径（控制面本地）
      keyPath: "~/.config/miobridge/ssh/node-sg.key"
      # known_hosts 指纹（首次连接时自动记录）
      hostKey: ""

    # === 新增：Agent 运行时信息（系统维护） ===
    agent:
      deployed: false
      version: ""
      status: "not_deployed"   # not_deployed | deploying | running | stopped | error
      lastDeploy: ""

    # === 新增：内核信息（系统维护） ===
    kernelInfo:
      installed: false
      version: ""
      installScript: ""        # 使用的 233boy 脚本类型
```

---

## 数据流

### 部署流程

```
用户点击 "部署"
  │
  ▼
POST /api/cluster/deploy { nodeId: "node-sg" }
  │
  ▼
DeployManager.fullDeploy("node-sg")
  │
  ├── connect() ──▶ SSH 连接 → 检测 OS (ubuntu/debian/centos) + arch (amd64/arm64)
  │     └── yield { step: 'connect', status: 'success', progress: 10 }
  │
  ├── installBun() ──▶ curl -fsSL https://bun.sh/install | bash
  │     └── yield { step: 'bun', status: 'success', progress: 25 }
  │
  ├── installKernel() ──▶ bash <(wget -qO- ... 233boy 脚本)
  │     └── yield { step: 'kernel', status: 'success', progress: 50 }
  │
  ├── deployAgent()
  │     ├── scp miobridge-agent → /usr/local/bin/
  │     ├── 生成 agent.yaml (含 HMAC secret) → scp → /etc/miobridge-agent/
  │     └── 生成 systemd unit → scp → /etc/systemd/system/
  │     └── yield { step: 'agent', status: 'success', progress: 75 }
  │
  ├── startService()
  │     ├── systemctl daemon-reload
  │     └── systemctl enable --now miobridge-agent
  │     └── yield { step: 'start', status: 'success', progress: 90 }
  │
  └── healthVerify() ──▶ curl /api/health → 200 OK
        └── yield { step: 'verify', status: 'success', progress: 100 }
        └── 更新 nodes.yaml 中 agent 状态
```

### 更新流程

```
用户点击 "更新 Agent"
  │
  ▼
POST /api/cluster/agent/update { nodeId: "node-sg" }
  │
  ▼
DeployManager.updateAgent("node-sg")
  ├── 从控制面下载最新 miobridge-agent 二进制
  │     └── curl https://control-plane/agent/miobridge-agent -o /tmp/miobridge-agent.new
  ├── systemctl stop miobridge-agent
  ├── mv /tmp/miobridge-agent.new /usr/local/bin/miobridge-agent
  ├── chmod +x /usr/local/bin/miobridge-agent
  ├── systemctl start miobridge-agent
  └── 健康验证 → 更新 nodes.yaml agent.version
```

---

## 错误处理

| 场景 | 行为 |
|------|------|
| SSH 连接失败 | 返回 `{ error: "SSH 连接失败: 认证被拒绝" }`，部署中止 |
| Bun 安装失败 | 返回 `{ error: "Bun 安装失败" }`，部署中止，已安装部分保留 |
| 内核安装失败 | 返回 `{ error: "内核安装失败: 不支持的发行版" }`，部署中止 |
| Agent 健康验证失败 | 返回 `{ error: "Agent 启动后健康检查失败" }`，保留已部署文件 |
| 部署中网络中断 | 部署中止，节点状态标记为 `error`，支持"重新部署" |
| 更新时 Agent 启动失败 | 自动回滚到旧二进制，返回错误 |
| OS 不支持 | 返回 `{ error: "不支持的操作系统: CentOS 7" }`（仅支持 Ubuntu 18+/Debian 10+） |

---

## 安全考虑

- SSH 私钥存储在 `~/.config/miobridge/ssh/`，权限 600
- 部署时生成 HMAC secret（64 字符随机 hex），通过 SSH 写入远程 `agent.yaml`，不在控制面日志中输出
- systemd unit 中 `MIOBRIDGE_NODE_SECRET` 通过 Environment 注入，进程外不可见（需 root 查看）
- `agent.yaml` 文件权限 600
- 首次 SSH 连接记录 host key，后续连接校验（防 MITM）
- 所有 SSH 操作超时 60s，避免挂死

---

## 向后兼容

- 现有 `nodes.yaml` 不含 `ssh`/`agent`/`kernelInfo` 字段 → 视为手动管理模式，Dashboard 不显示部署按钮
- 现有 NodeManager 轮询逻辑不变，agent 端点响应格式与完整 MioBridge 完全一致
- `agent/` 是独立子包，不影响现有 `frontend/` 构建和部署
- 未配置 SSH 的节点行为完全不变

---

## 验收标准

- [ ] Agent 编译为单二进制，`scp` 到裸机直接运行
- [ ] Agent 三个端点 (`/api/status`, `/api/update`, `/api/health`) 响应格式与控制面一致
- [ ] HMAC 验证正确，错误签名返回 401
- [ ] Dashboard 可以添加节点（填写 SSH 信息 + 上传密钥）
- [ ] 一键部署：自动装 Bun → 内核 → Agent → 启动 → 健康验证
- [ ] Dashboard 实时显示部署进度（SSE）
- [ ] Dashboard 可以更新 Agent 二进制
- [ ] Dashboard 可以重启/停止/启动 Agent
- [ ] Dashboard 可以卸载 Agent（保留内核）
- [ ] Dashboard 可以安装/重装/卸载内核
- [ ] 部署失败有明确错误信息和重试入口
- [ ] 单机模式（无 nodes.yaml）向后兼容

---

## 依赖

### 控制面新增

```
node-ssh    ← SSH 连接（纯 JS SSH2，零系统依赖）
```

### Agent 新增

```
无           ← 零 npm 依赖，仅 Node.js 标准库
```

---

## 预计工作量

3-5 天（单人开发）

- Agent 子包 + 构建脚本：1 天
- DeployManager 服务：1 天
- API 端点 + SSE 进度：0.5 天
- Dashboard UI 扩展：1 天
- 测试 + 端到端验证：0.5-1 天
