# 故障排除指南

使用 Subscription API TS 时常见问题的诊断和解决方案。

## 服务连接问题

### 服务无法访问

**症状**：`curl: (7) Failed to connect to localhost port 3001`

```bash
# 检查服务状态
sudo systemctl status subscription-api-ts

# 查看最近日志
sudo journalctl -u subscription-api-ts -n 50 --no-pager

# 检查端口
ss -tlnp | grep 3001
```

**解决**：
```bash
# 重启服务
sudo systemctl restart subscription-api-ts

# 如果启动失败，检查应用日志
tail -50 ~/.config/subscription/log/error.log
```

### 仪表盘状态显示"未生成"或"0 节点"

**症状**：仪表盘首次加载正常，但 30 秒后所有状态变为"未生成"、节点数变为 0。

**原因**：这是 v1.1.0 之前的一个 bug — 客户端轮询时未正确解析 API 响应。

**解决**：确保部署的是最新版本（≥ v1.1.0，commit `f387663` 或更新）。查看当前部署版本：

```bash
readlink ~/.config/subscription/dist
# 输出如：/root/.config/subscription/releases/20260624-162219-f387663
# commit hash 后缀应为 f387663 或更新
```

## 文件生成问题

### clash.yaml 不存在

**症状**：`GET /clash.yaml` 返回 404，"Clash 配置"卡片显示"未生成"。

**诊断**：
```bash
# 检查文件是否存在
ls -la ~/.config/subscription/www/clash.yaml

# 触发一次更新
curl -s http://127.0.0.1:3001/api/update | python3 -m json.tool
```

**常见原因**：

1. **yq 版本问题** — 需要 mikefarah/yq v4，`-o yaml` 参数
   ```bash
   ~/.config/subscription/bin/yq --version
   # 应为 yq (https://github.com/mikefarah/yq/) version v4.x
   ```

2. **mihomo 不可用**
   ```bash
   ~/.config/subscription/bin/mihomo -v
   # 应输出版本信息
   ```

3. **sing-box 配置不存在** — 检查 config.yaml 中的 `sing_box_configs` 列表是否与实际配置匹配
   ```bash
   sing-box info <config-name>
   ```

### subscription.txt 为空或只有少量节点

**症状**：更新成功但节点数很少。

```bash
# 查看 raw.txt 中的实际节点
cat ~/.config/subscription/www/raw.txt

# 查看更新日志
sudo journalctl -u subscription-api-ts --since "10 min ago" | grep "提取到有效代理URL\|URL获取完成"
```

**常见原因**：
- sing-box 中部分配置名称不存在（日志会显示 `配置 xxx 不存在`）
- 配置文件中的 `sing_box_configs` 与实际 sing-box 配置名不匹配

## 部署问题

### GitHub Actions 部署失败

**症状**：push 到 main 后部署 workflow 显示失败。

```bash
# 查看 workflow 运行日志
gh run list --limit 5
gh run view <run-id> --log
```

**常见原因和解决**：

| 错误 | 原因 | 解决 |
|------|------|------|
| `Permission denied (publickey)` | SSH key 问题 | 检查 `DEPLOY_SSH_KEY` secret |
| `sudo: a password is required` | NOPASSWD 未配置 | `sudo visudo -f /etc/sudoers.d/subscription-deploy` |
| `Host key verification failed` | known_hosts 缺失 | 更新 `DEPLOY_KNOWN_HOSTS` secret |
| 健康检查超时 | 服务未正常启动 | 服务器上 `journalctl -u subscription-api-ts -n 200` |

### 手动回滚

```bash
cd ~/.config/subscription
ls -lt releases/                              # 查看历史版本
ln -sfn releases/<旧版本目录名> dist           # 切换软链接
sudo systemctl restart subscription-api-ts    # 重启
```

## 日志查看

### 应用日志

```bash
# 综合日志
tail -f ~/.config/subscription/log/combined.log

# 错误日志
tail -f ~/.config/subscription/log/error.log

# 按关键词过滤
grep "订阅更新" ~/.config/subscription/log/combined.log
grep "ERROR" ~/.config/subscription/log/error.log
```

### 系统日志

```bash
# 最近 100 行
sudo journalctl -u subscription-api-ts -n 100 --no-pager

# 实时跟踪
sudo journalctl -u subscription-api-ts -f

# 按时间范围
sudo journalctl -u subscription-api-ts --since "1 hour ago"
```

### 开启调试日志

编辑 `~/.config/subscription/config.yaml`：

```yaml
logging:
  level: debug
```

然后重启服务：`sudo systemctl restart subscription-api-ts`

## 常见配置问题

### 端口被占用

```bash
# 查找占用端口的进程
ss -tlnp | grep <端口号>

# 更换端口 — 编辑 config.yaml
# app.port: 3002
sudo systemctl restart subscription-api-ts
```

### 权限问题

```bash
# 确保运行时目录权限正确
sudo chown -R $USER:$USER ~/.config/subscription/

# 确保二进制文件可执行
chmod +x ~/.config/subscription/bin/mihomo
chmod +x ~/.config/subscription/bin/yq
```

## API 端点测试

```bash
# 健康检查
curl http://localhost:3001/api/health

# 服务状态
curl http://localhost:3001/api/status | python3 -m json.tool

# 触发更新
curl http://localhost:3001/api/update

# 下载文件
curl -o clash.yaml http://localhost:3001/clash.yaml
curl -o subscription.txt http://localhost:3001/subscription.txt
```

## 获取帮助

1. 查看 [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) — 部署指南
2. 查看 [GitHub Issues](https://github.com/imal1/subscription-api-ts/issues)
3. 收集调试信息后提交 Issue：
   ```bash
   echo "=== 版本信息 ===" > debug.txt
   readlink ~/.config/subscription/dist >> debug.txt
   echo "=== 最近日志 ===" >> debug.txt
   tail -100 ~/.config/subscription/log/error.log >> debug.txt
   echo "=== 服务状态 ===" >> debug.txt
   sudo systemctl status subscription-api-ts >> debug.txt
   ```
