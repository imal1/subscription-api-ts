---
name: config-patterns
description: MioBridge 配置约定和默认值
metadata:
  type: project
---

# 配置约定和默认值

## 配置来源

主配置文件：`~/.config/miobridge/config.yaml`

由 `YamlService` 在服务启动时通过 yq 解析，缺失时回退默认值。

## 配置结构

```yaml
app:
  name: miobridge           # 应用名称
  version: 1.1.0            # 从 package.json 读取
  port: 3001                # 服务端口
  environment: production   # development / production

protocols:
  sing_box_configs:         # sing-box 配置名称列表
    - vless
    - hysteria2
    - trojan
    - tuic
    - vmess

binaries:
  mihomo_path: ""           # 空则回退 ~/.config/miobridge/bin/mihomo
  bun_path: ""              # 空则回退 ~/.config/miobridge/bin/bun

directories:
  base_dir: ""              # 空则回退 ~/.config/miobridge
  data_dir: ""              # 空则回退 $base_dir/www
  log_dir: ""               # 空则回退 $base_dir/log
  backup_dir: ""            # 空则回退 $base_dir/backup
  dist_dir: ""              # 空则回退 $base_dir/dist

automation:
  auto_update_cron: "0 */2 * * *"   # 定时更新 cron 表达式，时区 Asia/Shanghai

logging:
  level: info               # error, warn, info, debug
```

## 默认值回退逻辑

所有路径类配置遵循：配置值 > 默认值（基于 `$base_dir`） > 硬编码回退

二进制文件查找顺序：
1. `config.yaml` 中指定的路径
2. `~/.config/miobridge/bin/<name>`
3. `process.cwd()/bin/<name>`
4. 系统 PATH

## 端口约定

| 端口 | 用途 |
|------|------|
| 3001 | Next.js 服务端口（`app.port`） |
| 3080 | Nginx 静态文件端口 |
| 3888 | Nginx 反代端口 |

## 环境变量覆盖

`PORT` 环境变量可覆盖 `app.port`（用于 systemd 注入）。
`NODE_ENV` 环境变量控制运行模式。
