const express = require('express');
const axios = require('axios');
const fs = require('fs-extra');
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');
const cron = require('node-cron');
const winston = require('winston');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');

const execAsync = promisify(exec);
const app = express();

// 配置
const CONFIG = {
    port: parseInt(process.env.PORT || '3000'),
    singBoxConfigs: (process.env.SING_BOX_CONFIGS || 'vless-reality,hysteria2,trojan,tuic,vmess').split(','),
    subconverterUrl: process.env.SUBCONVERTER_URL || 'http://localhost:25500',
    staticDir: process.env.DATA_DIR || './data',
    logDir: process.env.LOG_DIR || './logs',
    backupDir: process.env.BACKUP_DIR || './data/backup',
    autoUpdateCron: process.env.AUTO_UPDATE_CRON || '0 */2 * * *',
    maxRetries: parseInt(process.env.MAX_RETRIES || '3'),
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT || '30000'),
    nginxPort: parseInt(process.env.NGINX_PORT || '3080')
};

// 创建必要目录
async function ensureDirectories() {
    await fs.ensureDir(CONFIG.staticDir);
    await fs.ensureDir(CONFIG.logDir);
    await fs.ensureDir(CONFIG.backupDir);
}

// 配置日志
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json()
    ),
    defaultMeta: { service: 'subscription-api' },
    transports: [
        new winston.transports.File({ 
            filename: path.join(CONFIG.logDir, 'error.log'), 
            level: 'error' 
        }),
        new winston.transports.File({ 
            filename: path.join(CONFIG.logDir, 'combined.log') 
        }),
        new winston.transports.Console({
            format: winston.format.combine(
                winston.format.colorize(),
                winston.format.simple()
            )
        })
    ]
});

// 中间件
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 请求日志中间件
app.use((req, res, next) => {
    logger.info(`${req.method} ${req.path} - ${req.ip}`);
    next();
});

// 获取sing-box节点URL
async function getSingBoxUrls() {
    const urls = [];
    const errors = [];

    for (const config of CONFIG.singBoxConfigs) {
        try {
            // 检查配置是否存在
            const { stdout: infoOutput, stderr: infoError } = await execAsync(`sing-box info ${config}`, { timeout: CONFIG.requestTimeout });
            
            if (infoError && infoError.includes('not found')) {
                errors.push(`配置 ${config} 不存在`);
                continue;
            }

            // 获取URL
            const { stdout, stderr } = await execAsync(`sing-box url ${config}`, { timeout: CONFIG.requestTimeout });
            
            if (stdout && stdout.trim()) {
                urls.push(stdout.trim());
                logger.info(`成功获取配置 ${config}`);
            } else {
                errors.push(`配置 ${config} 获取失败: ${stderr || '无输出'}`);
            }
        } catch (error) {
            if (error.killed) {
                errors.push(`配置 ${config} 获取超时`);
            } else {
                errors.push(`配置 ${config} 获取异常: ${error.message}`);
            }
            logger.error(`获取配置 ${config} 失败:`, error);
        }
    }

    return { urls, errors };
}

// 检查subconverter服务
async function checkSubconverter() {
    try {
        const response = await axios.get(`${CONFIG.subconverterUrl}/version`, { timeout: parseInt(process.env.REQUEST_TIMEOUT || '30000') });
        return response.status === 200;
    } catch (error) {
        return false;
    }
}

// 更新订阅
async function updateSubscription() {
    try {
        logger.info('开始更新订阅...');

        // 检查subconverter状态
        const subconverterRunning = await checkSubconverter();
        if (!subconverterRunning) {
            throw new Error('Subconverter服务未运行');
        }

        // 获取节点
        const { urls, errors } = await getSingBoxUrls();

        if (urls.length === 0) {
            throw new Error('未获取到任何节点');
        }

        // 创建订阅内容
        const subscriptionContent = urls.join('\n');
        const encodedContent = Buffer.from(subscriptionContent).toString('base64');

        // 确保目录存在
        await ensureDirectories();

        // 保存文件
        const subscriptionFile = path.join(CONFIG.staticDir, 'subscription.txt');
        const rawFile = path.join(CONFIG.staticDir, 'raw_links.txt');

        await fs.writeFile(subscriptionFile, encodedContent);
        await fs.writeFile(rawFile, subscriptionContent);

        // 生成Clash配置
        let clashGenerated = false;
        try {
            const localSubscriptionUrl = `http://localhost:${CONFIG.nginxPort}/subscription.txt`;
            const clashUrl = `${CONFIG.subconverterUrl}/sub?target=clash&url=${encodeURIComponent(localSubscriptionUrl)}`;
            
            logger.info(`请求Clash转换: ${clashUrl}`);
            const response = await axios.get(clashUrl, { timeout: CONFIG.requestTimeout });

            if (response.status === 200) {
                const clashFile = path.join(CONFIG.staticDir, 'clash.yaml');
                await fs.writeFile(clashFile, response.data);
                logger.info('Clash配置生成成功');
                clashGenerated = true;
            }
        } catch (error) {
            logger.error('生成Clash配置失败:', error.message);
        }

        // 创建备份
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
        const backupFile = path.join(CONFIG.backupDir, `subscription_${timestamp}.txt`);
        await fs.copy(subscriptionFile, backupFile);

        const result = {
            success: true,
            message: `订阅更新成功，共 ${urls.length} 个节点`,
            timestamp: new Date().toISOString(),
            nodesCount: urls.length,
            clashGenerated,
            backupCreated: backupFile,
            warnings: errors.length > 0 ? errors : undefined
        };

        logger.info(`订阅更新完成: ${urls.length} 个节点`);
        return result;

    } catch (error) {
        logger.error('更新订阅失败:', error);
        throw error;
    }
}

// API路由

// 首页 - API文档
app.get('/', (req, res) => {
    res.json({
        name: 'Subscription API',
        version: '1.0.0',
        description: 'Node.js订阅转换API服务',
        endpoints: {
            'GET /': 'API文档',
            'POST /api/update': '更新订阅',
            'GET /api/status': '获取状态',
            'GET /subscription.txt': '获取Base64编码的订阅',
            'GET /clash.yaml': '获取Clash配置',
            'GET /raw.txt': '获取原始链接',
            'GET /api/configs': '获取可用配置列表',
            'POST /api/configs': '更新配置列表'
        }
    });
});

// 更新订阅
app.post('/api/update', async (req, res) => {
    try {
        const result = await updateSubscription();
        res.json(result);
    } catch (error) {
        res.status(500).json({
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// 获取状态
app.get('/api/status', async (req, res) => {
    try {
        const subscriptionFile = path.join(CONFIG.staticDir, 'subscription.txt');
        const clashFile = path.join(CONFIG.staticDir, 'clash.yaml');
        const rawFile = path.join(CONFIG.staticDir, 'raw_links.txt');

        const status = {
            subscriptionExists: await fs.pathExists(subscriptionFile),
            clashExists: await fs.pathExists(clashFile),
            rawExists: await fs.pathExists(rawFile),
            subconverterRunning: await checkSubconverter(),
            singBoxAccessible: true
        };

        // 检查sing-box是否可访问
        try {
            await execAsync('sing-box --version', { timeout: parseInt(process.env.REQUEST_TIMEOUT || '30000') });
        } catch (error) {
            status.singBoxAccessible = false;
        }

        // 获取文件信息
        if (status.subscriptionExists) {
            const stats = await fs.stat(subscriptionFile);
            status.subscriptionLastUpdated = stats.mtime.toISOString();
            status.subscriptionSize = stats.size;
        }

        if (status.clashExists) {
            const stats = await fs.stat(clashFile);
            status.clashLastUpdated = stats.mtime.toISOString();
            status.clashSize = stats.size;
        }

        if (status.rawExists) {
            const content = await fs.readFile(rawFile, 'utf8');
            const lines = content.split('\n').filter(line => line.trim());
            status.nodesCount = lines.length;
        }

        res.json(status);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 获取配置列表
app.get('/api/configs', (req, res) => {
    res.json({
        configs: CONFIG.singBoxConfigs,
        description: '当前配置的sing-box节点名称列表'
    });
});

// 更新配置列表
app.post('/api/configs', (req, res) => {
    try {
        const { configs } = req.body;
        
        if (!Array.isArray(configs)) {
            return res.status(400).json({ error: '请提供configs数组' });
        }

        CONFIG.singBoxConfigs = configs;
        logger.info(`配置列表已更新: ${JSON.stringify(configs)}`);

        res.json({
            success: true,
            message: '配置列表更新成功',
            configs: CONFIG.singBoxConfigs
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 文件下载路由
app.get('/subscription.txt', async (req, res) => {
    try {
        const filePath = path.join(CONFIG.staticDir, 'subscription.txt');
        
        if (await fs.pathExists(filePath)) {
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.sendFile(filePath);
        } else {
            res.status(404).send('订阅文件不存在，请先执行更新操作');
        }
    } catch (error) {
        res.status(500).send(`获取订阅文件失败: ${error.message}`);
    }
});

app.get('/clash.yaml', async (req, res) => {
    try {
        const filePath = path.join(CONFIG.staticDir, 'clash.yaml');
        
        if (await fs.pathExists(filePath)) {
            res.setHeader('Content-Type', 'text/yaml; charset=utf-8');
            res.sendFile(filePath);
        } else {
            res.status(404).send('Clash配置文件不存在，请先执行更新操作');
        }
    } catch (error) {
        res.status(500).send(`获取Clash配置失败: ${error.message}`);
    }
});

app.get('/raw.txt', async (req, res) => {
    try {
        const filePath = path.join(CONFIG.staticDir, 'raw_links.txt');
        
        if (await fs.pathExists(filePath)) {
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.sendFile(filePath);
        } else {
            res.status(404).send('原始链接文件不存在');
        }
    } catch (error) {
        res.status(500).send(`获取原始链接失败: ${error.message}`);
    }
});

// 健康检查
app.get('/health', (req, res) => {
    res.send('OK');
});

// 错误处理中间件
app.use((error, req, res, next) => {
    logger.error('Unhandled error:', error);
    res.status(500).json({
        error: '内部服务器错误',
        message: error.message
    });
});

// 404处理
app.use((req, res) => {
    res.status(404).json({
        error: '端点不存在',
        path: req.path
    });
});

// 定时任务
if (CONFIG.autoUpdateCron) {
    cron.schedule(CONFIG.autoUpdateCron, async () => {
        logger.info('执行定时更新订阅...');
        try {
            await updateSubscription();
            logger.info('定时更新完成');
        } catch (error) {
            logger.error('定时更新失败:', error);
        }
    }, {
        timezone: "Asia/Shanghai"
    });
    
    logger.info(`定时任务已启动，计划: ${CONFIG.autoUpdateCron}`);
}

// 启动服务器
async function startServer() {
    try {
        await ensureDirectories();
        
        app.listen(CONFIG.port, '0.0.0.0', () => {
            logger.info(`服务器启动成功，监听端口 ${CONFIG.port}`);
            logger.info(`访问地址: http://localhost:${CONFIG.port}`);
        });
    } catch (error) {
        logger.error('启动服务器失败:', error);
        process.exit(1);
    }
}

// 优雅关闭
process.on('SIGTERM', () => {
    logger.info('收到SIGTERM信号，正在关闭服务器...');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('收到SIGINT信号，正在关闭服务器...');
    process.exit(0);
});

startServer();