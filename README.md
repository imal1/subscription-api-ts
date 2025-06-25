# Subscription API TypeScript

🚀 一个基于 TypeScript 的 sing-box 订阅转换 API 服务，支持将 sing-box 配置自动转换为 Clash 订阅格式。

## ✨ 功能特性

- 🔄 **自动转换**: 自动获取 sing-box 节点配置并转换为 Clash 格式
- 🕒 **定时更新**: 支持定时自动更新订阅
- 🛡️ **类型安全**: 完整的 TypeScript 支持
- 🌐 **REST API**: 提供完整的 REST API 接口
- 📊 **状态监控**: 实时监控服务状态和健康检查
- 📝 **日志系统**: 完善的日志记录和错误处理
- 🔧**常见问题解决**

**1. TypeScript 编译错误**（找不到模块声明文件）：
```bash
# 自动诊断和修复
./manage.sh fix-ts

# 或手动清理重装
rm -rf node_modules package-lock.json
npm install
npm run build
```

**2. SystemD 服务工作目录错误**：
```bash
# 错误信息：Changing to the requested working directory failed
./manage.sh diagnose-workdir    # 诊断问题
./manage.sh fix-workdir         # 自动修复
```

**3. Node.js 路径问题**（版本管理器冲突）：
```bash
./manage.sh fix-node           # 修复 Node.js 路径
```持 systemd 服务管理
- 🐳 **容器化**: 支持 Docker 部署

## 🏗️ 技术栈

- **后端**: TypeScript + Node.js + Express.js
- **转换器**: Subconverter
- **代理**: Nginx
- **日志**: Winston
- **进程管理**: systemd / PM2
- **定时任务**: node-cron

## 📋 系统要求

- Ubuntu 18.04+ / Debian 10+
- Node.js 18+
- sing-box (已安装配置)
- subconverter 服务

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/imal1/subscription-api-ts.git
cd subscription-api-ts
```

### 2. 自动安装
```bash
# 方法1：使用管理脚本（推荐）
./manage.sh install

# 方法2：直接使用安装脚本
chmod +x scripts/install.sh
./scripts/install.sh
```

### 3. 配置环境
```bash
# 复制配置文件
cp .env.example .env

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

# macOS  
npm start
# 或使用 PM2
pm2 start dist/index.js --name subscription-api-ts
```

## 🎮 管理脚本

项目提供了统一的管理入口脚本 `manage.sh`，集成了所有常用功能：

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
./manage.sh fix-node     # 修复 Node.js 路径

# 📋 信息查看
./manage.sh logs         # 查看日志
./manage.sh version      # 版本信息
```
## 📖 API 文档
### 基础信息
- Base URL: http://your-server:${PORT} （默认 3000，可通过 .env 配置）
- Content-Type: application/json
### 端点列表
|方法|端点|描述|
|--|--|--|
|GET|`/`|API文档|
|GET|`/health`|健康检查|
|POST|`/api/update`|更新订阅|
|GET|`/api/status`|获取状态|
|GET|`/api/configs`|获取配置列表|
|POST|`/api/configs`|更新配置列表|
|GET|`/subscription.txt`|获取订阅文件|
|GET|`/clash.yaml`|获取Clash配置|
|GET|`/raw.txt`|获取原始链接|
### 使用示例
```bash
# 更新订阅
curl -X POST http://localhost:${PORT}/api/update

# 获取状态
curl http://localhost:${PORT}/api/status

# 获取 Clash 配置
curl http://localhost:${PORT}/clash.yaml

# 健康检查
curl http://localhost:${PORT}/health
```
## ⚙️ 配置说明
主要配置文件为 .env：

```bash
# 服务端口
PORT=3000

# sing-box 配置名称 (逗号分隔)
SING_BOX_CONFIGS=vless-reality,hysteria2,trojan,tuic,vmess

# subconverter 地址
SUBCONVERTER_URL=http://localhost:25500

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
npm run nginx:config

# 自动安装和配置nginx (Linux)
npm run nginx:setup
```

**配置说明:**
- `nginx:config` - 根据.env文件生成配置文件
- `nginx:setup` - 自动安装nginx并应用配置 (仅限Linux)

生成的配置文件：
- 开发环境：`config/nginx.dev.conf`
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
npm run systemd:service /path/to/installation/directory

# 例如，如果项目安装在当前目录
npm run systemd:service $(pwd)

# 或者如果安装在 /opt/subscription-api-ts
npm run systemd:service /opt/subscription-api-ts
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
npm install -g pm2

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
npm run config:check

# TypeScript 编译问题诊断
npm run ts:diagnose
./scripts/diagnose-typescript.sh

# 自动修复 TypeScript 问题  
npm run ts:fix
./scripts/fix-typescript.sh

# 系统服务诊断（Linux）
./scripts/diagnose-systemd.sh

# 自动修复系统服务问题
./scripts/fix-systemd.sh

# 修复 Node.js 路径问题
./scripts/fix-node-path.sh

# 验证环境变量加载
npm run config:validate

# 检查服务状态
npm run service:status
```

### 常见问题解决

**TypeScript 编译错误**（找不到模块声明文件）：
```bash
# 自动诊断和修复
npm run ts:fix

# 或手动清理重装
rm -rf node_modules package-lock.json
npm install
npm run build
```

## 🔧 开发
### 开发环境
```bash
# 安装依赖
npm install

# 开发模式 (热重载)
npm run dev:watch

# 构建
npm run build

# 生产模式
npm start
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
npm run dev
```
2. sing-box 连接失败

```bash
# 检查 sing-box 状态
sing-box

# 验证配置名称
sing-box info your-config-name
```
3. subconverter 不可用

```bash
# 检查 subconverter 服务
sudo systemctl status subconverter

# 测试连接
curl http://localhost:25500/version
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
npm run service:status

# Linux 专用诊断
bash scripts/diagnose-systemd.sh
```

#### 常见问题及解决方案

1. **服务文件不存在**
   ```bash
   # 重新生成服务配置
   npm run systemd:service $(pwd)
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
   npm run service:fix
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
   npm run build
   
   # 重新安装到正确路径
   sudo bash scripts/install.sh
   ```

#### 自动修复脚本

项目提供了多种自动修复脚本，可以解决不同类型的 SystemD 相关问题：

```bash
# 通用服务修复（需要 sudo 权限）
sudo npm run service:fix

# 专门修复 systemd 工作目录问题
bash scripts/fix-systemd-workdir.sh

# FNM 用户专用修复（推荐 fnm 用户使用）
bash scripts/fix-fnm-systemd.sh

# 使用统一管理工具
./manage.sh fix-systemd-workdir    # 修复工作目录问题
./manage.sh fix-fnm               # fnm 用户专用修复
./manage.sh fix                    # 自动修复常见问题
./manage.sh check                  # 全面诊断
```

**FNM 用户特别说明：**

如果你使用 fnm (Fast Node Manager) 管理 Node.js 版本，建议使用专门的修复脚本：

```bash
# FNM 用户专用修复
bash scripts/fix-fnm-systemd.sh
# 或
./manage.sh fix-fnm
```

该脚本会：
- 自动检测 fnm 管理的 Node.js 路径
- 将 Node.js 复制到系统路径 (`/usr/local/bin/node`)
- 生成适合 systemd 的服务配置
- 自动启动和验证服务状态

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

**FNM 用户常见问题：**

fnm (Fast Node Manager) 是一个现代的 Node.js 版本管理器，但它会将 Node.js 安装在用户目录下（如 `~/.local/share/fnm/node-versions/`），systemd 服务运行时无法访问这些路径。

**FNM 路径示例：**
- `~/.local/share/fnm/node-versions/v18.19.0/installation/bin/node`
- `~/.fnm/node-versions/v20.11.0/installation/bin/node`

**问题原因：**
1. systemd 服务在独立的环境中运行，没有用户的 shell 环境变量
2. fnm 通过修改 PATH 和环境变量来工作，但这些在 systemd 中不可用
3. 服务启动时找不到 Node.js 可执行文件，导致 `CHDIR` 或 `EXEC` 失败

**解决方案：**

**解决方案：**
```bash
# 方法1：快速检查是否为 fnm 问题
bash scripts/check-fnm.sh

# 方法2：针对 FNM 用户的专用修复
bash scripts/fix-fnm-systemd.sh

# 方法3：使用管理工具
./manage.sh check-fnm        # 检查问题
./manage.sh fix-fnm          # 修复问题

# 方法4：手动修复
sudo cp $(which node) /usr/local/bin/node
sudo chmod +x /usr/local/bin/node

# 然后重新生成服务文件
bash scripts/generate-systemd-service.sh $(pwd)
sudo cp /tmp/subscription-api-ts.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart subscription-api-ts
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
- [subconverter](https://github.com/tindy2013/subconverter) - 订阅转换工具
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

