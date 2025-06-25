#!/usr/bin/env python3
import os
import base64
import subprocess
import requests
from flask import Flask, jsonify, request, send_file
from datetime import datetime
import json
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)

# 配置 (从环境变量读取)
SING_BOX_CONFIGS = os.getenv('SING_BOX_CONFIGS', 'vless-reality,hysteria2,trojan,tuic,vmess').split(',')
SUBCONVERTER_URL = os.getenv('SUBCONVERTER_URL', 'http://localhost:25500')
STATIC_DIR = os.getenv('STATIC_DIR', './data')
LOG_DIR = os.getenv('LOG_DIR', './logs')
BACKUP_DIR = os.getenv('BACKUP_DIR', './data/backup')
MAX_RETRIES = int(os.getenv('MAX_RETRIES', '3'))
REQUEST_TIMEOUT = int(os.getenv('REQUEST_TIMEOUT', '30000')) // 1000  # 转换为秒
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO').upper()
NGINX_PORT = int(os.getenv('NGINX_PORT', '8080'))

# 配置日志
if not os.path.exists(LOG_DIR):
    os.makedirs(LOG_DIR)

logging.basicConfig(level=logging.INFO)
handler = RotatingFileHandler(f'{LOG_DIR}/subscription_api.log', maxBytes=10000000, backupCount=5)
handler.setFormatter(logging.Formatter('%(asctime)s %(levelname)s: %(message)s'))
app.logger.addHandler(handler)

def get_sing_box_urls():
    """获取sing-box节点URL"""
    urls = []
    errors = []
    
    for config in SING_BOX_CONFIGS:
        try:
            # 检查配置是否存在
            check_result = subprocess.run(['sing-box', 'info', config], 
                                        capture_output=True, text=True, timeout=10)
            
            if check_result.returncode != 0:
                errors.append(f"配置 {config} 不存在")
                continue
                
            # 获取URL
            result = subprocess.run(['sing-box', 'url', config], 
                                  capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0 and result.stdout.strip():
                url = result.stdout.strip()
                urls.append(url)
                app.logger.info(f"成功获取配置 {config}")
            else:
                errors.append(f"配置 {config} 获取失败: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            errors.append(f"配置 {config} 获取超时")
        except Exception as e:
            errors.append(f"配置 {config} 获取异常: {str(e)}")
    
    return urls, errors

def check_subconverter():
    """检查subconverter服务状态"""
    try:
        response = requests.get(f"{SUBCONVERTER_URL}/version", timeout=5)
        return response.status_code == 200
    except:
        return False

@app.route('/')
def index():
    """首页，显示API文档"""
    return jsonify({
        "name": "Subscription API",
        "version": "1.0",
        "endpoints": {
            "GET /": "API文档",
            "POST /api/update": "更新订阅",
            "GET /api/status": "获取状态",
            "GET /subscription.txt": "获取Base64编码的订阅",
            "GET /clash.yaml": "获取Clash配置",
            "GET /api/configs": "获取可用配置列表",
            "POST /api/configs": "更新配置列表"
        }
    })

@app.route('/api/update', methods=['POST'])
def update_subscription():
    """更新订阅"""
    try:
        app.logger.info("开始更新订阅...")
        
        # 检查subconverter状态
        if not check_subconverter():
            return jsonify({"error": "Subconverter服务未运行"}), 503
        
        # 获取节点
        urls, errors = get_sing_box_urls()
        
        if not urls:
            app.logger.error("未获取到任何节点")
            return jsonify({
                "error": "未获取到任何节点",
                "details": errors
            }), 400
        
        # 创建订阅内容
        subscription_content = '\n'.join(urls)
        encoded_content = base64.b64encode(subscription_content.encode()).decode()
        
        # 确保目录存在
        os.makedirs(STATIC_DIR, exist_ok=True)
        
        # 保存订阅文件
        subscription_file = f"{STATIC_DIR}/subscription.txt"
        with open(subscription_file, 'w') as f:
            f.write(encoded_content)
        
        # 保存原始链接（便于调试）
        raw_file = f"{STATIC_DIR}/raw_links.txt"
        with open(raw_file, 'w') as f:
            f.write(subscription_content)
        
        # 生成Clash配置
        try:
            # 使用本地文件URL
            local_subscription_url = f"http://localhost:{NGINX_PORT}/subscription.txt"
            clash_url = f"{SUBCONVERTER_URL}/sub?target=clash&url={local_subscription_url}"
            
            app.logger.info(f"请求Clash转换: {clash_url}")
            response = requests.get(clash_url, timeout=REQUEST_TIMEOUT)
            
            if response.status_code == 200:
                clash_file = f"{STATIC_DIR}/clash.yaml"
                with open(clash_file, 'w', encoding='utf-8') as f:
                    f.write(response.text)
                app.logger.info("Clash配置生成成功")
                clash_generated = True
            else:
                app.logger.error(f"Clash配置生成失败: {response.status_code} - {response.text}")
                clash_generated = False
                
        except Exception as e:
            app.logger.error(f"生成Clash配置时出错: {str(e)}")
            clash_generated = False
        
        # 创建备份
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = f"{STATIC_DIR}/backup/subscription_{timestamp}.txt"
        os.makedirs(f"{STATIC_DIR}/backup", exist_ok=True)
        
        import shutil
        shutil.copy2(subscription_file, backup_file)
        
        result = {
            "success": True,
            "message": f"订阅更新成功，共 {len(urls)} 个节点",
            "timestamp": datetime.now().isoformat(),
            "nodes_count": len(urls),
            "clash_generated": clash_generated,
            "backup_created": backup_file
        }
        
        if errors:
            result["warnings"] = errors
            
        app.logger.info(f"订阅更新完成: {len(urls)} 个节点")
        return jsonify(result)
        
    except Exception as e:
        app.logger.error(f"更新订阅时出错: {str(e)}")
        return jsonify({"error": f"内部错误: {str(e)}"}), 500

@app.route('/api/status', methods=['GET'])
def get_status():
    """获取状态信息"""
    try:
        # 检查文件状态
        subscription_file = f"{STATIC_DIR}/subscription.txt"
        clash_file = f"{STATIC_DIR}/clash.yaml"
        raw_file = f"{STATIC_DIR}/raw_links.txt"
        
        status = {
            "subscription_exists": os.path.exists(subscription_file),
            "clash_exists": os.path.exists(clash_file),
            "raw_exists": os.path.exists(raw_file),
            "subconverter_running": check_subconverter(),
            "sing_box_accessible": True
        }
        
        # 检查sing-box是否可访问
        try:
            subprocess.run(['sing-box', '--version'], capture_output=True, timeout=5)
        except:
            status["sing_box_accessible"] = False
            
        # 获取文件信息
        if status["subscription_exists"]:
            stat = os.stat(subscription_file)
            status["subscription_last_updated"] = datetime.fromtimestamp(stat.st_mtime).isoformat()
            status["subscription_size"] = stat.st_size
            
        if status["clash_exists"]:
            stat = os.stat(clash_file)
            status["clash_last_updated"] = datetime.fromtimestamp(stat.st_mtime).isoformat()
            status["clash_size"] = stat.st_size
            
        # 获取节点数量
        if status["raw_exists"]:
            with open(raw_file, 'r') as f:
                lines = f.readlines()
                status["nodes_count"] = len([line for line in lines if line.strip()])
            
        return jsonify(status)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/configs', methods=['GET'])
def get_configs():
    """获取当前配置的节点列表"""
    return jsonify({
        "configs": SING_BOX_CONFIGS,
        "description": "当前配置的sing-box节点名称列表"
    })

@app.route('/api/configs', methods=['POST'])
def update_configs():
    """更新配置列表"""
    try:
        data = request.get_json()
        if not data or 'configs' not in data:
            return jsonify({"error": "请提供configs数组"}), 400
            
        global SING_BOX_CONFIGS
        SING_BOX_CONFIGS = data['configs']
        
        app.logger.info(f"配置列表已更新: {SING_BOX_CONFIGS}")
        return jsonify({
            "success": True,
            "message": "配置列表更新成功",
            "configs": SING_BOX_CONFIGS
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/subscription.txt')
def get_subscription():
    """获取订阅文件"""
    try:
        subscription_file = f"{STATIC_DIR}/subscription.txt"
        if os.path.exists(subscription_file):
            return send_file(subscription_file, mimetype='text/plain')
        else:
            return "订阅文件不存在，请先执行更新操作", 404
    except Exception as e:
        return f"获取订阅文件失败: {str(e)}", 500

@app.route('/clash.yaml')
def get_clash_config():
    """获取Clash配置"""
    try:
        clash_file = f"{STATIC_DIR}/clash.yaml"
        if os.path.exists(clash_file):
            return send_file(clash_file, mimetype='text/yaml')
        else:
            return "Clash配置文件不存在，请先执行更新操作", 404
    except Exception as e:
        return f"获取Clash配置失败: {str(e)}", 500

@app.route('/raw.txt')
def get_raw_links():
    """获取原始链接文件（调试用）"""
    try:
        raw_file = f"{STATIC_DIR}/raw_links.txt"
        if os.path.exists(raw_file):
            return send_file(raw_file, mimetype='text/plain')
        else:
            return "原始链接文件不存在", 404
    except Exception as e:
        return f"获取原始链接失败: {str(e)}", 500

if __name__ == '__main__':
    import os
    port = int(os.getenv('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)