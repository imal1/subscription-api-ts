# Subscription API TypeScript

🚀 一个基于 TypeScript 的 sing-box 订阅转换 API 服务，支持将 sing-box 配置自动转换为 Clash 订阅格式。

## ✨ 功能特性

- 🔄 **自动转换**: 自动获取 sing-box 节点配置并转换为 Clash 格式
- 🕒 **定时更新**: 支持定时自动更新订阅
- 🛡️ **类型安全**: 完整的 TypeScript 支持
- 🌐 **REST API**: 提供完整的 REST API 接口
- 📊 **状态监控**: 实时监控服务状态和健康检查
- 📝 **日志系统**: 完善的日志记录和错误处理
- 🔧 **易于部署**: 支持 systemd 服务管理
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
```bash
# 启动服务
sudo systemctl start subscription-api-ts

# 检查状态
sudo systemctl status subscription-api-ts

# 设置开机启动
sudo systemctl enable subscription-api-ts
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
- 主要API代理：3888端口 (默认)
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
## 🛠️ 快速诊断

如果遇到编译或路径问题，可以使用以下命令快速诊断：

```bash
# 检查路径配置和编译环境
npm run config:check

# TypeScript 编译问题诊断
npm run ts:diagnose

# 自动修复 TypeScript 问题
npm run ts:fix

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

4. **项目路径问题**
   ```bash
   # 确保项目已构建
   npm run build
   
   # 重新安装到正确路径
   sudo bash scripts/install.sh
   ```

#### 自动修复脚本

项目提供了自动修复脚本，可以解决大部分 SystemD 相关问题：

```bash
# Linux 环境下运行（需要 sudo 权限）
sudo npm run service:fix
```

该脚本会：
- 清理旧的服务配置
- 重新生成正确的服务文件
- 修复权限问题
- 重新启动服务
- 验证服务状态
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

