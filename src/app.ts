import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import * as cron from 'node-cron';

import { config, validateConfig } from './config';
import { logger } from './utils/logger';
import { SubscriptionService } from './services/subscriptionService';
import routes from './routes';

export class App {
    public app: Application;
    private subscriptionService: SubscriptionService;

    constructor() {
        this.app = express();
        this.subscriptionService = SubscriptionService.getInstance();
        
        this.initializeMiddlewares();
        this.initializeRoutes();
        this.initializeErrorHandling();
        this.initializeCronJobs();
    }

    private initializeMiddlewares(): void {
        // 安全中间件
        this.app.use(helmet({
            crossOriginEmbedderPolicy: false,
            contentSecurityPolicy: false
        }));
        
        // 压缩中间件
        this.app.use(compression() as unknown as express.RequestHandler);
        
        // CORS中间件
        this.app.use(cors({
            origin: process.env.CORS_ORIGIN || '*',
            methods: ['GET', 'POST', 'PUT', 'DELETE'],
            allowedHeaders: ['Content-Type', 'Authorization']
        }));

        // 解析中间件
        this.app.use(express.json({ limit: '10mb' }));
        this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

        // 请求日志中间件
        this.app.use((req: Request, res: Response, next: NextFunction) => {
            const start = Date.now();
            
            res.on('finish', () => {
                const duration = Date.now() - start;
                logger.info(`${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration}ms - ${req.ip}`);
            });
            
            next();
        });
    }

    private initializeRoutes(): void {
        this.app.use('/', routes);
    }

    private initializeErrorHandling(): void {
        // 404处理
        this.app.use('*', (req: Request, res: Response) => {
            res.status(404).json({
                success: false,
                error: 'API端点不存在',
                message: `请求的端点 ${req.method} ${req.originalUrl} 不存在`,
                path: req.originalUrl,
                method: req.method,
                timestamp: new Date().toISOString(),
                availableEndpoints: {
                    'GET /': 'API文档',
                    'GET /api/update': '更新订阅',
                    'GET /api/status': '获取状态',
                    'GET /api/diagnose/clash': '诊断Clash生成问题',
                    'GET /subscription.txt': '获取Base64编码的订阅',
                    [`GET /${config.clashFilename}`]: '获取Clash配置',
                    'GET /raw.txt': '获取原始链接',
                    'GET /api/configs': '获取可用配置列表',
                    'POST /api/configs': '更新配置列表',
                    'GET /health': '健康检查'
                }
            });
        });

        // 全局错误处理 - Express 5.x 兼容
        this.app.use((error: Error, req: Request, res: Response, next: NextFunction) => {
            logger.error('未处理的错误:', {
                error: error.message,
                stack: error.stack,
                url: req.originalUrl,
                method: req.method,
                ip: req.ip
            });

            // Express 5.x 改进的错误处理
            if (res.headersSent) {
                return next(error);
            }

            res.status(500).json({
                success: false,
                error: '内部服务器错误',
                message: process.env.NODE_ENV === 'development' ? error.message : undefined,
                timestamp: new Date().toISOString()
            });
        });
    }

    private initializeCronJobs(): void {
        if (config.autoUpdateCron) {
            logger.info(`设置定时任务: ${config.autoUpdateCron}`);
            
            cron.schedule(config.autoUpdateCron, async () => {
                logger.info('执行定时更新订阅...');
                try {
                    const result = await this.subscriptionService.updateSubscription();
                    logger.info(`定时更新完成: ${result.nodesCount} 个节点`);
                } catch (error: any) {
                    logger.error('定时更新失败:', error);
                }
            }, {
                timezone: "Asia/Shanghai"
            });
            
            logger.info(`定时任务已启动，计划: ${config.autoUpdateCron} (Asia/Shanghai)`);
        }
    }

    public async initialize(): Promise<void> {
        try {
            // 验证配置
            validateConfig();
            logger.info('配置验证通过');

            // 确保必要目录存在
            await this.subscriptionService.ensureDirectories();
            logger.info('目录初始化完成');

            // 初始化完成
            logger.info('应用初始化完成');
        } catch (error: any) {
            logger.error('应用初始化失败:', error);
            throw error;
        }
    }

    public listen(): void {
        this.app.listen(config.port, '0.0.0.0', () => {
            logger.info(`🚀 服务器启动成功`);
            logger.info(`📡 监听端口: ${config.port}`);
            logger.info(`🌍 访问地址: http://localhost:${config.port}`);
            logger.info(`📝 API文档: http://localhost:${config.port}/`);
            logger.info(`📊 健康检查: http://localhost:${config.port}/health`);
            logger.info(`🔧 环境: ${process.env.NODE_ENV || 'development'}`);
        });
    }
}