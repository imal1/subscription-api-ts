# 环境变量配置指南

本文档列出了项目中所有支持的环境变量，确保所有配置都能正确从 `.env` 文件读取。

## 🚀 API 端点参考

| 端点 | 支持方法 | 功能描述 |
|------|----------|----------|
| `/api/update` | **GET** | 更新订阅文件 |
| `/api/configs` | GET, POST | 获取/更新配置列表 |
| `/api/status` | GET | 获取服务状态 |
| `/subscription.txt` | GET | 下载订阅文件 |
| `/clash.yaml` | GET | 下载Clash配置（文件名可通过CLASH_FILENAME配置） |
| `/health` | GET | 健康检查 |

⚠️ **重要**：`/api/update` 现在支持 GET 方法。详细的 API 使用说明请参考 [README.md](./README.md)

## 📋 环境变量清单

### 🚀 服务配置
- `PORT` - API服务监听端口 (默认: 3000)
- `NODE_ENV` - 运行环境 (默认: development)
- `SERVICE_NAME` - 服务名称，用于 systemd 和 PM2 (默认: subscription-api-ts)

### 🔧 Sing-box配置
- `SING_BOX_CONFIGS` - sing-box配置名称，逗号分隔 (默认: vless-reality,hysteria2,trojan,tuic,vmess)

### 🔄 Subconverter配置
- `SUBCONVERTER_URL` - subconverter服务地址 (默认: http://localhost:25500)
- `CLASH_FILENAME` - Clash配置文件名称，包含后缀 (默认: clash.yaml)

### 📁 文件路径配置
- `DATA_DIR` - 数据文件目录 (默认: ./data)
- `LOG_DIR` - 日志文件目录 (默认: ./logs)
- `BACKUP_DIR` - 备份文件目录 (默认: ./data/backup)

### ⏰ 定时任务配置
- `AUTO_UPDATE_CRON` - 自动更新cron表达式 (默认: 0 */2 * * *)

### 🌐 网络配置
- `NGINX_PORT` - Nginx服务端口 (默认: 3080)
- `MAX_RETRIES` - 最大重试次数 (默认: 3)
- `REQUEST_TIMEOUT` - 请求超时时间，毫秒 (默认: 30000)

### 🔒 CORS配置
- `CORS_ORIGIN` - 允许的跨域来源 (默认: *)

### 📝 日志配置
- `LOG_LEVEL` - 日志级别 (默认: info)

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
  -d '{"configs": ["vless-reality", "hysteria2"]}'
```

### 配置特性

- **动态更新**：API 更新的配置立即生效，无需重启
- **配置来源**：默认从环境变量 `SING_BOX_CONFIGS` 读取
- **持久性**：服务重启后恢复到环境变量默认值
- **格式验证**：配置名称必须是非空字符串数组

### 配置文件结构

```bash
.env                    # 主配置文件
.env.example           # 配置模板
config/                # 配置模板目录
├── nginx.conf.template
└── nginx.dev.conf.template
```

## 🔍 配置验证

### 自动检查
```bash
# 验证所有环境变量
./manage.sh overview

# 检查配置文件
npm run build
```

### 手动检查
```bash
# 搜索硬编码值
grep -r "3000\|3080\|25500" src/ --exclude-dir=node_modules

# 搜索硬编码路径  
grep -r "/var/www\|/var/log" src/ --exclude-dir=node_modules
```

## ✅ 已修复的文件

### TypeScript文件
- `src/config/index.ts` - 主配置文件 ✅
- `src/services/subconverterService.ts` - Subconverter服务 ✅
- `src/services/singBoxService.ts` - Sing-box服务 ✅
- `src/app.ts` - 应用配置 ✅
- `src/utils/logger.ts` - 日志配置 ✅

### JavaScript文件
- 已移除旧版本文件

### Python文件  
- 已移除旧版本文件

### 配置文件
- `config/nginx.conf.template` - Nginx生产环境模板 ✅
- `config/nginx.dev.conf.template` - Nginx开发环境模板 ✅

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
   npm run dev    # 开发模式
   npm start      # 生产模式
   ```

## 🔗 相关文档

- [故障排除指南](./TROUBLESHOOTING.md) - 详细的错误诊断和解决方案
- [项目结构说明](./PROJECT_STRUCTURE.md) - 项目文件组织
- [README.md](./README.md) - 项目概述和安装指南

所有配置通过环境变量统一管理，确保配置的一致性和灵活性！🎉
