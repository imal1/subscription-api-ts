# Scripts 目录说明

这个目录包含了 MioBridge 项目的所有管理脚本。

## 🎯 设计特点

- **📦 模块化设计**：将功能拆分为独立的函数库
- **🔧 统一管理**：一个脚本管理所有功能
- **💰 代码精简**：模块化的函数库设计
- **🚀 易于使用**：简单明了的命令行接口
- **🔄 向后兼容**：保持原有功能的同时提供更好的用户体验

## 📁 目录结构

```
scripts/
├── manage.sh           # 统一管理脚本（主要入口）
├── install.sh          # 快速安装脚本
├── README.md          # 说明文档
└── lib/               # 函数库目录
    ├── core.sh        # 核心工具函数
    ├── system.sh      # 系统检测和环境管理
    ├── config.sh      # 配置文件管理
    ├── service.sh     # 服务管理
    ├── install.sh     # 安装相关函数
    └── build.sh       # 构建相关函数
```

## 🚀 快速开始

### 完整安装
```bash
# 使用快速安装脚本
bash scripts/install.sh

# 或者使用管理脚本
bash scripts/manage.sh setup
```

### 日常使用
```bash
# 查看帮助
bash scripts/manage.sh help

# 构建项目
bash scripts/manage.sh build

# 服务管理 (Linux)
sudo bash scripts/manage.sh start
sudo bash scripts/manage.sh status
sudo bash scripts/manage.sh logs

# 系统检查
bash scripts/manage.sh check
```

## 📋 完整命令列表

### 环境管理
- `init` - 初始化项目环境
- `setup` - 完整安装配置
- `env` - 显示环境信息
- `config` - 显示配置信息

### 构建相关
- `build` - 构建项目（后端+前端）
- `build-backend` - 仅构建后端
- `build-frontend` - 仅构建前端
- `clean` - 清理构建文件

### 服务管理（仅 Linux）
- `start` - 启动服务
- `stop` - 停止服务
- `restart` - 重启服务
- `status` - 查看服务状态
- `logs` - 查看服务日志
- `logs-f` - 实时跟踪日志

### 维护工具
- `check` - 系统检查
- `verify` - 验证权限
- `update` - 更新项目（开发中）
- `backup` - 备份配置（开发中）

## 🔧 函数库说明

### core.sh - 核心工具函数
- 颜色定义和状态打印
- 基础文件/目录操作
- 版本信息管理
- 界面显示函数

### system.sh - 系统检测和环境管理
- 操作系统和架构检测
- 用户权限管理
- 环境变量设置
- 系统依赖检查

### config.sh - 配置文件管理
- YAML 配置文件解析
- yq 工具自动安装
- 配置文件创建和更新

### service.sh - 服务管理
- systemd 服务操作
- 服务状态检查
- 日志查看功能

### install.sh - 安装相关函数
- 二进制文件下载
- bun 和 mihomo 安装
- 文件权限设置

### build.sh - 构建相关函数
- 前端和后端构建
- 构建文件管理
- 依赖检查

## 🎨 使用示例

### 开发环境
```bash
# 初始化开发环境
bash scripts/manage.sh init

# 构建项目
bash scripts/manage.sh build

# 启动开发服务器
cd /path/to/project
bun run dev
```

### 生产环境 (Linux)
```bash
# 完整安装
sudo bash scripts/manage.sh setup

# 启动服务
sudo bash scripts/manage.sh start

# 查看状态
sudo bash scripts/manage.sh status

# 实时日志
sudo bash scripts/manage.sh logs-f
```

### 日常维护
```bash
# 系统检查
bash scripts/manage.sh check

# 权限验证
bash scripts/manage.sh verify

# 重新构建
bash scripts/manage.sh build

# 重启服务
sudo bash scripts/manage.sh restart
```

## 📝 注意事项

1. **权限要求**：某些操作需要 root 权限，使用 `sudo` 执行
2. **系统支持**：完全支持 Linux 和 macOS，服务管理功能仅适用于 Linux
3. **依赖检查**：脚本会自动检查和安装必要的依赖
4. **配置文件**：默认配置文件位于 `~/.config/miobridge/config.yaml`

## 🐛 故障排除

如果遇到问题，请依次尝试：

1. **检查系统环境**
   ```bash
   bash scripts/manage.sh check
   ```

2. **验证权限**
   ```bash
   bash scripts/manage.sh verify
   ```

3. **重新初始化**
   ```bash
   bash scripts/manage.sh init
   ```

4. **查看详细日志**
   ```bash
   bash scripts/manage.sh logs
   ```

## 📞 获取帮助

- 查看内置帮助：`bash scripts/manage.sh help`
- 查看系统状态：`bash scripts/manage.sh check`
- 查看环境信息：`bash scripts/manage.sh env`
