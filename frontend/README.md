# 前端 Dashboard 使用说明

## 概述

这个前端 Dashboard 是一个基于 Next.js 和 Tailwind CSS 构建的现代化 Web 界面，用于管理和监控 Subscription API 服务。

## 特性

- **实时状态监控**: 显示服务状态、文件信息、节点数量等
- **快速操作**: 一键更新订阅、下载配置文件
- **API 接口测试**: 直接在界面中测试各个 API 端点
- **响应式设计**: 支持桌面和移动设备
- **现代化 UI**: 使用 shadcn/ui 组件库

## 技术栈

- **框架**: Next.js 14
- **样式**: Tailwind CSS
- **UI组件**: 基于 Radix UI 的 shadcn/ui
- **图标**: Iconify React
- **构建**: 静态导出，支持 Nginx 部署

## 快速开始

### 1. 构建前端

```bash
# 构建前端 Dashboard
./manage.sh build-frontend

# 或者手动构建
cd frontend
bun install
bun run build
```

### 2. 完整部署

```bash
# 构建并部署整个系统（包括前端和后端）
./manage.sh deploy-dashboard
```

### 3. 访问 Dashboard

部署完成后，访问：
- 生产环境: `http://localhost:3888/dashboard/`
- 开发环境: `http://localhost:3000` (API) + 单独的前端服务

## 目录结构

```
frontend/
├── src/
│   ├── components/
│   │   ├── ui/           # UI 组件
│   │   └── Dashboard.tsx # 主 Dashboard 组件
│   ├── lib/
│   │   ├── api.ts        # API 服务
│   │   └── utils.ts      # 工具函数
│   ├── pages/            # Next.js 页面
│   └── styles/           # 样式文件
├── dist/                 # 构建输出目录
├── package.json
├── next.config.js
├── tailwind.config.js
└── build.sh             # 构建脚本
```

## 主要功能

### 1. 状态概览

- **服务状态**: 显示 Subconverter 和 Sing-box 的运行状态
- **文件状态**: 显示订阅文件、Clash 配置等的生成状态
- **节点统计**: 显示当前可用节点数量
- **运行时间**: 显示服务运行时长

### 2. 快速操作

- **更新订阅**: 一键更新所有订阅内容
- **下载文件**: 直接下载订阅文件、Clash 配置、原始链接
- **刷新状态**: 手动刷新系统状态

### 3. API 接口文档

- **接口列表**: 显示所有可用的 API 端点
- **快速测试**: 直接在界面中测试 API 接口
- **实时结果**: 显示 API 调用结果和错误信息

## 配置说明

### 环境变量

Dashboard 会自动读取以下环境变量：

- `PORT`: API 服务端口
- `NGINX_PROXY_PORT`: Nginx 代理端口

### API 基础路径

- 生产环境: 使用相对路径（由 Nginx 代理）
- 开发环境: `http://localhost:3000`

## 部署方式

### 方式 1: Nginx 集成部署（推荐）

```bash
./manage.sh deploy-dashboard
```

这会：
1. 构建前端和后端
2. 生成 Nginx 配置
3. 配置路由和代理

### 方式 2: 手动部署

1. 构建前端：
```bash
cd frontend
bun run build
```

2. 将 `frontend/dist/` 目录内容部署到 Web 服务器

3. 配置反向代理到 API 服务

### 方式 3: 开发模式

```bash
# 启动 API 服务
bun run dev

# 另一个终端启动前端开发服务器
cd frontend
bun run dev
```

## Nginx 配置

Dashboard 集成了 Nginx 配置，主要路由：

- `/dashboard/` - 前端静态文件
- `/api/` - API 接口代理
- `/` - 重定向到 Dashboard
- `/subscription.txt`, `/clash.yaml`, `/raw.txt` - 直接文件访问

## 故障排除

### 1. 构建失败

```bash
# 检查 Bun 版本
bun --version  # 需要 >= 1.0

# 清理并重新安装依赖
cd frontend
rm -rf node_modules bun.lockb
bun install
```

### 2. API 请求失败

- 检查 API 服务是否运行
- 检查 CORS 配置
- 检查 Nginx 代理配置

### 3. 页面无法访问

- 检查 Nginx 配置是否正确
- 检查文件路径是否正确
- 查看 Nginx 错误日志

## 开发指南

### 添加新组件

1. 在 `src/components/` 下创建组件文件
2. 使用 Tailwind CSS 进行样式设计
3. 遵循现有的组件模式

### 添加新 API

1. 在 `src/lib/api.ts` 中添加 API 方法
2. 在 Dashboard 组件中使用
3. 添加错误处理

### 自定义样式

编辑 `src/styles/globals.css` 或使用 Tailwind 类名。

## 许可证

与主项目保持一致。
