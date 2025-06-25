import multiprocessing
import os

# Gunicorn配置文件
port = os.getenv('PORT', '3000')
bind = f"127.0.0.1:{port}"
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True