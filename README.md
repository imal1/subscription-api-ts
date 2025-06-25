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
- Base URL: http://your-server:5000
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
curl -X POST http://localhost:3000/api/update

# 获取状态
curl http://localhost:3000/api/status

# 获取 Clash 配置
curl http://localhost:3000/clash.yaml

# 健康检查
curl http://localhost:3000/health
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
NGINX_PORT=8080

# 网络超时配置
REQUEST_TIMEOUT=30000
```

### Nginx配置生成
项目提供了自动生成nginx配置的功能：

```bash
# 根据.env文件生成nginx配置
npm run nginx:config
```

该命令会根据当前的环境变量生成对应的nginx配置文件：
- 开发环境：生成 `config/nginx.dev.conf`
- 生产环境：生成 `config/nginx.conf`

所有端口配置都将从环境变量中读取，确保配置一致性。
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
  -p 5000:5000 \
  -v ./data:/app/data \
  -v ./logs:/app/logs \
  --env-file .env \
  subscription-api-ts
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
```Code
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
- sing-box - 通用代理工具
- subconverter - 订阅转换工具
- Express.js - Web 框架
## 📞 支持
如果您遇到任何问题，请：

1. 查看 文档
2. 搜索 Issues
3. 创建新的 Issue
------
⭐ 如果这个项目对您有帮助，请给个星标！

