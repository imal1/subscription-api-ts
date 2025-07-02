# 迁移指南：从 Subconverter 到 Mihomo

本文档详细说明如何从 v1.x (subconverter) 迁移到 v2.0.0+ (mihomo)。

## 📋 迁移概述

### 主要变化

| 项目 | v1.x (subconverter) | v2.0.0+ (mihomo) |
|------|-------------------|------------------|
| 转换内核 | subconverter 外部服务 | mihomo (clash-meta) 内置 |
| 协议支持 | 有限 (不支持 vless/hysteria2/tuic) | 完整 (支持所有新协议) |
| 外部依赖 | 需要 subconverter 服务 | 无外部依赖 |
| 配置管理 | 需要手动管理 subconverter | 自动下载和管理 mihomo |
| 性能 | 网络调用开销 | 本地处理，性能更好 |

### 为什么迁移？

1. **协议支持**: subconverter 不支持 vless、hysteria2、tuic 等新协议
2. **依赖简化**: 不再需要外部 subconverter 服务
3. **性能提升**: 本地处理，避免网络调用开销
4. **维护性**: mihomo 活跃维护，更新及时
5. **准确性**: 原生协议解析，转换更准确

## 🚀 迁移步骤

### 1. 备份现有配置

```bash
# 备份当前配置和数据
cp .env .env.backup
cp -r data data.backup
cp -r logs logs.backup
```

### 2. 停止现有服务

```bash
# 停止服务
./manage.sh stop

# 或者手动停止
sudo systemctl stop subscription-api-ts
```

### 3. 更新代码

```bash
# 拉取最新代码
git fetch origin
git checkout v2.0.0  # 或 main 分支

# 更新依赖
npm install
```

### 4. 更新配置文件

```bash
# 查看新的配置示例
cat .env.example

# 编辑配置文件
nano .env
```

**重要配置变更：**

```bash
# 删除 (不再需要)
# SUBCONVERTER_URL=http://localhost:25500

# 新增 (可选，留空则自动管理)
MIHOMO_PATH=

# 其他配置保持不变
PORT=3000
SING_BOX_CONFIGS=vless,hysteria2,trojan,tuic,vmess
DATA_DIR=./data
LOG_DIR=./logs
# ...
```

### 5. 构建和启动

```bash
# 构建项目
npm run build

# 构建前端 (如果使用)
npm run frontend:build

# 启动服务
./manage.sh start

# 或者手动启动
sudo systemctl start subscription-api-ts
```

### 6. 验证迁移

```bash
# 检查服务状态
./manage.sh status

# 测试 API
curl http://localhost:3000/api/status

# 检查 mihomo 状态
curl http://localhost:3000/api/diagnose/mihomo

# 测试协议转换
curl http://localhost:3000/api/test/protocols
```

## 🔧 配置说明

### 新的环境变量

```bash
# mihomo 二进制文件路径 (可选)
# 留空则自动下载到系统临时目录
MIHOMO_PATH=

# 示例：指定自定义路径
# MIHOMO_PATH=/opt/mihomo
```

### mihomo 自动管理

v2.0.0+ 会自动：

1. **检测 mihomo**: 检查本地是否已安装 mihomo
2. **下载 mihomo**: 如果不存在，自动从 GitHub 下载最新版本
3. **版本管理**: 自动选择适合当前系统的版本 (Linux/macOS/Windows + amd64/arm64)
4. **权限设置**: 自动设置执行权限
5. **验证功能**: 自动验证下载文件的完整性

## 📊 功能对比

### API 端点变更

| 功能 | v1.x 端点 | v2.0.0+ 端点 |
|------|-----------|--------------|
| 检查转换服务 | `/api/diagnose/subconverter` | `/api/diagnose/mihomo` |
| 服务状态 | `subconverterRunning` | `mihomoAvailable` |
| 版本信息 | `subconverterVersion` | `mihomoVersion` |

### 协议支持对比

| 协议 | v1.x 支持 | v2.0.0+ 支持 | 说明 |
|------|-----------|--------------|------|
| vmess | ✅ | ✅ | 完全支持 |
| vless | ❌ | ✅ | **新支持** |
| trojan | ✅ | ✅ | 完全支持 |
| shadowsocks | ✅ | ✅ | 完全支持 |
| hysteria2 | ❌ | ✅ | **新支持** |
| tuic | ❌ | ✅ | **新支持** |
| wireguard | ❌ | ✅ | **新支持** |

## 🛠️ 故障排除

### 常见问题

#### 1. mihomo 下载失败

```bash
# 检查网络连接
curl -I https://api.github.com/repos/MetaCubeX/mihomo/releases/latest

# 手动下载 mihomo
mkdir -p /tmp/mihomo
cd /tmp/mihomo
# 根据系统下载对应版本
wget https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-amd64
chmod +x mihomo-linux-amd64

# 设置环境变量
echo "MIHOMO_PATH=/tmp/mihomo" >> .env
```

#### 2. 协议转换失败

```bash
# 检查 mihomo 状态
curl http://localhost:3000/api/diagnose/mihomo

# 测试单个协议
curl -X POST http://localhost:3000/api/test/single-node \
  -H "Content-Type: application/json" \
  -d '{"content": "vless://uuid@server:port?encryption=none&security=tls#name"}'
```

#### 3. 权限问题

```bash
# 检查 mihomo 文件权限
ls -la $MIHOMO_PATH/mihomo*

# 修复权限
chmod +x $MIHOMO_PATH/mihomo*
```

#### 4. 配置验证失败

```bash
# 检查配置文件格式
./manage.sh diagnose

# 重新生成配置
curl http://localhost:3000/api/update
```

## 📝 迁移检查清单

- [ ] 备份现有配置和数据
- [ ] 停止现有服务
- [ ] 更新代码到 v2.0.0+
- [ ] 更新 .env 配置文件
- [ ] 删除 SUBCONVERTER_URL 配置
- [ ] 添加 MIHOMO_PATH 配置 (可选)
- [ ] 重新构建项目
- [ ] 启动新服务
- [ ] 验证 API 状态
- [ ] 测试协议转换
- [ ] 检查前端功能
- [ ] 更新监控和告警
- [ ] 清理旧的 subconverter 服务

## 🔄 回滚步骤

如果迁移出现问题，可以回滚到 v1.x：

```bash
# 停止服务
./manage.sh stop

# 回滚代码
git checkout v1.x

# 恢复配置
cp .env.backup .env

# 重新安装依赖
npm install

# 重新构建
npm run build

# 启动服务
./manage.sh start
```

## 💡 最佳实践

1. **测试环境先行**: 在测试环境完成迁移验证后再在生产环境操作
2. **逐步迁移**: 可以并行运行两个版本，逐步切换流量
3. **监控告警**: 迁移后密切监控服务状态和错误日志
4. **性能对比**: 对比迁移前后的性能指标
5. **用户通知**: 提前通知用户可能的服务中断

## 📞 获取帮助

如果迁移过程中遇到问题：

1. 查看 [故障排除文档](./TROUBLESHOOTING.md)
2. 检查 [GitHub Issues](https://github.com/imal1/subscription-api-ts/issues)
3. 提交新的 Issue 并包含详细的错误信息
4. 查看服务日志：`tail -f logs/app.log`

---

**迁移完成后，您将享受到更好的性能、更多的协议支持和更简单的维护体验！** 🎉
