#!/bin/bash

# Subscription API TypeScript 管理脚本
# 功能：提供项目管理、诊断、部署等功能的统一入口
# 作者：subscription-api-ts 项目组
# 版本：1.0.0

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# 引入公共函数库
source "$SCRIPTS_DIR/common.sh"

# 显示帮助信息
show_help() {
    show_header "Subscription API TypeScript 管理工具"
    echo -e "${WHITE}使用方法:${NC}"
    echo -e "  ${CYAN}./manage.sh [命令]${NC}"
    echo ""
    echo -e "${WHITE}🚀 核心管理命令:${NC}"
    echo -e "  ${GREEN}install${NC}          完整项目安装和配置"
    echo -e "  ${GREEN}update${NC}           更新代码并重启服务"
    echo -e "  ${GREEN}start${NC}            启动服务"
    echo -e "  ${GREEN}stop${NC}             停止服务"
    echo -e "  ${GREEN}restart${NC}          重启服务"
    echo -e "  ${GREEN}status${NC}           查看服务状态（快速检查）"
    echo -e "  ${GREEN}check${NC}            全面服务状态检测"
    echo ""
    echo -e "${WHITE}🔧 开发工具:${NC}"
    echo -e "  ${BLUE}build${NC}            编译 TypeScript 项目"
    echo -e "  ${BLUE}build-frontend${NC}   构建前端 Dashboard"
    echo -e "  ${BLUE}dev${NC}              启动开发模式"
    echo -e "  ${BLUE}test${NC}             运行测试"
    echo -e "  ${BLUE}clean${NC}            清理编译文件"
    echo ""
    echo -e "${WHITE}🛠️ 诊断修复:${NC}"
    echo -e "  ${YELLOW}deploy${NC}           部署项目"
    echo -e "  ${YELLOW}check${NC}            全面服务状态检测"
    echo ""
    echo -e "${WHITE}📋 信息查看:${NC}"
    echo -e "  ${CYAN}logs${NC}             查看服务日志"
    echo -e "  ${CYAN}version${NC}          显示版本信息"
    echo -e "  ${CYAN}overview${NC}         项目状态概览"
    echo -e "  ${CYAN}api-help${NC}         API 端点使用说明"
    echo -e "  ${CYAN}help${NC}             显示此帮助信息"
    echo ""
    echo -e "${WHITE}💡 示例:${NC}"
    echo -e "  ${CYAN}./manage.sh install${NC}         # 完整安装项目"
    echo -e "  ${CYAN}./manage.sh deploy${NC}          # 部署项目"
    echo -e "  ${CYAN}./manage.sh status${NC}          # 快速检查服务状态"
    echo -e "  ${CYAN}./manage.sh overview${NC}        # 查看项目概览"
    echo -e "  ${CYAN}./manage.sh api-help${NC}        # 查看 API 使用说明"
    echo ""
}

# 检查脚本文件是否存在
check_script() {
    local script_name="$1"
    if [ ! -f "$SCRIPTS_DIR/$script_name" ]; then
        echo -e "${RED}❌ 脚本文件不存在: $SCRIPTS_DIR/$script_name${NC}"
        return 1
    fi
    if [ ! -x "$SCRIPTS_DIR/$script_name" ]; then
        echo -e "${YELLOW}⚠️  脚本无执行权限，自动添加权限...${NC}"
        chmod +x "$SCRIPTS_DIR/$script_name"
    fi
    return 0
}

# 执行脚本
run_script() {
    local script_name="$1"
    shift
    if check_script "$script_name"; then
        echo -e "${GREEN}🚀 执行: $script_name${NC}"
        echo ""
        bash "$SCRIPTS_DIR/$script_name" "$@"
    else
        exit 1
    fi
}

# 检测操作系统
get_os() {
    detect_os
}

# 服务管理
manage_service() {
    local action="$1"
    local os=$(get_os)
    
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        case "$action" in
            "start")
                echo -e "${GREEN}🚀 启动服务: $service_name${NC}"
                safe_sudo systemctl start "$service_name"
                safe_sudo systemctl status "$service_name" --no-pager -l
                ;;
            "stop")
                echo -e "${YELLOW}⏹️  停止服务: $service_name${NC}"
                safe_sudo systemctl stop "$service_name"
                ;;
            "restart")
                echo -e "${BLUE}🔄 重启服务: $service_name${NC}"
                safe_sudo systemctl restart "$service_name"
                safe_sudo systemctl status "$service_name" --no-pager -l
                ;;
        esac
    elif [ "$os" = "Mac" ]; then
        case "$action" in
            "start")
                echo -e "${GREEN}🚀 启动服务 (macOS)${NC}"
                if command -v pm2 >/dev/null 2>&1; then
                    pm2 start dist/index.js --name subscription-api-ts
                    pm2 status
                else
                    echo -e "${YELLOW}💡 使用 bun start 启动服务，或安装 PM2: bun add -g pm2${NC}"
                    BUN_CMD=$(detect_bun)
                    if [ -n "$BUN_CMD" ]; then
                        "$BUN_CMD" start &
                    else
                        echo -e "${RED}❌ 未找到 bun，请先运行 bash scripts/install.sh${NC}"
                        exit 1
                    fi
                fi
                ;;
            "stop")
                echo -e "${YELLOW}⏹️  停止服务 (macOS)${NC}"
                if command -v pm2 >/dev/null 2>&1; then
                    pm2 stop subscription-api-ts
                else
                    pkill -f "node.*dist/index.js"
                fi
                ;;
            "restart")
                echo -e "${BLUE}🔄 重启服务 (macOS)${NC}"
                if command -v pm2 >/dev/null 2>&1; then
                    pm2 restart subscription-api-ts
                else
                    pkill -f "bun.*dist/index.js"
                    sleep 1
                    BUN_CMD=$(detect_bun)
                    if [ -n "$BUN_CMD" ]; then
                        "$BUN_CMD" start &
                    else
                        echo -e "${RED}❌ 未找到 bun${NC}"
                        exit 1
                    fi
                fi
                ;;
        esac
    fi
}

# 查看日志
show_logs() {
    local os=$(get_os)
    
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        echo -e "${CYAN}📝 查看服务日志 (最新 50 条):${NC}"
        safe_sudo journalctl -u "$service_name" -n 50 --no-pager
        echo ""
        if [[ $EUID -eq 0 ]]; then
            echo -e "${WHITE}💡 实时查看日志: journalctl -u $service_name -f${NC}"
        else
            if [ "$HAS_SUDO" = true ]; then
                echo -e "${WHITE}💡 实时查看日志: sudo journalctl -u $service_name -f${NC}"
            else
                echo -e "${WHITE}💡 实时查看日志: journalctl -u $service_name -f (需要root权限)${NC}"
            fi
        fi
    elif [ "$os" = "Mac" ]; then
        if [ -f "logs/combined.log" ]; then
            echo -e "${CYAN}📝 查看应用日志:${NC}"
            tail -50 logs/combined.log
        elif command -v pm2 >/dev/null 2>&1; then
            echo -e "${CYAN}📝 查看 PM2 日志:${NC}"
            pm2 logs subscription-api-ts --lines 50
        else
            echo -e "${YELLOW}⚠️  未找到日志文件${NC}"
        fi
    fi
}

# 版本信息
show_version() {
    echo -e "${WHITE}📦 版本信息${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    if [ -f "package.json" ]; then
        local name=$(jq -r '.name // "unknown"' package.json 2>/dev/null || grep '"name"' package.json | cut -d'"' -f4)
        local version=$(jq -r '.version // "unknown"' package.json 2>/dev/null || grep '"version"' package.json | cut -d'"' -f4)
        local description=$(jq -r '.description // ""' package.json 2>/dev/null || grep '"description"' package.json | cut -d'"' -f4)
        
        echo -e "${WHITE}项目名称:${NC} ${GREEN}$name${NC}"
        echo -e "${WHITE}版本:${NC} ${GREEN}$version${NC}"
        if [ -n "$description" ] && [ "$description" != "null" ]; then
            echo -e "${WHITE}描述:${NC} $description"
        fi
    fi
    
    echo ""
    echo -e "${WHITE}运行环境:${NC}"
    if command -v node >/dev/null 2>&1; then
        echo -e "  Node.js: ${GREEN}$(node --version)${NC}"
    fi
    if command -v bun >/dev/null 2>&1; then
        echo -e "  bun: ${GREEN}$(bun --version)${NC}"
    fi
    echo -e "  操作系统: ${GREEN}$(detect_os)${NC}"
    echo -e "  用户: ${GREEN}$(whoami)${NC}"
}

# 显示 API 使用帮助
show_api_help() {
    echo -e "${WHITE}📖 API 端点使用说明${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
    
    # 读取端口配置
    local port="3000"
    local external_host="localhost"
    
    # 尝试从 config.yaml 读取配置
    if [ -f "config.yaml" ]; then
        if command -v yq >/dev/null 2>&1; then
            port=$(yq eval '.server.port' config.yaml 2>/dev/null || echo "3000")
            external_host=$(yq eval '.server.external_host' config.yaml 2>/dev/null || echo "localhost")
        fi
    fi
    
    echo -e "${WHITE}🌐 基础信息:${NC}"
    echo -e "  Base URL: ${GREEN}http://${external_host}:${port}${NC}"
    echo -e "  Content-Type: ${GREEN}application/json${NC}"
    echo ""
    
    echo -e "${WHITE}📋 可用端点:${NC}"
    echo -e "${CYAN}┌─────────┬──────────────────┬────────────────────┬────────────────────┐${NC}"
    echo -e "${CYAN}│${WHITE} 方法    ${CYAN}│${WHITE} 端点             ${CYAN}│${WHITE} 描述               ${CYAN}│${WHITE} 注意事项           ${CYAN}│${NC}"
    echo -e "${CYAN}├─────────┼──────────────────┼────────────────────┼────────────────────┤${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /                ${CYAN}│${WHITE} API文档            ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /health          ${CYAN}│${WHITE} 健康检查           ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /api/update      ${CYAN}│${WHITE} 更新订阅           ${CYAN}│${GREEN} ✅ 支持GET方法     ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /api/status      ${CYAN}│${WHITE} 获取状态           ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /api/configs     ${CYAN}│${WHITE} 获取配置列表       ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${BLUE} POST    ${CYAN}│${WHITE} /api/configs     ${CYAN}│${WHITE} 更新配置列表       ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /subscription.txt${CYAN}│${WHITE} 获取订阅文件       ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /clash.yaml      ${CYAN}│${WHITE} 获取Clash配置      ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}│${GREEN} GET     ${CYAN}│${WHITE} /raw.txt         ${CYAN}│${WHITE} 获取原始链接       ${CYAN}│${WHITE}                    ${CYAN}│${NC}"
    echo -e "${CYAN}└─────────┴──────────────────┴────────────────────┴────────────────────┘${NC}"
    echo ""
    
    echo -e "${GREEN}✅ 更新说明:${NC}"
    echo -e "  ${GREEN}/api/update 端点现在支持 GET 方法！${NC}"
    echo -e "  可以通过简单的 GET 请求更新订阅。"
    echo ""
    
    echo -e "${WHITE}✅ 正确用法示例:${NC}"
    echo -e "${GREEN}  # 更新订阅（现在支持GET方法）${NC}"
    echo -e "  curl http://${external_host}:${port}/api/update"
    echo -e "  curl -X GET http://${external_host}:${port}/api/update"
    echo -e "  wget http://${external_host}:${port}/api/update"
    echo -e "  # 也可以直接在浏览器中访问"
    echo ""
    echo -e "${GREEN}  # 获取状态${NC}"
    echo -e "  curl http://${external_host}:${port}/api/status"
    echo ""
    echo -e "${GREEN}  # 获取配置列表${NC}"
    echo -e "  curl http://${external_host}:${port}/api/configs"
    echo ""
    echo -e "${GREEN}  # 健康检查${NC}"
    echo -e "  curl http://${external_host}:${port}/health"
    echo ""
    
    echo -e "${WHITE}🎉 优势:${NC}"
    echo -e "  ${GREEN}更简单${NC}     - 不需要指定 POST 方法"
    echo -e "  ${GREEN}更直观${NC}     - 可以直接在浏览器中访问"
    echo -e "  ${GREEN}更通用${NC}     - 支持 wget、curl 等多种工具"
    echo ""
    
    echo -e "${WHITE}🧪 测试工具:${NC}"
    echo -e "  运行完整的端点测试: ${CYAN}./test-api-endpoints.sh${NC}"
    echo -e "  查看故障排除指南: ${CYAN}cat TROUBLESHOOTING.md${NC}"
}

# 项目概览
show_project_overview() {
    echo -e "${WHITE}📊 项目概览${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    # 基本信息
    if [ -f "package.json" ]; then
        local name=$(grep '"name"' package.json | cut -d'"' -f4)
        local version=$(grep '"version"' package.json | cut -d'"' -f4)
        echo -e "${WHITE}项目:${NC} ${GREEN}$name${NC} v${version}"
    fi
    
    local os=$(get_os)
    echo -e "${WHITE}环境:${NC} ${GREEN}$os${NC}"
    
    # 编译状态
    if [ -f "dist/index.js" ]; then
        echo -e "${WHITE}编译:${NC} ${GREEN}✅ 已编译${NC}"
    else
        echo -e "${WHITE}编译:${NC} ${RED}❌ 未编译${NC}"
    fi
    
    # 依赖状态
    if [ -d "node_modules" ]; then
        echo -e "${WHITE}依赖:${NC} ${GREEN}✅ 已安装${NC}"
    else
        echo -e "${WHITE}依赖:${NC} ${RED}❌ 未安装${NC}"
    fi
    
    # 服务状态
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            echo -e "${WHITE}服务:${NC} ${GREEN}✅ 运行中${NC}"
        else
            echo -e "${WHITE}服务:${NC} ${RED}❌ 停止${NC}"
        fi
    elif [ "$os" = "Mac" ]; then
        if pgrep -f "node.*dist/index.js" >/dev/null 2>&1; then
            echo -e "${WHITE}服务:${NC} ${GREEN}✅ 运行中${NC}"
        else
            echo -e "${WHITE}服务:${NC} ${RED}❌ 停止${NC}"
        fi
    fi
    
    # 端口状态
    local port="${PORT:-3000}"
    if [ "$os" = "Linux" ]; then
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            echo -e "${WHITE}端口:${NC} ${GREEN}✅ $port 占用${NC}"
        else
            echo -e "${WHITE}端口:${NC} ${RED}❌ $port 空闲${NC}"
        fi
    elif [ "$os" = "Mac" ]; then
        if lsof -i tcp:$port >/dev/null 2>&1; then
            echo -e "${WHITE}端口:${NC} ${GREEN}✅ $port 占用${NC}"
        else
            echo -e "${WHITE}端口:${NC} ${RED}❌ $port 空闲${NC}"
        fi
    fi
    
    # 配置文件
    if [ -f "config.yaml" ]; then
        echo -e "${WHITE}配置:${NC} ${GREEN}✅ config.yaml 存在${NC}"
    else
        echo -e "${WHITE}配置:${NC} ${RED}❌ config.yaml 缺失${NC}"
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}💡 快速操作:${NC}"
    echo -e "  ${CYAN}./manage.sh status${NC}  - 快速状态检查"
    echo -e "  ${CYAN}./manage.sh check${NC}   - 详细诊断"
    echo -e "  ${CYAN}./manage.sh start${NC}   - 启动服务"
}

# 显示服务状态
show_service_status() {
    local os=$(get_os)
    
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        echo -e "${CYAN}📊 检查服务状态: $service_name${NC}"
        
        if systemctl is-active --quiet "$service_name"; then
            echo -e "  状态: ${GREEN}✅ 运行中${NC}"
            echo -e "  详细状态: $(systemctl is-active "$service_name")"
            
            # 显示端口信息
            local port="3000"
            local external_host="localhost"
            
            # 尝试从 config.yaml 读取配置
            if [ -f "config.yaml" ]; then
                if command -v yq >/dev/null 2>&1; then
                    port=$(yq eval '.server.port' config.yaml 2>/dev/null || echo "3000")
                    external_host=$(yq eval '.server.external_host' config.yaml 2>/dev/null || echo "localhost")
                fi
            fi
            echo -e "  访问地址: ${BLUE}http://${external_host}:${port}${NC}"
            
            # 检查端口是否被监听
            if command -v netstat >/dev/null 2>&1; then
                if netstat -ln | grep -q ":${port} "; then
                    echo -e "  端口 ${port}: ${GREEN}✅ 监听中${NC}"
                else
                    echo -e "  端口 ${port}: ${YELLOW}⚠️  未监听${NC}"
                fi
            fi
        else
            echo -e "  状态: ${RED}❌ 未运行${NC}"
            echo -e "  建议: 运行 ${WHITE}./manage.sh start${NC} 启动服务"
        fi
    elif [ "$os" = "Mac" ]; then
        echo -e "${CYAN}📊 检查服务状态 (macOS)${NC}"
        
        if command -v pm2 >/dev/null 2>&1; then
            if pm2 list | grep -q "subscription-api-ts"; then
                echo -e "  PM2 状态: ${GREEN}✅ 运行中${NC}"
                pm2 status subscription-api-ts
            else
                echo -e "  PM2 状态: ${YELLOW}⚠️  未在 PM2 中运行${NC}"
            fi
        fi
        
        # 检查进程
        if pgrep -f "node.*dist/index.js" >/dev/null; then
            echo -e "  进程状态: ${GREEN}✅ 运行中${NC}"
        else
            echo -e "  进程状态: ${RED}❌ 未运行${NC}"
            echo -e "  建议: 运行 ${WHITE}./manage.sh start${NC} 启动服务"
        fi
    fi
}

# 更新服务
run_update_service() {
    echo -e "${PURPLE}🚀 开始更新 Subscription API...${NC}"
    echo ""
    
    # 调用专门的更新脚本
    run_script "update.sh" "$@"
}

# 主逻辑
main() {
    # 如果没有参数，显示帮助
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        # 核心管理命令
        "install")
            run_script "install.sh" "$@"
            ;;
        "update")
            run_update_service
            ;;
        "deploy")
            run_script "deploy.sh" "$@"
            ;;
        "check")
            show_service_status
            ;;
        "start")
            manage_service "start"
            ;;
        "stop")
            manage_service "stop"
            ;;
        "restart")
            manage_service "restart"
            ;;
        "status")
            show_service_status
            ;;
            
        # 开发工具
        "build")
            echo -e "${BLUE}🏗️  编译项目...${NC}"
            BUN_CMD=$(detect_bun)
            if [ -n "$BUN_CMD" ]; then
                "$BUN_CMD" run build
            else
                echo -e "${RED}❌ 未找到 bun，请先运行 ./manage.sh install${NC}"
                exit 1
            fi
            ;;
        "build-frontend")
            echo -e "${BLUE}🎨 构建前端 Dashboard...${NC}"
            if [ -f "scripts/build-frontend.sh" ]; then
                bash scripts/build-frontend.sh
            else
                echo -e "${RED}❌ 前端构建脚本不存在${NC}"
                exit 1
            fi
            ;;
        "dev")
            echo -e "${BLUE}🚀 启动开发模式...${NC}"
            BUN_CMD=$(detect_bun)
            if [ -n "$BUN_CMD" ]; then
                "$BUN_CMD" run dev
            else
                echo -e "${RED}❌ 未找到 bun，请先运行 ./manage.sh install${NC}"
                exit 1
            fi
            ;;
        "test")
            echo -e "${BLUE}🧪 运行测试...${NC}"
            BUN_CMD=$(detect_bun)
            if [ -n "$BUN_CMD" ]; then
                "$BUN_CMD" test
            else
                echo -e "${RED}❌ 未找到 bun，请先运行 ./manage.sh install${NC}"
                exit 1
            fi
            ;;
        "clean")
            echo -e "${YELLOW}🧹 清理编译文件...${NC}"
            rm -rf dist
            echo -e "${GREEN}✅ 清理完成${NC}"
            ;;
            
        # 信息查看
        "logs")
            show_logs
            ;;
        "version")
            show_version
            ;;
        "overview")
            show_project_overview
            ;;
        "api-help")
            show_api_help
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
            
        *)
            echo -e "${RED}❌ 未知命令: $command${NC}"
            echo ""
            echo -e "${WHITE}💡 使用 ${CYAN}./manage.sh help${WHITE} 查看可用命令${NC}"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
