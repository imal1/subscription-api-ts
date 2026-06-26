# MioBridge v1.0 — 多节点分布式管理系统

**状态**: 设计稿 | **日期**: 2026-06-26 | **作者**: imal1

---

## 概述

将 MioBridge 从单机订阅转换服务升级为分布式多节点管理系统。控制面部署在其中一台节点服务器上，通过公网直连 + HMAC 签名认证管理 2-10 台地域分散的节点。节点支持 sing-box、xray、v2ray 三种代理内核（均来自 233boy 仓库）。

---

## 目标

1. **单一控制面**：在一个 Dashboard 上查看和管理所有节点的订阅转换状态
2. **内核兼容**：同时支持 sing-box、xray、v2ray 三种 233boy 内核
3. **安全通信**：公网直连，HMAC-SHA256 签名 + 时间戳防重放
4. **批量操作**：一键触发所有节点的订阅更新和健康检查
5. **渐进式**：节点可独立运行，控制面挂了不影响各节点服务

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│                    控制面节点 (Node A)                         │
│                                                               │
│  ┌──────────────────┐  ┌───────────────────────────────────┐ │
│  │ Dashboard        │  │ NodeManager (单例 Service)         │ │
│  │ (Next.js SSR)    │  │                                    │ │
│  │                  │  │  nodes.yaml ──▶ 节点注册表          │ │
│  │  多节点卡片视图   │◀─│                                    │ │
│  │  节点详情面板     │  │  pollAll() ──▶ 并发轮询远程节点      │ │
│  │  批量操作按钮     │  │  triggerUpdate() ──▶ 触发远程更新    │ │
│  │                  │  │  getClusterStatus() ──▶ 聚合缓存    │ │
│  └──────────────────┘  └───────────────┬───────────────────┘ │
│                                        │                       │
│  ┌────────────────────────────────────┼──────────────────────┐ │
│  │ MioBridgeService                   │                      │ │
│  │                                    │                      │ │
│  │  KernelAdapter (接口)              │                      │ │
│  │  ├── SingBoxAdapter  (本地)        │                      │ │
│  │  ├── XrayAdapter                   │                      │ │
│  │  └── V2rayAdapter                  │                      │ │
│  └────────────────────────────────────┼──────────────────────┘ │
└───────────────────────────────────────┼────────────────────────┘
                                        │
                         公网 HTTPS + HMAC 签名
                                        │
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
                    ▼                   ▼                   ▼
              ┌──────────┐       ┌──────────┐       ┌──────────┐
              │ Node B   │       │ Node C   │       │ Node D   │
              │ xray     │       │ v2ray    │       │ sing-box │
              │ 东京     │       │ 新加坡   │       │ 洛杉矶   │
              │          │       │          │       │          │
              │ Nginx    │       │ Nginx    │       │ Nginx    │
              │  └─▶API  │       │  └─▶API  │       │  └─▶API  │
              │ HMAC验证  │       │ HMAC验证  │       │ HMAC验证  │
              └──────────┘       └──────────┘       └──────────┘
```

---

## 组件设计

### 1. 节点注册表 (nodes.yaml)

**位置**: `~/.config/miobridge/nodes.yaml`（仅控制面节点）

```yaml
nodes:
  - id: "node-a"
    name: "本地"
    host: "localhost"
    port: 3001
    secret: ""                    # 本机无需 HMAC
    kernel: "sing-box"
    location: "东京"
    enabled: true

  - id: "node-b"
    name: "新加坡"
    host: "sg.example.com"
    port: 443                     # HTTPS Nginx 反代
    secret: "<64-char-hex>"
    kernel: "xray"
    location: "新加坡"
    enabled: true

  - id: "node-c"
    name: "洛杉矶"
    host: "us.example.com"
    port: 443
    secret: "<64-char-hex>"
    kernel: "v2ray"
    location: "洛杉矶"
    enabled: true
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | 唯一标识，kebab-case |
| `name` | string | Dashboard 显示名称 |
| `host` | string | 公网 IP 或域名 |
| `port` | number | API 端口（Nginx 反代后通常 443） |
| `secret` | string | HMAC 共享密钥，64 字符 hex，本机留空 |
| `kernel` | enum | `sing-box` / `xray` / `v2ray` |
| `location` | string | 地域标签 |
| `enabled` | boolean | 是否纳入管理 |

### 2. 远程节点配置扩展 (config.yaml)

在现有 `~/.config/miobridge/config.yaml` 新增：

```yaml
node:
  id: "node-b"                    # 本节点标识
  secret: "<64-char-hex>"         # HMAC 共享密钥（与控制面一致）
```

### 3. NodeManager 服务

**位置**: `frontend/src/server/services/nodeManager.ts`

```
NodeManager (单例)
├── 属性
│   ├── nodes: NodeConfig[]          // 从 nodes.yaml 加载
│   └── cache: Map<id, NodeStatus>   // 内存缓存，30s TTL
│
├── loadNodes(): void                // 读取 nodes.yaml
├── getNode(id): NodeConfig          // 查找单节点
├── pollNode(id): Promise<NodeStatus> // 对单个节点发起签名请求
├── pollAll(): Promise<void>         // 并发轮询所有远程节点
├── getClusterStatus(): ClusterStatus // 返回聚合状态
├── triggerUpdate(id?): Promise      // 触发节点更新（不传 id=全部）
├── healthCheck(id?): Promise        // 健康检查（不传 id=全部）
└── signRequest(node, method, path, body?): { headers } // HMAC 签名
```

**职责边界**:
- NodeManager 只负责远程节点通信和状态聚合
- 本地节点的逻辑仍在 MioBridgeService 中
- 轮询间隔固定 30s，与现有 Dashboard 轮询一致

### 4. HMAC 签名中间件

**控制面侧** (`nodeManager.ts` 内置):

```typescript
signRequest(node, method, path, body) {
  const timestamp = Date.now();
  const payload = `${timestamp}\n${method}\n${path}\n${body ?? ''}`;
  const signature = crypto.createHmac('sha256', node.secret)
    .update(payload).digest('hex');
  return {
    'X-Node-Id': node.id,
    'X-Timestamp': String(timestamp),
    'X-Signature': signature,
  };
}
```

**远程节点侧** (新增中间件，应用到所有 `/api/*` 路由):

```typescript
// frontend/src/server/middleware/hmac.ts
verifyHmac(req) {
  // 1. 提取请求头
  // 2. 检查时间窗口 |now - timestamp| < 30s
  // 3. 防重放：同一 timestamp 不可复用
  // 4. 重新计算 HMAC-SHA256 并 timingSafeEqual 比对
}
```

**特殊处理**:
- `localhost` 请求跳过 HMAC 验证
- 时间戳缓存每 60s 清理一次过期条目
- 验证失败返回 `401 Unauthorized`，附带错误原因

### 5. 内核适配器

**位置**: `frontend/src/server/services/adapters/`

```typescript
interface KernelAdapter {
  readonly type: 'sing-box' | 'xray' | 'v2ray';
  getConfigPaths(): Promise<string[]>;    // 配置文件路径
  extractNodeUrls(): Promise<string[]>;   // 提取代理节点 URL
  isAvailable(): Promise<boolean>;        // 内核二进制是否可用
}

// SingBoxAdapter  — 现有逻辑封装，配置路径 /usr/local/etc/sing-box/
// XrayAdapter     — 解析 /usr/local/etc/xray/config.json
// V2rayAdapter    — 解析 /etc/v2ray/config.json，处理 alterId 差异
```

**233boy 各内核差异**:

| 内核 | 配置路径 | 配置格式 | 出站节点提取方式 |
|------|---------|---------|----------------|
| sing-box | `/usr/local/etc/sing-box/` | JSON (sing-box 格式) | `outbounds[].{server,port,protocol}` |
| xray | `/usr/local/etc/xray/config.json` | JSON (Xray 格式) | `outbounds[].settings.vnext[]` |
| v2ray | `/etc/v2ray/config.json` | JSON (V2Ray 格式) | 同 xray，但 `alterId` 字段差异 |

每个 adapter 提取出统一的 `ProxyNode[]` 后，统一交给 mihomo 转换为 Clash 格式——转换逻辑不变。

### 6. Dashboard 组件

**新增/修改的组件**:

| 组件 | 用途 |
|------|------|
| `ClusterOverview` | 全局统计条：总节点数、在线数、总代理数、协议类型数 |
| `NodeCard` | 单节点卡片：在线状态、内核类型、代理数、协议分布、操作按钮 |
| `NodeDetail` | 节点详情面板：复用现有 Dashboard 组件，展示单节点完整信息 |
| `BatchActions` | 批量操作栏：全部更新、全部健康检查 |

**路由设计**:
- `/` — 多节点总览（集群视图）
- `/?node=node-b` — 点击节点卡片后展开详情面板（客户端路由，不刷新页面）

### 7. API 变更

| 端点 | 方法 | 用途 | 变更类型 |
|------|------|------|---------|
| `/api/cluster/status` | GET | 聚合所有节点状态 | **新增** |
| `/api/cluster/update` | POST | 触发节点更新 `?node=id` 或全部 | **新增** |
| `/api/cluster/health` | GET | 批量健康检查 | **新增** |
| `/api/status` | GET | 现有，增加 HMAC 验证 | 修改 |
| `/api/update` | POST | 现有，增加 HMAC 验证 | 修改 |
| `/api/health` | GET | 现有，增加 HMAC 验证 | 修改 |

---

## 数据流

```
Dashboard 首次加载:
  getServerSideProps
    └─▶ NodeManager.getClusterStatus()
          ├─▶ 本地 MioBridgeService.getStatus()     (本机，直接调用)
          └─▶ 并发 pollAll()                        (远程节点)
                ├─▶ HMAC签名 GET /api/status → Node B
                ├─▶ HMAC签名 GET /api/status → Node C
                └─▶ 聚合结果 → ClusterStatus

Dashboard 30s 轮询:
  setInterval 30s
    └─▶ GET /api/cluster/status
          └─▶ NodeManager.getClusterStatus()
                ├── 缓存未过期 (<30s): 直接返回缓存
                └── 缓存过期 (≥30s): 并发 pollAll() 刷新全部节点 → 更新缓存 → 返回

用户点击"更新" (单节点):
  POST /api/cluster/update?node=node-b
    └─▶ NodeManager.triggerUpdate("node-b")
          └─▶ HMAC签名 POST /api/update → Node B

用户点击"全部更新":
  POST /api/cluster/update
    └─▶ NodeManager.triggerUpdate()
          ├─▶ 本地 MioBridgeService.updateSubscription()
          └─▶ 并发 HMAC签名 POST /api/update → 各远程节点
```

---

## 错误处理

| 场景 | 行为 |
|------|------|
| 远程节点超时 (10s) | 标记为离线，显示"超时"，下次轮询重试 |
| HMAC 签名验证失败 | 返回 401，控制面标记节点为"认证失败" |
| 远程节点返回 500 | 标记为在线但异常，显示错误信息 |
| 节点在 nodes.yaml 中 disabled | 不轮询，Dashboard 显示"已停用" |
| 控制面本地 mihomo 不可用 | 不影响远程节点管理，本地节点显示异常 |
| 部分节点更新失败（批量操作） | Toast 显示 "2/3 成功，node-c 失败: 超时" |

---

## 安全考虑

- HMAC secret 通过 `nodes.yaml` 和远程 `config.yaml` 分别配置，不通过 API 传输
- 时间窗口 ±30s，依赖 NTP 时钟同步（公网服务器默认启用）
- 签名 payload 包含 method + path，防止请求被重放到不同端点
- 远程节点 Nginx 层可额外配置 IP 白名单（可选，增强安全）
- `nodes.yaml` 文件权限 600

---

## 向后兼容

- 单机部署用户（无 nodes.yaml）行为完全不变
- 现有 `/api/*` 端点兼容无 HMAC 头的请求（localhost 跳过验证）
- 现有 Dashboard 路径 `/` 保持可用，仅当 nodes.yaml 存在时显示集群视图
- 配置文件 `config.yaml` 新增 `node` 段可选，缺失时不影响现有功能

---

## 版本规划

```
v0.2.0 (当前)    AI Memory & Docs (当前进行中)
    │
    ▼
v1.0.0          多节点分布式管理系统 ← 本次
    │           节点注册表 / NodeManager / HMAC 签名
    │           Dashboard 集群视图 / 批量操作
    │           xray & v2ray 内核适配器
    │
    ▼
v1.1.0          用户认证 (原 v0.3)
    │           API Keys / 管理员登录 / 访问控制
    ▼
v1.2.0          配置管理 (原 v0.4)
    │           Web 端 YAML 配置编辑器
    ▼
v1.3.0          订阅源管理 (原 v0.5)
    │           多源订阅 / 远程 URL / 手动输入
    ▼
v1.4.0          节点定制 (原 v0.6)
    │           Clash 模板 / 规则引擎 / 代理组
    ▼
v1.5.0          监控 (原 v0.7)
    │           指标采集 / 日志聚合 / 告警
    ▼
v1.6.0          API 文档 (原 v0.8)
    │           OpenAPI Spec / 标准化响应
    ▼
v1.7.0          性能优化 (原 v0.9)
    │           缓存 / SSE 推送 / 首屏优化
    ▼
v1.8.0          生产就绪 (原 v1.0)
                测试覆盖 / CI/CD 强化
```

---

## 非功能需求

- 控制面不增加远程节点的运行时开销（仅接收标准 HTTP 请求）
- 节点离线不影响控制面和其他节点的正常运行
- Dashboard 集群视图首屏渲染时间不因节点数增加而显著增长（并发轮询）
- 新增节点只需编辑 `nodes.yaml`，NodeManager 通过 fs.watch 检测文件变更自动重载
- 本地节点使用对应内核 adapter（sing-box/xray/v2ray），远程节点通过其自身 API 获取状态，控制面无需远程节点的 adapter
