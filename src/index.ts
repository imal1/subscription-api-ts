import dotenv from 'dotenv';

// 首先加载环境变量
dotenv.config();

import { App } from './app';
import { logger } from './utils/logger';
import * as packageJson from '../package.json';

async function bootstrap(): Promise<void> {
    try {
        logger.info('🚀 正在启动 Subscription API 服务...');
        logger.info(`📦 当前版本: ${packageJson.version}`);
        logger.info(`🔧 运行环境: ${process.env.NODE_ENV || 'development'}`);
        logger.info(`📝 Node.js 版本: ${process.version}`);
        
        const app = new App();
        
        // 初始化应用
        logger.info('⚙️  正在初始化应用...');
        await app.initialize();
        logger.info('✅ 应用初始化完成');
        
        // 启动服务器
        logger.info('🌐 正在启动 HTTP 服务器...');
        app.listen();
        
        // 优雅关闭处理
        const gracefulShutdown = (signal: string) => {
            logger.info(`收到 ${signal} 信号，正在关闭服务器...`);
            
            process.exit(0);
        };

        process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
        process.on('SIGINT', () => gracefulShutdown('SIGINT'));
        process.on('SIGUSR2', () => gracefulShutdown('SIGUSR2')); // nodemon restart

        // 未捕获异常处理
        process.on('uncaughtException', (error: Error) => {
            logger.error('未捕获的异常:', error);
            process.exit(1);
        });

        process.on('unhandledRejection', (reason: any, promise: Promise<any>) => {
            logger.error('未处理的Promise拒绝:', { reason, promise });
            process.exit(1);
        });

    } catch (error: any) {
        logger.error('应用启动失败:', error);
        process.exit(1);
    }
}

// 启动应用
bootstrap();