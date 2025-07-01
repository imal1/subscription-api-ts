# Monorepo 项目结构说明

## 项目改造说明

此项目已改造为 monorepo 结构，使用 npm workspaces 统一管理前端和后端依赖。

## 新的项目结构

```
subscription-api-ts/
├── package.json              # 根项目配置，管理所有依赖
├── src/                      # 后端源码
├── frontend/                 # 前端工作区
│   ├── package.json         # 前端项目配置（仅包含脚本）
│   └── src/                 # 前端源码
└── node_modules/            # 统一的依赖目录
    └── subscription-api-dashboard@ -> ../frontend
```

## 主要变化

### 1. 依赖管理
- **原来**: 前端和后端分别管理依赖
- **现在**: 根目录统一管理所有依赖

### 2. 安装流程
- **原来**: 需要分别在根目录和 frontend 目录执行 `npm install`
- **现在**: 只需在根目录执行 `npm install` 即可安装所有依赖

### 3. 构建流程
- **原来**: 需要分别构建后端和前端
- **现在**: 使用统一的构建脚本

## 新的脚本命令

### 根目录 package.json 新增脚本：

```json
{
  "scripts": {
    // 原有脚本保持不变
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node -r tsconfig-paths/register src/index.ts",
    
    // 新增的 monorepo 脚本
    "frontend:dev": "npm run dev --workspace=frontend",
    "frontend:build": "npm run build --workspace=frontend", 
    "frontend:start": "npm run start --workspace=frontend",
    "frontend:lint": "npm run lint --workspace=frontend",
    "dev:all": "concurrently \"npm run dev\" \"npm run frontend:dev\"",
    "build:all": "npm run build && npm run frontend:build",
    "setup": "npm install && npm run build:all"
  }
}
```

### 简化的前端 package.json：

```json
{
  "name": "subscription-api-dashboard",
  "version": "1.0.0", 
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "export": "next build",
    "lint": "next lint"
  }
  // 依赖已移至根目录
}
```

## 使用方法

### 开发环境

```bash
# 安装所有依赖
npm install

# 启动后端开发服务器
npm run dev

# 启动前端开发服务器
npm run frontend:dev

# 同时启动前端和后端
npm run dev:all
```

### 生产环境

```bash
# 构建所有项目
npm run build:all

# 启动后端服务
npm start

# 启动前端服务
npm run frontend:start
```

### 单独操作前端

```bash
# 构建前端
npm run frontend:build

# 启动前端开发
npm run frontend:dev

# 前端代码检查
npm run frontend:lint
```

## 安装脚本更新

### install.sh 脚本改进：
- 移除了单独安装前端依赖的步骤
- 使用 `npm run build:all` 统一构建
- 简化了权限设置流程

### update.sh 脚本改进：
- 使用 monorepo 方式安装依赖
- 统一构建前端和后端
- 简化了更新流程

## 优势

1. **依赖管理统一**: 避免重复安装相同依赖，减少 node_modules 大小
2. **版本一致性**: 确保前端和后端使用相同版本的共享依赖
3. **构建简化**: 一个命令构建整个项目
4. **开发效率**: 简化了开发环境搭建流程
5. **维护便捷**: 统一的依赖管理，减少版本冲突

## 注意事项

1. 现在只需要在根目录执行 `npm install`
2. 构建使用 `npm run build:all` 而不是分别构建
3. 前端依赖现在位于根目录的 node_modules 中
4. 删除了前端目录下的 node_modules 和 package-lock.json

## 迁移指导

如果你之前克隆了旧版本的项目，请按以下步骤迁移：

1. 拉取最新代码
2. 删除旧的依赖文件：
   ```bash
   rm -rf node_modules package-lock.json
   rm -rf frontend/node_modules frontend/package-lock.json
   ```
3. 重新安装依赖：
   ```bash
   npm install
   ```
4. 构建项目：
   ```bash
   npm run build:all
   ```

这样就完成了向 monorepo 结构的迁移！
