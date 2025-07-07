#!/bin/bash

# 服务管理函数 (Linux 系统)

# 检查 systemd 服务状态
service_status() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    safe_sudo systemctl status "$service_name" --no-pager -l 2>/dev/null
}

# 检查服务是否运行
service_is_running() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        return 1
    fi
    
    safe_sudo systemctl is-active --quiet "$service_name" 2>/dev/null
}

# 启动服务
service_start() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "启动服务: $service_name"
    safe_sudo systemctl start "$service_name"
}

# 停止服务
service_stop() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "停止服务: $service_name"
    safe_sudo systemctl stop "$service_name"
}

# 重启服务
service_restart() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "重启服务: $service_name"
    safe_sudo systemctl restart "$service_name"
}

# 启用服务
service_enable() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "启用服务: $service_name"
    safe_sudo systemctl enable "$service_name"
}

# 禁用服务
service_disable() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务管理功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "禁用服务: $service_name"
    safe_sudo systemctl disable "$service_name"
}

# 重新加载 systemd 配置
systemd_reload() {
    if [ "$OS" != "linux" ]; then
        print_status "warning" "systemd 功能仅适用于 Linux 系统"
        return 1
    fi
    
    print_status "info" "重新加载 systemd 配置"
    safe_sudo systemctl daemon-reload
}

# 显示服务日志
service_logs() {
    local service_name="$1"
    local lines="${2:-50}"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务日志功能仅适用于 Linux 系统"
        return 1
    fi
    
    safe_sudo journalctl -u "$service_name" --lines="$lines" --no-pager
}

# 实时跟踪服务日志
service_logs_follow() {
    local service_name="$1"
    
    if [ "$OS" != "linux" ]; then
        print_status "warning" "服务日志功能仅适用于 Linux 系统"
        return 1
    fi
    
    safe_sudo journalctl -u "$service_name" -f
}
