# 环境变量配置检查清单

本文档列出了项目中所有支持的环境变量，确保所有配置都能正确从 `.env` 文件读取。

## 📋 环境变量清单

### 🚀 服务配置
- `PORT` - API服务监听端口 (默认: 3000)
- `NODE_ENV` - 运行环境 (默认: development)

### 🔧 Sing-box配置
- `SING_BOX_CONFIGS` - sing-box配置名称，逗号分隔 (默认: vless-reality,hysteria2,trojan,tuic,vmess)

### 🔄 Subconverter配置
- `SUBCONVERTER_URL` - subconverter服务地址 (默认: http://localhost:25500)

### 📁 文件路径配置
- `STATIC_DIR` - 静态文件目录 (默认: ./data)
- `LOG_DIR` - 日志文件目录 (默认: ./logs)
- `BACKUP_DIR` - 备份文件目录 (默认: ./data/backup)

### ⏰ 定时任务配置
- `AUTO_UPDATE_CRON` - 自动更新cron表达式 (默认: 0 */2 * * *)

### 🌐 网络配置
- `NGINX_PORT` - Nginx服务端口 (默认: 8080)
- `MAX_RETRIES` - 最大重试次数 (默认: 3)
- `REQUEST_TIMEOUT` - 请求超时时间，毫秒 (默认: 30000)

### 🔒 CORS配置
- `CORS_ORIGIN` - 允许的跨域来源 (默认: *)

### 📝 日志配置
- `LOG_LEVEL` - 日志级别 (默认: info)

## ✅ 已修复的文件

### TypeScript文件
- `src/config/index.ts` - 主配置文件 ✅
- `src/services/subconverterService.ts` - Subconverter服务 ✅
- `src/services/singBoxService.ts` - Sing-box服务 ✅
- `src/app.ts` - 应用配置 ✅
- `src/utils/logger.ts` - 日志配置 ✅

### JavaScript文件
- `opt/subscription-api/app.js` - JavaScript版本API ✅
- `opt/subscription-api/gunicorn_config.py` - Gunicorn配置 ✅

### Python文件
- `opt/subscription-api/subscription_api.py` - Python版本API ✅

### 配置文件
- `config/nginx.conf.template` - Nginx生产环境模板 ✅
- `config/nginx.dev.conf.template` - Nginx开发环境模板 ✅
- `scripts/generate-nginx-config.sh` - Nginx配置生成脚本 ✅

## 🔍 检查方法

要验证所有环境变量都被正确读取，可以：

1. **搜索硬编码值**：
   ```bash
   # 搜索可能的硬编码端口
   grep -r "5000\|8080\|25500" src/ --exclude-dir=node_modules
   
   # 搜索硬编码路径
   grep -r "/var/www\|/var/log" src/ --exclude-dir=node_modules
   ```

2. **验证配置生成**：
   ```bash
   npm run nginx:config
   ```

3. **检查构建**：
   ```bash
   npm run build
   ```

## 📖 使用说明

1. 复制 `.env.example` 到 `.env`
2. 根据你的环境修改 `.env` 中的配置
3. 运行 `npm run nginx:config` 生成对应的nginx配置
4. 启动服务

所有配置现在都通过环境变量统一管理，确保了配置的一致性和灵活性！🎉
