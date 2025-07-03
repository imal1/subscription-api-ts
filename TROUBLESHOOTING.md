# 故障排除指南

详细的错误诊断和解决方案，帮助快速解决使用 Subscription API TypeScript 时遇到的问题。

## 🚨 API 端点使用

### `/api/update` 端点说明

**重要更新：`/api/update` 现在支持 GET 方法！**

**使用方法：**
```bash
# ✅ 现在这些方法都是正确的
curl http://localhost:3000/api/update                    # 默认GET
curl -X GET http://localhost:3000/api/update            # 明确GET
wget http://localhost:3000/api/update                   # wget默认GET
# 浏览器直接访问也可以正常工作
```

**成功响应示例：**
```json
{
  "success": true,
  "data": {
    "message": "订阅更新成功，共 5 个节点",
    "timestamp": "2025-06-26T10:30:00.000Z",
    "nodesCount": 5,
    "clashGenerated": true,
    "backupCreated": "/app/data/backup/subscription_2025-06-26T10-30-00.txt"
  },
  "message": "订阅更新成功",
  "timestamp": "2025-06-26T10:30:00.000Z"
}
```

### 常见问题解决

如果您仍然遇到 "端点不存在" 错误，可能的原因：

1. **服务未启动**
   ```bash
   ./manage.sh status
   ./manage.sh start
   ```

2. **端口配置错误**
   ```bash
   # 检查端口配置
   grep PORT .env
   # 确保使用正确的端口
   curl http://localhost:3000/api/update
   ```

3. **路径错误**
   ```bash
   # 确保路径正确（注意 /api/update 而不是 /update）
   curl http://localhost:3000/api/update
   ```

## 🔌 服务连接问题

### 1. 服务连接失败

**错误信息：**
```bash
curl: (7) Failed to connect to localhost port 3000: Connection refused
```

**诊断步骤：**
```bash
# 1. 检查服务状态
./manage.sh status

# 2. 检查端口占用
lsof -i :3000
netstat -tlnp | grep :3000

# 3. 查看进程
ps aux | grep subscription-api
pgrep -f "node.*dist/index.js"
```

**解决方案：**
```bash
# 启动服务
./manage.sh start

# 如果启动失败，查看日志
./manage.sh logs

# 手动启动（调试模式）
bun run dev
```

### 3. Subconverter 服务不可用

**错误信息：**
```json
{
  "success": false,
  "error": "Subconverter服务未运行或不可访问"
}
```

**诊断步骤：**
```bash
# 检查 subconverter 服务状态
sudo systemctl status subconverter

# 测试连接
curl http://localhost:25500/sub
curl http://localhost:25500/version
```

**解决方案：**
```bash
# 启动 subconverter 服务
sudo systemctl start subconverter
sudo systemctl enable subconverter

# 检查配置
grep SUBCONVERTER_URL .env

# 手动启动 subconverter（如果服务不存在）
# 参考 subconverter 官方文档
```

## ⚙️ 配置和文件问题

### 4. 配置文件错误

**错误信息：**
```json
{
  "success": false,
  "error": "配置文件不存在或格式错误"
}
```

**诊断步骤：**
```bash
# 检查配置文件
ls -la .env .env.example
cat .env | grep -E "^[A-Z]"

# 检查必要目录
ls -la data/ logs/ config/
```

**解决方案：**
```bash
# 重新生成配置
cp .env.example .env
nano .env  # 编辑配置

# 创建必要目录
mkdir -p data logs data/backup

# 验证配置
./manage.sh overview
```

### 5. 权限问题

**错误信息：**
```bash
EACCES: permission denied, mkdir '$HOME/.config/.subscription/log'
EACCES: permission denied, open '/var/run/subscription-api.pid'
```

**解决方案：**
```bash
# 检查文件权限
ls -la $HOME/.config/.subscription/ /var/run/

# 修改权限
sudo chown -R $USER:$USER $HOME/.config/.subscription/
sudo chown -R $USER:$USER /var/run/subscription-api.pid

# 或使用 sudo 运行
sudo ./manage.sh install
sudo ./manage.sh start
```

### 6. 端口占用问题

**错误信息：**
```bash
Error: listen EADDRINUSE :::3000
```

**诊断步骤：**
```bash
# 查找占用端口的进程
lsof -i :3000
netstat -tlnp | grep :3000
ss -tlnp | grep :3000
```

**解决方案：**
```bash
# 方案1：更换端口
echo "PORT=3001" >> .env
./manage.sh restart

# 方案2：停止占用进程
kill $(lsof -ti:3000)

# 方案3：强制停止
sudo pkill -f "node.*3000"
```

## 🔍 诊断工具和命令

### 快速诊断
```bash
# 全面系统检查
./manage.sh status
./manage.sh overview

# API 端点测试
./test-api-endpoints.sh

# 查看实时日志
./manage.sh logs
tail -f logs/combined.log logs/error.log
```

### 手动测试步骤

#### 基础连通性测试
```bash
# 1. 服务健康检查
curl -v http://localhost:3000/health

# 2. API 文档
curl -s http://localhost:3000/ | jq .

# 3. 服务状态
curl -s http://localhost:3000/api/status | jq .
```

#### API 功能测试
```bash
# 1. 配置管理
curl -s http://localhost:3000/api/configs | jq .

# 2. 订阅更新（正确方法）
curl http://localhost:3000/api/update -v

# 3. 文件下载
curl -I http://localhost:3000/subscription.txt
curl -I http://localhost:3000/clash.yaml
```

#### 依赖服务测试
```bash
# 1. Subconverter 连通性
curl -v http://localhost:25500/sub

# 2. Nginx 状态（如果使用）
curl -v http://localhost:3080/health

# 3. 系统服务状态
sudo systemctl status subscription-api-ts
sudo systemctl status subconverter
```

### 深度调试

#### 启用详细日志
```bash
# 临时启用调试模式
NODE_ENV=development LOG_LEVEL=debug bun run dev

# 或修改 .env 文件
echo "LOG_LEVEL=debug" >> .env
./manage.sh restart
```

#### 网络调试
```bash
# 检查网络连接
ping localhost
telnet localhost 3000
nc -zv localhost 3000

# 检查防火墙
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # CentOS/RHEL
```

#### 系统资源检查
```bash
# 内存使用
free -h
ps aux --sort=-%mem | head

# 磁盘空间
df -h
du -sh logs/ data/

# 系统负载
uptime
top -p $(pgrep -f subscription-api)
```

## 📊 日志分析

### 日志位置
```bash
$BASE_DIR/log/combined.log    # 综合日志 (默认: $HOME/.config/.subscription/log/)
$BASE_DIR/log/error.log       # 错误日志
$BASE_DIR/log/nginx-*.log     # Nginx 日志（如果使用）
```

### 常用日志命令
```bash
# 查看最近错误
tail -50 $BASE_DIR/log/error.log

# 实时监控
tail -f logs/combined.log | grep ERROR

# 搜索特定错误
grep -i "端点不存在" logs/combined.log
grep -i "ECONNREFUSED" logs/error.log

# 分析访问模式
awk '{print $1}' logs/combined.log | sort | uniq -c | sort -nr
```

## 🆘 问题报告

如果上述方法都无法解决问题，请收集以下信息：

### 系统信息收集
```bash
# 基本信息
./manage.sh overview > debug-info.txt
./manage.sh status >> debug-info.txt

# 详细日志
tail -100 logs/combined.log >> debug-info.txt
tail -100 logs/error.log >> debug-info.txt

# 系统环境
node --version >> debug-info.txt
bun --version >> debug-info.txt
cat .env >> debug-info.txt

# 网络状态
netstat -tlnp | grep -E ":300[0-9]" >> debug-info.txt
```

### API测试结果
```bash
# 运行完整测试
./test-api-endpoints.sh > api-test-results.txt 2>&1
```

将 `debug-info.txt` 和 `api-test-results.txt` 提供给技术支持可以帮助快速定位问题。

## 🔗 相关资源

- [环境变量配置](./ENVIRONMENT_VARIABLES.md) - 配置说明和环境变量
- [项目结构](./PROJECT_STRUCTURE.md) - 文件组织和架构
- [API 使用帮助](./manage.sh) - 运行 `./manage.sh api-help` 查看详细 API 说明

## 🔍 诊断工具

### 快速诊断
```bash
# 运行完整的系统诊断
./manage.sh status

# 查看详细的项目状态
./manage.sh overview

# 测试所有 API 端点
./test-api-endpoints.sh
```

### 手动测试步骤

1. **测试服务是否运行：**
   ```bash
   curl http://localhost:3000/health
   ```

2. **测试API文档：**
   ```bash
   curl http://localhost:3000/
   ```

3. **测试配置获取：**
   ```bash
   curl http://localhost:3000/api/configs
   ```

4. **测试更新订阅（正确方法）：**
   ```bash
   curl http://localhost:3000/api/update
   ```

5. **检查生成的文件：**
   ```bash
   ls -la data/
   curl http://localhost:3000/subscription.txt
   ```

## 📝 调试技巧

### 查看实时日志
```bash
# 查看应用日志
./manage.sh logs

# 查看系统服务日志
sudo journalctl -u subscription-api-ts -f

# 查看 nginx 日志
tail -f $BASE_DIR/log/nginx-error.log
```

### 检查网络连接
```bash
# 检查端口监听
netstat -tlnp | grep :3000

# 检查防火墙
sudo ufw status

# 测试本地连接
telnet localhost 3000
```

## 🆘 获取帮助

如果上述解决方案都无法解决您的问题：

1. **查看详细日志：**
   ```bash
   ./manage.sh logs | tail -50
   ```

2. **收集系统信息：**
   ```bash
   ./manage.sh overview > debug-info.txt
   ./manage.sh status >> debug-info.txt
   ```

3. **运行测试脚本：**
   ```bash
   ./test-api-endpoints.sh > api-test-results.txt 2>&1
   ```

4. **检查依赖服务：**
   ```bash
   # 检查 Bun 版本
   bun --version
   
   # 检查系统服务
   sudo systemctl status subconverter
   sudo systemctl status nginx
   ```

将这些信息一起提供可以帮助快速诊断问题。
