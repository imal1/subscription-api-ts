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