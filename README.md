# Subscription API TypeScript

🚀 一个基于 TypeScript 的 sing-box 订阅转换 API 服务，支持将 sing-box 配置自动转换为 Clash 订阅格式。

## 🔥 重要更新 - 迁移到 Mihomo

> ⚠️ **BREAKING CHANGE**: 从 v2.0.0 开始，本项目已完全迁移到 **mihomo (clash-meta)** 内核，不再使用 subconverter。
> 
> **为什么迁移？**
> - subconverter 不支持 vless/hysteria2/tuic 等新协议
> - mihomo 提供原生协议支持，转换更准确
> - 无需外部服务依赖，简化部署流程
> - 更好的性能和稳定性
>
> 📖 **迁移指南**: 请查看 [MIGRATION_TO_MIHOMO.md](./MIGRATION_TO_MIHOMO.md) 了解详细迁移步骤
>
> **旧版本支持**: subconverter 版本 (v1.x) 已停止维护，建议尽快迁移到 v2.0.0+

## ✨ 功能特性

- 🔄 **自动转换**: 自动获取 sing-box 节点配置并转换为 Clash 格式
- 🌟 **多协议支持**: 原生支持 vless、vmess、hysteria2、tuic、trojan、shadowsocks
- 🤖 **智能下载**: 自动下载和管理最新 mihomo 二进制文件
- 🕒 **定时更新**: 支持定时自动更新订阅
- 🛡️ **类型安全**: 完整的 TypeScript 支持
- 🌐 **REST API**: 提供完整的 REST API 接口
- 📊 **状态监控**: 实时监控服务状态和健康检查
- 📝 **日志系统**: 完善的日志记录和错误处理
- 🔧 **无外部依赖**: 不再需要 subconverter 服务
- �️ **支持 systemd 服务管理**
- 🐳 **容器化**: 支持 Docker 部署

## 🏗️ 技术栈

- **后端**: TypeScript + Node.js + Express.js
- **转换内核**: mihomo (clash-meta)
- **前端**: Next.js + React + Tailwind CSS
- **代理**: Nginx
- **日志**: Winston
- **进程管理**: systemd / PM2
- **定时任务**: node-cron

## 📋 系统要求

- Ubuntu 18.04+ / Debian 10+ / CentOS 8+ / macOS 10.15+
- **Node.js 18+** （推荐使用官方安装包，避免版本管理器）
- sing-box (已安装配置)

### 💡 Node.js 安装建议

**强烈推荐使用官方 Node.js 安装包**，以确保 systemd 服务的兼容性：

**Ubuntu/Debian:**
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

**CentOS/RHEL:**
```bash
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs
```

**或访问 [nodejs.org](https://nodejs.org/) 下载官方安装包**

⚠️ **注意**: 请避免使用 fnm、nvm 等版本管理器，因为它们的 Node.js 路径在 systemd 服务中可能不可用。

## 💪 包管理工具

本项目推荐使用 [Bun](https://bun.sh) 作为包管理工具和运行时环境。Bun 比 npm 和 Node.js 拥有更快的执行速度和更低的内存占用，特别适合在低配置服务器上运行。

```bash
# 安装 Bun (Linux & macOS)
curl -fsSL https://bun.sh/install | bash

# 验证安装
bun --version
```

💡 **提示**: 即使在低配置服务器上，Bun 也能高效地安装依赖，不会出现 "JavaScript heap out of memory" 错误。

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/imal1/subscription-api-ts.git
cd subscription-api-ts
```

### 2. 自动安装
```bash
# 方法1：使用快速安装脚本（推荐）
bash scripts/install.sh

# 方法2：使用管理脚本
bash scripts/manage.sh setup

# 方法3：分步安装
bash scripts/manage.sh init   # 初始化环境
bash scripts/manage.sh build  # 构建项目
```

### 3. 配置环境
```bash
# 配置文件会自动创建在 ~/.config/subscription/config.yaml

# 编辑配置 (修改为您的实际配置)
nano .env
```

### 4. 启动服务

#### 🎯 使用管理脚本（推荐）
```bash
# 查看服务状态
./manage.sh status

# 启动服务
./manage.sh start

# 重启服务  
./manage.sh restart

# 停止服务
./manage.sh stop

# 全面状态检查
./manage.sh check
```

#### 📋 传统方式
```bash
# Linux (systemd)
sudo systemctl start subscription-api-ts
sudo systemctl status subscription-api-ts
sudo systemctl enable subscription-api-ts

# 直接使用 Bun
bun start
# 或使用 PM2
pm2 start dist/index.js --name subscription-api-ts
# 或使用 PM2
pm2 start dist/index.js --name subscription-api-ts
```

## 🎮 管理脚本

项目提供了重构后的统一管理脚本 `scripts/manage.sh`，集成了所有常用功能：

### 🚀 核心管理命令
```bash
# 环境管理
bash scripts/manage.sh init    # 初始化项目环境
bash scripts/manage.sh setup   # 完整安装配置
bash scripts/manage.sh env     # 显示环境信息
bash scripts/manage.sh config  # 显示配置信息

# 服务管理 (Linux)
sudo bash scripts/manage.sh start    # 启动服务
sudo bash scripts/manage.sh stop     # 停止服务
sudo bash scripts/manage.sh restart  # 重启服务
sudo bash scripts/manage.sh status   # 查看服务状态
sudo bash scripts/manage.sh logs     # 查看服务日志
sudo bash scripts/manage.sh logs-f   # 实时跟踪日志
```

### 🔧 构建工具
```bash
bash scripts/manage.sh build          # 构建项目 (后端+前端)
bash scripts/manage.sh build-backend  # 仅构建后端
bash scripts/manage.sh build-frontend # 仅构建前端
bash scripts/manage.sh clean          # 清理构建文件
```

### 🛠️ 维护工具
```bash
bash scripts/manage.sh check    # 系统检查
bash scripts/manage.sh verify   # 验证权限
bash scripts/manage.sh update   # 更新项目 (开发中)
bash scripts/manage.sh backup   # 备份配置 (开发中)
```

### 📋 快速开始
```bash
./manage.sh logs             # 查看服务日志
./manage.sh version          # 显示版本信息
./manage.sh overview         # 项目状态概览
./manage.sh api-help         # API 端点使用说明
./manage.sh help             # 显示帮助信息
```

### ✨ 全新功能: 现代化 Dashboard

项目现在包含一个基于 Next.js 的现代化 Web Dashboard：

```bash
# 构建并部署 Dashboard
./manage.sh deploy-dashboard

# 仅构建前端
./manage.sh build-frontend

# 测试 Dashboard 功能
./scripts/test-dashboard.sh
```

**Dashboard 特性:**
- 🎨 现代化 UI 设计 (基于 shadcn/ui)
- 📊 实时服务状态监控
- ⚡ 快速操作面板
- 📱 响应式设计
- 🔧 API 接口测试工具
- 📖 集成文档说明

**访问 Dashboard:**
- 生产环境: `http://localhost:3888/dashboard/`
- 开发环境: 需要单独启动前端服务

```bash
# 查看所有可用命令
./manage.sh help

# 🚀 核心管理
./manage.sh install      # 完整项目安装
./manage.sh start        # 启动服务
./manage.sh stop         # 停止服务  
./manage.sh restart      # 重启服务
./manage.sh status       # 快速状态检查
./manage.sh check        # 全面状态诊断

# 🔧 开发工具
./manage.sh build        # 编译项目
./manage.sh dev          # 开发模式
./manage.sh test         # 运行测试
./manage.sh clean        # 清理编译文件

# 🛠️ 问题诊断
./manage.sh diagnose     # 系统诊断
./manage.sh fix          # 自动修复
./manage.sh fix-ts       # 修复 TypeScript 问题
./manage.sh fix-systemd-workdir  # 修复系统路径问题

# 📋 信息查看
./manage.sh logs         # 查看日志
./manage.sh version      # 版本信息
```
## 📖 API 文档

### 基础信息
- Base URL: http://your-server:${PORT} （默认 3000，可通过 .env 配置）
- Content-Type: application/json

### 端点列表
|方法|端点|描述|注意事项|
|--|--|--|--|
|GET|`/`|API文档||
|GET|`/health`|健康检查||
|**GET**|`/api/update`|更新订阅|✅ **支持GET方法**|
|GET|`/api/status`|获取状态||
|GET|`/api/configs`|获取配置列表||
|POST|`/api/configs`|更新配置列表||
|GET|`/subscription.txt`|获取订阅文件||
|GET|`/clash.yaml`|获取Clash配置||
|GET|`/raw.txt`|获取原始链接||

### ✅ 使用说明

**`/api/update` 端点现在支持 GET 方法！**

您可以通过简单的 GET 请求来更新订阅：

```bash
# ✅ 正确用法（支持多种方式）
curl http://localhost:3000/api/update
curl -X GET http://localhost:3000/api/update
wget http://localhost:3000/api/update
# 也可以直接在浏览器中访问
```

### 使用示例
```bash
# 更新订阅（现在使用GET方法）
curl http://localhost:${PORT}/api/update

# 获取状态
curl http://localhost:${PORT}/api/status

# 获取 Clash 配置
curl http://localhost:${PORT}/clash.yaml

# 健康检查
curl http://localhost:${PORT}/health

# 测试所有端点
./test-api-endpoints.sh
```
## ⚙️ 配置说明
主要配置文件为 .env：

```bash
# 服务端口
PORT=3000

# sing-box 配置名称 (逗号分隔)
SING_BOX_CONFIGS=vless-reality,hysteria2,trojan,tuic,vmess

# 定时更新 (cron 格式)
AUTO_UPDATE_CRON=0 */2 * * *

# Nginx端口配置
NGINX_PORT=3080

# 网络超时配置
REQUEST_TIMEOUT=30000
```

### Nginx配置生成和安装
项目提供了自动生成和安装nginx配置的功能：

```bash
# 生成nginx配置文件
bun run nginx:config

# 自动安装和配置nginx (Linux)
bun run nginx:setup
```

**配置说明:**
- `nginx:config` - 根据.env文件生成配置文件
- `nginx:setup` - 自动安装nginx并应用配置 (仅限Linux)

生成的配置文件：
- 生产环境：`config/nginx.conf`

**端口说明:**
- 主要API代理：3888端口 (默认，可通过 NGINX_PROXY_PORT 配置)
- 静态文件服务：3080端口 (可通过 NGINX_PORT 配置)

所有端口配置都将从环境变量中读取，确保配置一致性。

**注意事项:**
- Linux: 脚本会自动处理nginx的安装、配置和启动
- macOS: 需要手动配置，脚本会提供详细说明

### Systemd服务配置生成
对于Linux环境，项目提供了自动生成systemd服务配置的功能：

```bash
# 生成服务配置文件
bun run systemd:service /path/to/installation/directory

# 例如，如果项目安装在当前目录
bun run systemd:service $(pwd)

# 或者如果安装在 /opt/subscription-api-ts
bun run systemd:service /opt/subscription-api-ts
```

该命令会：
- 自动检测Node.js路径
- 使用当前用户作为服务运行用户
- 根据实际安装路径生成正确的配置
- 生成可直接使用的systemd服务文件

生成的服务文件将保存在 `/tmp/subscription-api-ts.service`，可以直接复制到系统目录并启用服务。

## 📦 部署方式
### 方式一：systemd 服务 (推荐)
```bash
# 使用安装脚本
./scripts/install.sh

# 或手动部署
./scripts/deploy.sh
```
### 方式二：PM2 部署
```bash
# 安装 PM2
bun add -g pm2

# 启动服务
pm2 start dist/index.js --name subscription-api

# 保存配置
pm2 save
pm2 startup
```
### 方式三：Docker 部署
```bash
# 构建镜像
docker build -t subscription-api-ts .

# 运行容器
docker run -d \
  --name subscription-api \
  -p ${PORT:-3000}:${PORT:-3000} \
  -v ./data:/app/data \
  -v ./logs:/app/logs \
  --env-file .env \
  subscription-api-ts
```
## 🛠️ 服务诊断与监控

### 一键服务状态检查

我们提供了专门的诊断脚本来检查 subscription-api-ts 服务的完整状态：

```bash
# 🔍 全面服务状态检测（推荐）
./scripts/check-service-status.sh

# ⚡ 快速状态检查（日常监控）
./scripts/quick-status.sh
```

**全面诊断脚本功能**：
- ✅ **环境检查**: Node.js 版本、依赖、配置文件
- ✅ **进程状态**: Linux systemd 服务或 macOS 进程状态  
- ✅ **端口检查**: 应用端口、Nginx 端口、代理端口占用情况
- ✅ **连接测试**: 健康检查接口、服务响应测试
- ✅ **配置验证**: Nginx 配置文件、代理设置检查
- ✅ **日志分析**: 最新服务日志和错误信息
- ✅ **故障建议**: 根据检查结果提供具体修复建议

**快速检查脚本功能**：
- 🚀 核心状态概览（进程、端口、健康检查、编译文件）
- 💡 简单故障排除建议
- ⚡ 适合日常监控和快速检查

### 传统诊断工具

如果遇到编译或路径问题，可以使用以下命令快速诊断：

```bash
# 检查路径配置和编译环境
bun run config:check

# TypeScript 编译问题诊断
bun run ts:diagnose
./scripts/diagnose-typescript.sh

# 自动修复 TypeScript 问题  
bun run ts:fix
./scripts/fix-typescript.sh

# 系统服务诊断（Linux）
./scripts/diagnose-systemd.sh

# 自动修复系统服务问题
./scripts/fix-systemd.sh

# 修复 Node.js 路径问题
./scripts/fix-node-path.sh

# 验证环境变量加载
bun run config:validate

# 检查服务状态
bun run service:status
```

### 常见问题解决

**TypeScript 编译错误**（找不到模块声明文件）：
```bash
# 自动诊断和修复
bun run ts:fix

# 或手动清理重装
rm -rf node_modules bun.lock
bun install
bun run build
```

## 🔧 开发
### 开发环境
```bash
# 安装依赖
bun install

# 开发模式 (热重载)
bun run dev:watch

# 构建
bun run build

# 生产模式
bun start
```
### 项目结构

详细的项目结构请参见 [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md)。

```
src/
├── types/           # TypeScript 类型定义
├── config/          # 配置管理
├── utils/           # 工具函数
├── services/        # 业务服务
├── controllers/     # 控制器
├── routes/          # 路由定义
├── app.ts          # 应用主文件
└── index.ts        # 入口文件
```
## 🐛 故障排除
### 常见问题
1. 服务启动失败

```bash
# 检查日志
sudo journalctl -u subscription-api-ts -f

# 检查配置
bun run dev
```
2. sing-box 连接失败

```bash
# 检查 sing-box 状态
sing-box

# 验证配置名称
sing-box info your-config-name
```

### 日志查看
```bash
# 系统日志
sudo journalctl -u subscription-api-ts --since "1 hour ago"

# 应用日志
tail -f ./logs/combined.log

# 错误日志
tail -f ./logs/error.log
```
## 🚨 故障排除

### Linux SystemD 服务问题

如果在Linux环境下使用 `systemctl status` 时遇到问题，可以使用以下方法诊断和修复：

#### 快速诊断
```bash
# 检查服务状态（跨平台）
bun run service:status

# Linux 专用诊断
bash scripts/diagnose-systemd.sh
```

#### 常见问题及解决方案

1. **服务文件不存在**
   ```bash
   # 重新生成服务配置
   bun run systemd:service $(pwd)
   sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

2. **权限问题**
   ```bash
   # 使用 sudo 执行
   sudo systemctl status subscription-api-ts
   sudo journalctl -u subscription-api-ts
   ```

3. **服务配置错误**
   ```bash
   # 一键修复（需要 sudo 权限）
   bun run service:fix
   ```

4. **工作目录问题 (CHDIR 失败)**
   ```bash
   # 专门修复 systemd 工作目录问题
   bash scripts/fix-systemd-workdir.sh
   
   # 或使用管理脚本
   ./manage.sh fix-systemd-workdir
   ```

5. **项目路径问题**
   ```bash
   # 确保项目已构建
   bun run build
   
   # 重新安装到正确路径
   sudo bash scripts/install.sh
   ```

#### 自动修复脚本

项目提供了自动修复脚本，可以解决 SystemD 相关问题：

```bash
# 通用服务修复（需要 sudo 权限）
sudo bun run service:fix

# 专门修复 systemd 工作目录问题
bash scripts/fix-systemd-workdir.sh

# 使用统一管理工具
./manage.sh fix-systemd-workdir    # 修复工作目录问题
./manage.sh fix                    # 自动修复常见问题
./manage.sh check                  # 全面诊断
```

**工作目录修复脚本功能：**
- 自动检测和修复 `WorkingDirectory` 路径错误
- 验证和修复 Node.js 可执行文件路径
- 检查和重新编译项目（如需要）
- 创建缺失的环境文件
- 重新生成正确的 systemd 服务文件
- 自动重启服务并验证状态

该脚本会：
- 清理旧的服务配置
- 重新生成正确的服务文件
- 修复权限问题
- 重新启动服务
- 验证服务状态

#### 常见 SystemD 错误分析

**错误：`Failed at step CHDIR spawning /usr/local/bin/node: No such file or directory`**

这个错误通常表示：
1. `WorkingDirectory` 路径不存在或无效
2. Node.js 可执行文件路径错误
3. 服务用户没有访问工作目录的权限

**推荐解决方案：**
1. **使用官方 Node.js 安装包**（推荐）
2. **使用修复脚本**：
   ```bash
   bash scripts/fix-systemd-workdir.sh
   ```
3. **手动复制到系统路径**：
   ```bash
   sudo cp $(which node) /usr/local/bin/node
   sudo chmod +x /usr/local/bin/node
   ```
## 🤝 贡献
欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (git checkout -b feature/AmazingFeature)
3. 提交更改 (git commit -m 'Add some AmazingFeature')
4. 推送到分支 (git push origin feature/AmazingFeature)
5. 开启 Pull Request
## 📄 许可证
本项目基于 MIT 许可证开源。详见 LICENSE 文件。

## 🙏 致谢
- [sing-box](https://github.com/233boy/sing-box) - 通用代理工具
- [mihomo (clash-meta)](https://github.com/MetaCubeX/mihomo) - 规则处理引擎
- [Express.js](https://github.com/expressjs/express) - Web 框架
## 📞 支持
如果您遇到任何问题，请：

1. 查看 文档
2. 搜索 Issues
3. 创建新的 Issue
------
⭐ 如果这个项目对您有帮助，请给个星标！

## 🔧 安装

### 自动安装脚本

项目提供了自动安装脚本，支持多种执行方式：

#### Linux 环境

```bash
# 方式1: 普通用户执行（推荐）
bash scripts/install.sh

# 方式2: 使用 sudo 执行（保留用户身份）
sudo bash scripts/install.sh

# 方式3: root 用户直接执行
# 作为 root 用户登录后执行
bash scripts/install.sh
```

**执行方式说明：**

- **普通用户执行**：脚本会自动使用 `sudo` 处理需要管理员权限的操作
- **sudo 执行**：推荐方式，脚本会使用原用户身份配置服务，避免权限问题
- **root 直接执行**：脚本会询问是否以 root 身份安装，或自动检测原用户

#### macOS 环境

```bash
# macOS 仅支持普通用户执行
bash scripts/install.sh
```

**注意：** macOS 环境下不支持 root 用户执行安装脚本。

