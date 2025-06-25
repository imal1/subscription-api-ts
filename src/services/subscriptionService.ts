import * as fs from 'fs-extra';
import * as path from 'path';
import { UpdateResult } from '../types';
import { config } from '../config';
import { logger } from '../utils/logger';
import { SingBoxService } from './singBoxService';
import { SubconverterService } from './subconverterService';

export class SubscriptionService {
    private static instance: SubscriptionService;
    private singBoxService: SingBoxService;
    private subconverterService: SubconverterService;
    
    public static getInstance(): SubscriptionService {
        if (!SubscriptionService.instance) {
            SubscriptionService.instance = new SubscriptionService();
        }
        return SubscriptionService.instance;
    }

    constructor() {
        this.singBoxService = SingBoxService.getInstance();
        this.subconverterService = SubconverterService.getInstance();
    }

    /**
     * 确保所有必要目录存在
     */
    async ensureDirectories(): Promise<void> {
        await fs.ensureDir(config.staticDir);
        await fs.ensureDir(config.logDir);
        await fs.ensureDir(config.backupDir);
        logger.info('目录检查完成');
    }

    /**
     * 更新订阅
     */
    async updateSubscription(): Promise<UpdateResult> {
        try {
            logger.info('开始更新订阅...');

            // 检查服务依赖
            const subconverterRunning = await this.subconverterService.checkHealth();
            if (!subconverterRunning) {
                throw new Error('Subconverter服务未运行或不可访问');
            }

            const singBoxAvailable = await this.singBoxService.checkSingBoxAvailable();
            if (!singBoxAvailable) {
                throw new Error('Sing-box不可用');
            }

            // 获取节点
            const { urls, errors } = await this.singBoxService.getAllConfigUrls();

            if (urls.length === 0) {
                throw new Error('未获取到任何有效节点');
            }

            // 确保目录存在
            await this.ensureDirectories();

            // 创建订阅内容
            const subscriptionContent = urls.join('\n');
            const encodedContent = Buffer.from(subscriptionContent).toString('base64');

            // 保存文件
            const subscriptionFile = path.join(config.staticDir, 'subscription.txt');
            const rawFile = path.join(config.staticDir, 'raw_links.txt');

            await fs.writeFile(subscriptionFile, encodedContent, 'utf8');
            await fs.writeFile(rawFile, subscriptionContent, 'utf8');

            logger.info(`订阅文件已保存: ${subscriptionFile}`);

            // 生成Clash配置
            let clashGenerated = false;
            try {
                const localSubscriptionUrl = `http://localhost:${config.nginxPort}/subscription.txt`;
                const clashContent = await this.subconverterService.convertToClash(localSubscriptionUrl);
                
                const clashFile = path.join(config.staticDir, 'clash.yaml');
                await fs.writeFile(clashFile, clashContent, 'utf8');
                clashGenerated = true;
                logger.info('Clash配置生成成功');
            } catch (clashError: any) {
                logger.error('生成Clash配置失败:', clashError.message);
            }

            // 创建备份
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
            const backupFile = path.join(config.backupDir, `subscription_${timestamp}.txt`);
            await fs.copy(subscriptionFile, backupFile);

            logger.info(`备份已创建: ${backupFile}`);

            const result: UpdateResult = {
                success: true,
                message: `订阅更新成功，共 ${urls.length} 个节点`,
                timestamp: new Date().toISOString(),
                nodesCount: urls.length,
                clashGenerated,
                backupCreated: backupFile,
                warnings: errors.length > 0 ? errors : undefined
            };

            logger.info(`订阅更新完成: ${urls.length} 个节点, Clash生成: ${clashGenerated}`);
            return result;

        } catch (error: any) {
            logger.error('更新订阅失败:', error);
            throw error;
        }
    }

    /**
     * 获取订阅状态信息
     */
    async getStatus(): Promise<any> {
        const subscriptionFile = path.join(config.staticDir, 'subscription.txt');
        const clashFile = path.join(config.staticDir, 'clash.yaml');
        const rawFile = path.join(config.staticDir, 'raw_links.txt');

        const status = {
            subscriptionExists: await fs.pathExists(subscriptionFile),
            clashExists: await fs.pathExists(clashFile),
            rawExists: await fs.pathExists(rawFile),
            subconverterRunning: await this.subconverterService.checkHealth(),
            singBoxAccessible: await this.singBoxService.checkSingBoxAvailable(),
            uptime: process.uptime(),
            version: '1.0.0'
        };

        // 获取文件信息
        if (status.subscriptionExists) {
            const stats = await fs.stat(subscriptionFile);
            (status as any).subscriptionLastUpdated = stats.mtime.toISOString();
            (status as any).subscriptionSize = stats.size;
        }

        if (status.clashExists) {
            const stats = await fs.stat(clashFile);
            (status as any).clashLastUpdated = stats.mtime.toISOString();
            (status as any).clashSize = stats.size;
        }

        if (status.rawExists) {
            const content = await fs.readFile(rawFile, 'utf8');
            const lines = content.split('\n').filter(line => line.trim());
            (status as any).nodesCount = lines.length;
        }

        return status;
    }

    /**
     * 获取文件内容
     */
    async getFileContent(filename: string): Promise<Buffer> {
        const filePath = path.join(config.staticDir, filename);
        
        if (!(await fs.pathExists(filePath))) {
            throw new Error(`文件 ${filename} 不存在`);
        }

        return await fs.readFile(filePath);
    }
}