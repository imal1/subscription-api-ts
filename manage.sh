#!/bin/bash

# Subscription API TypeScript 管理脚本
# 功能：提供项目管理、诊断、部署等功能的统一入口
# 作者：subscription-api-ts 项目组
# 版本：1.0.0

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 显示标题
show_header() {
    echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${WHITE}    Subscription API TypeScript 管理工具    ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# 显示帮助信息
show_help() {
    show_header
    echo -e "${WHITE}使用方法:${NC}"
    echo -e "  ${CYAN}./manage.sh [命令]${NC}"
    echo ""
    echo -e "${WHITE}🚀 核心管理命令:${NC}"
    echo -e "  ${GREEN}install${NC}          完整项目安装和配置"
    echo -e "  ${GREEN}start${NC}            启动服务"
    echo -e "  ${GREEN}stop${NC}             停止服务"
    echo -e "  ${GREEN}restart${NC}          重启服务"
    echo -e "  ${GREEN}status${NC}           查看服务状态（快速检查）"
    echo -e "  ${GREEN}check${NC}            全面服务状态检测"
    echo ""
    echo -e "${WHITE}🔧 开发工具:${NC}"
    echo -e "  ${BLUE}build${NC}            编译 TypeScript 项目"
    echo -e "  ${BLUE}dev${NC}              启动开发模式"
    echo -e "  ${BLUE}test${NC}             运行测试"
    echo -e "  ${BLUE}clean${NC}            清理编译文件"
    echo ""
    echo -e "${WHITE}🛠️ 诊断修复:${NC}"
    echo -e "  ${YELLOW}diagnose${NC}         运行系统诊断"
    echo -e "  ${YELLOW}diagnose-ts${NC}      TypeScript 编译诊断"
    echo -e "  ${YELLOW}diagnose-workdir${NC} 工作目录权限诊断"
    echo -e "  ${YELLOW}diagnose-node${NC}    Node.js 和路径诊断"
    echo -e "  ${YELLOW}fix${NC}              自动修复常见问题"
    echo -e "  ${YELLOW}fix-ts${NC}           修复 TypeScript 问题"
    echo -e "  ${YELLOW}fix-node${NC}         修复 Node.js 路径问题"
    echo -e "  ${YELLOW}fix-systemd${NC}      快速修复 systemd 服务"
    echo -e "  ${YELLOW}fix-workdir${NC}      修复工作目录权限问题"
    echo -e "  ${YELLOW}fix-systemd-workdir${NC} 修复 systemd 工作目录问题"
    echo ""
    echo -e "${WHITE}🌐 网络服务:${NC}"
    echo -e "  ${PURPLE}nginx-setup${NC}      配置 Nginx"
    echo -e "  ${PURPLE}nginx-config${NC}     生成 Nginx 配置"
    echo -e "  ${PURPLE}systemd-config${NC}   生成 systemd 服务配置"
    echo ""
    echo -e "${WHITE}📋 信息查看:${NC}"
    echo -e "  ${CYAN}logs${NC}             查看服务日志"
    echo -e "  ${CYAN}version${NC}          显示版本信息"
    echo -e "  ${CYAN}overview${NC}         项目状态概览"
    echo -e "  ${CYAN}help${NC}             显示此帮助信息"
    echo ""
    echo -e "${WHITE}💡 示例:${NC}"
    echo -e "  ${CYAN}./manage.sh install${NC}         # 完整安装项目"
    echo -e "  ${CYAN}./manage.sh status${NC}          # 快速检查服务状态"
    echo -e "  ${CYAN}./manage.sh check${NC}           # 全面诊断服务"
    echo -e "  ${CYAN}./manage.sh fix${NC}             # 自动修复问题"
    echo -e "  ${CYAN}./manage.sh fix-workdir${NC}     # 修复工作目录问题"
    echo -e "  ${CYAN}./manage.sh fix-systemd-workdir${NC} # 修复 systemd 工作目录问题"
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
detect_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "Mac";;
        *)          echo "Unknown";;
    esac
}

# 服务管理
manage_service() {
    local action="$1"
    local os=$(detect_os)
    
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        case "$action" in
            "start")
                echo -e "${GREEN}🚀 启动服务: $service_name${NC}"
                sudo systemctl start "$service_name"
                sudo systemctl status "$service_name" --no-pager -l
                ;;
            "stop")
                echo -e "${YELLOW}⏹️  停止服务: $service_name${NC}"
                sudo systemctl stop "$service_name"
                ;;
            "restart")
                echo -e "${BLUE}🔄 重启服务: $service_name${NC}"
                sudo systemctl restart "$service_name"
                sudo systemctl status "$service_name" --no-pager -l
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
                    echo -e "${YELLOW}💡 使用 npm start 启动服务，或安装 PM2: npm install -g pm2${NC}"
                    npm start &
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
                    pkill -f "node.*dist/index.js"
                    sleep 1
                    npm start &
                fi
                ;;
        esac
    fi
}

# 查看日志
show_logs() {
    local os=$(detect_os)
    
    if [ "$os" = "Linux" ]; then
        local service_name="${SERVICE_NAME:-subscription-api-ts}"
        echo -e "${CYAN}📝 查看服务日志 (最新 50 条):${NC}"
        sudo journalctl -u "$service_name" -n 50 --no-pager
        echo ""
        echo -e "${WHITE}💡 实时查看日志: sudo journalctl -u $service_name -f${NC}"
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
    echo -e "${WHITE}📦 项目信息:${NC}"
    if [ -f "package.json" ]; then
        local version=$(grep '"version"' package.json | cut -d'"' -f4)
        local name=$(grep '"name"' package.json | cut -d'"' -f4)
        echo -e "  项目名称: ${GREEN}$name${NC}"
        echo -e "  项目版本: ${GREEN}$version${NC}"
    fi
    
    echo ""
    echo -e "${WHITE}🟢 运行环境:${NC}"
    if command -v node >/dev/null 2>&1; then
        echo -e "  Node.js: ${GREEN}$(node --version)${NC}"
    fi
    if command -v npm >/dev/null 2>&1; then
        echo -e "  npm: ${GREEN}$(npm --version)${NC}"
    fi
    echo -e "  操作系统: ${GREEN}$(detect_os)${NC}"
    echo -e "  用户: ${GREEN}$(whoami)${NC}"
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
    
    local os=$(detect_os)
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
    if [ -f ".env" ]; then
        echo -e "${WHITE}配置:${NC} ${GREEN}✅ .env 存在${NC}"
    else
        echo -e "${WHITE}配置:${NC} ${RED}❌ .env 缺失${NC}"
    fi
    
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${WHITE}💡 快速操作:${NC}"
    echo -e "  ${CYAN}./manage.sh status${NC}  - 快速状态检查"
    echo -e "  ${CYAN}./manage.sh check${NC}   - 详细诊断"
    echo -e "  ${CYAN}./manage.sh start${NC}   - 启动服务"
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
            run_script "quick-status.sh" "$@"
            ;;
        "check")
            run_script "check-service-status.sh" "$@"
            ;;
            
        # 开发工具
        "build")
            echo -e "${BLUE}🏗️  编译项目...${NC}"
            npm run build
            ;;
        "dev")
            echo -e "${BLUE}🚀 启动开发模式...${NC}"
            npm run dev
            ;;
        "test")
            echo -e "${BLUE}🧪 运行测试...${NC}"
            npm test
            ;;
        "clean")
            echo -e "${YELLOW}🧹 清理编译文件...${NC}"
            rm -rf dist
            echo -e "${GREEN}✅ 清理完成${NC}"
            ;;
            
        # 诊断修复
        "diagnose")
            run_script "diagnose-systemd.sh" "$@"
            ;;
        "diagnose-ts")
            run_script "diagnose-typescript.sh" "$@"
            ;;
        "diagnose-workdir")
            run_script "diagnose-workdir.sh" "$@"
            ;;
        "diagnose-node")
            run_script "diagnose-node.sh" "$@"
            ;;
        "fix")
            run_script "fix-systemd.sh" "$@"
            ;;
        "fix-ts")
            run_script "fix-typescript.sh" "$@"
            ;;
        "fix-node")
            run_script "fix-node-path.sh" "$@"
            ;;
        "fix-systemd")
            run_script "quick-fix-systemd.sh" "$@"
            ;;
        "fix-workdir")
            run_script "fix-workdir.sh" "$@"
            ;;
        "fix-systemd-workdir")
            run_script "fix-systemd-workdir.sh" "$@"
            ;;
            
        # 网络服务
        "nginx-setup")
            run_script "setup-nginx.sh" "$@"
            ;;
        "nginx-config")
            run_script "generate-nginx-config.sh" "$@"
            ;;
        "systemd-config")
            run_script "generate-systemd-service.sh" "$@"
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
