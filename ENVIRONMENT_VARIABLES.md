# 环境变量配置指南

本文档列出了项目中所有支持的环境变量，确保所有配置都可通过 `.env` 文件读取。### 🛠️ Sing-box配置
- `SING_BOX_CONFIGS` - sing-box配置名称，逗号分隔 (默认: vless,hysteria2,trojan,tuic,vmess)🛠️ 安装和管理脚本

项目采用模块化脚本架构，提供以下管理工具：

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `scripts/install.sh` | 完整项目安装 | 首次部署时使用 |
| `scripts/update.sh` | 服务更新 | 代码更新后重新部署 |
| `scripts/deploy.sh` | 生产环境部署 | 正式环境部署 |
| `scripts/build-frontend.sh` | 前端构建 | 单独构建前端项目 |
| `scripts/build-all.sh` | 完整项目构建 | 构建前端+后端 |
| `scripts/setup-nginx.sh` | Nginx 配置 | 配置反向代理 |
| `scripts/verify-permissions.sh` | 权限验证 | 排查权限问题 |

**推荐使用方式**：
```bash
# 首次安装
sudo bash scripts/install.sh

# 服务更新  
bash scripts/update.sh

# 生产部署
bash scripts/deploy.sh
```

## 🚀 API 端点参考

| 端点 | 支持方法 | 功能描述 |
|------|----------|----------|
| `/api/update` | **GET** | 更新订阅文件 |
| `/api/configs` | GET, POST | 获取/更新配置列表 |
| `/api/status` | GET | 获取服务状态 |
| `/subscription.txt` | GET | 下载订阅文件 |
| `/clash.yaml` | GET | 下载Clash配置 |
| `/health` | GET | 健康检查 |

⚠️ **重要**：`/api/update` 现在支持 GET 方法。详细的 API 使用说明请参考 [README.md](./README.md)

## 📋 环境变量清单

### 🚀 服务配置
- `PORT` - API服务监听端口 (默认: 3000)
- `NODE_ENV` - 运行环境 (默认: development)
- `SERVICE_NAME` - 服务名称，用于 systemd 和 PM2 (默认: subscription-api-ts)

### 🌐 Nginx配置
- `NGINX_PORT` - nginx服务端口 (默认: 3080)
- `NGINX_PROXY_PORT` - nginx代理端口 (默认: 3888)

### � Sing-box配置
- `SING_BOX_CONFIGS` - sing-box配置名称，逗号分隔 (默认: vless,hysteria2,trojan,tuic,vmess)

###  文件路径配置
- `BASE_DIR` - 工作区基础目录 (默认: $HOME/.config/subscription)
- `DATA_DIR` - 数据文件目录 (默认: $BASE_DIR/www)
- `LOG_DIR` - 日志文件目录 (默认: $BASE_DIR/log)
- `BACKUP_DIR` - 备份文件目录 (默认: $BASE_DIR/www/backup)
- `MIHOMO_PATH` - mihomo二进制目录 (默认: $BASE_DIR/bin)
- `BUN_PATH` - bun运行时目录 (默认: $BASE_DIR/bin)

### 🏗️ 构建文件配置
- `DIST_DIR` - 构建文件根目录 (默认: $BASE_DIR/dist)
  - 前端构建文件: $DIST_DIR/frontend
  - 后端构建文件: $DIST_DIR/backend

### ⏰ 定时任务配置
- `AUTO_UPDATE_CRON` - 自动更新cron表达式 (默认: 0 */2 * * *)

### 🌐 网络配置
- `MAX_RETRIES` - 最大重试次数 (默认: 3)
- `REQUEST_TIMEOUT` - 请求超时时间，毫秒 (默认: 30000)
- `EXTERNAL_HOST` - 外部访问主机名，影响所有脚本显示的访问地址 (默认: localhost)
  - 本地开发: `localhost`
  - 服务器部署: `your-server.example.com` 或服务器IP
  - Docker 部署: 容器IP或域名
  - 云平台部署: 平台提供的域名

### 🔒 CORS配置
- `CORS_ORIGIN` - 允许的跨域来源 (默认: *)

### 📝 日志配置
- `LOG_LEVEL` - 日志级别 (默认: info)

### 📦 构建文件目录结构
```bash
$BASE_DIR/
├── bin/                   # 二进制文件 (bun, mihomo)
│   ├── bun
│   └── mihomo
├── www/                   # 数据文件
│   ├── subscription.txt
│   ├── clash.yaml
│   └── backup/
├── log/                   # 日志文件
│   ├── combined.log
│   └── error.log
└── dist/                  # 构建文件
    ├── frontend/          # 前端构建文件 (Next.js)
    │   ├── index.html
    │   ├── _next/
    │   └── ...
    └── backend/           # 后端构建文件 (TypeScript)
        ├── index.js
        └── ...
```

> **注意**: 前端和后端构建文件自动存放在固定的子目录中，无需单独配置环境变量

## 📝 配置文件示例

### `.env` 文件示例
```bash
# 基础配置
PORT=3000
NODE_ENV=production
SERVICE_NAME=subscription-api-ts

# 服务端口
NGINX_PORT=3080
NGINX_PROXY_PORT=3888

# 订阅配置
SING_BOX_CONFIGS=vless,hysteria2,trojan,tuic,vmess

# 目录配置
BASE_DIR=/home/user/.config/subscription
DATA_DIR=/home/user/.config/subscription/www
LOG_DIR=/home/user/.config/subscription/log
DIST_DIR=/home/user/.config/subscription/dist
MIHOMO_PATH=/home/user/.config/subscription/bin
BUN_PATH=/home/user/.config/subscription/bin

# 定时任务
AUTO_UPDATE_CRON=0 */2 * * *

# 网络配置
MAX_RETRIES=3
REQUEST_TIMEOUT=30000
EXTERNAL_HOST=your-domain.com

# 安全配置
CORS_ORIGIN=*

# 日志配置
LOG_LEVEL=info
```

## ⚙️ 配置管理

### 动态配置更新

项目提供 API 接口来动态管理配置：

#### 获取当前配置
```bash
curl http://localhost:3000/api/configs
```

#### 更新配置列表
```bash
curl -X POST http://localhost:3000/api/configs \
  -H "Content-Type: application/json" \
  -d '{"configs": ["vless", "hysteria2"]}'
```

### 配置特性

- **动态更新**：API 更新的配置立即生效，无需重启
- **配置来源**：默认从环境变量 `SING_BOX_CONFIGS` 读取
- **持久性**：服务重启后恢复到环境变量默认值
- **格式验证**：配置名称必须是非空字符串数组

## 🔧 高级配置

### Systemd服务配置
服务将自动使用以下环境变量：
- `SERVICE_USER` - 运行服务的用户
- `SERVICE_GROUP` - 运行服务的用户组
- `INSTALL_DIR` - 项目安装目录

### Nginx配置变量
Nginx配置模板会自动替换以下变量：
- `${API_PORT}` - 后端API端口
- `${NGINX_PORT}` - Nginx监听端口
- `${NGINX_PROXY_PORT}` - Nginx代理端口
- `${DATA_DIR}` - 静态文件目录
- `${LOG_DIR}` - 日志文件目录
- `${DIST_DIR}` - 前端构建文件目录

## 📋 环境变量验证

项目启动时会自动验证必需的环境变量：

### ✅ 必需变量
- `PORT` - API服务端口
- `SING_BOX_CONFIGS` - 至少一个配置名称

### ⚠️ 可选变量（有默认值）
- 所有其他变量都有合理的默认值
- 如果未设置，将使用文档中标注的默认值

## 🔍 配置验证

### 自动检查
```bash
# 验证所有环境变量
./manage.sh overview

# 检查配置文件
bun run build
```

### 手动检查
```bash
# 搜索硬编码值
grep -r "3000\|3080\|25500" src/ --exclude-dir=node_modules

# 搜索硬编码路径  
grep -r "/var/www\|/var/log" src/ --exclude-dir=node_modules
```

## 📖 快速开始

1. **复制配置模板**：
   ```bash
   cp .env.example .env
   ```

2. **编辑配置**：
   ```bash
   nano .env  # 根据你的环境修改配置
   ```

3. **验证配置**：
   ```bash
   ./manage.sh overview
   ```

4. **启动服务**：
   ```bash
   bun run dev    # 开发模式
   bun start      # 生产模式
   ```

## 🚨 重要注意事项

1. **路径配置**: 所有路径建议使用绝对路径
2. **权限配置**: 确保服务用户对所有目录有适当的读写权限
3. **端口配置**: 确保配置的端口不与其他服务冲突
4. **安全配置**: 生产环境中请修改默认的配置

## 🔍 故障排除

如果遇到配置问题：

1. 检查 `.env` 文件格式是否正确
2. 确认所有目录路径存在且有正确权限
3. 验证端口配置不冲突
4. 检查外部服务地址可达性
5. 查看服务日志获取详细错误信息

## 🔗 相关文档

- [故障排除指南](./TROUBLESHOOTING.md) - 详细的错误诊断和解决方案
- [项目结构说明](./PROJECT_STRUCTURE.md) - 项目文件组织
- [README.md](./README.md) - 项目概述和安装指南

更多故障排除信息请参考 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

所有配置通过环境变量统一管理，确保配置的一致性和灵活性！🎉
