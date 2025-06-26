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
            let clashError: string | null = null;
            try {
                // 检查 subconverter 服务状态
                const subconverterHealthy = await this.subconverterService.checkHealth();
                logger.info(`Subconverter服务状态: ${subconverterHealthy ? '正常' : '异常'}`);
                
                if (!subconverterHealthy) {
                    throw new Error('Subconverter服务不可用，请检查服务是否启动');
                }
                
                const localSubscriptionUrl = `http://localhost:${config.nginxPort}/subscription.txt`;
                logger.info(`开始生成Clash配置，使用订阅URL: ${localSubscriptionUrl}`);
                
                const clashContent = await this.subconverterService.convertToClash(localSubscriptionUrl);
                
                if (!clashContent || clashContent.trim().length === 0) {
                    throw new Error('转换返回空内容');
                }
                
                const clashFile = path.join(config.staticDir, 'clash.yaml');
                await fs.writeFile(clashFile, clashContent, 'utf8');
                
                // 验证文件是否成功写入
                const fileExists = await fs.pathExists(clashFile);
                const fileStats = fileExists ? await fs.stat(clashFile) : null;
                
                if (fileExists && fileStats && fileStats.size > 0) {
                    clashGenerated = true;
                    logger.info(`Clash配置生成成功，文件大小: ${fileStats.size} 字节`);
                } else {
                    throw new Error('文件写入失败或文件为空');
                }
            } catch (error: any) {
                clashError = error.message;
                logger.error('生成Clash配置失败:', error.message);
                logger.error('错误详情:', error);
            }

            // 创建备份
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
            const backupFile = path.join(config.backupDir, `subscription_${timestamp}.txt`);
            await fs.copy(subscriptionFile, backupFile);

            logger.info(`备份已创建: ${backupFile}`);

            const result: UpdateResult = {
                success: true,
                message: `订阅更新成功，共 ${urls.length} 个节点${clashGenerated ? '' : ' (Clash生成失败)'}`,
                timestamp: new Date().toISOString(),
                nodesCount: urls.length,
                clashGenerated,
                backupCreated: backupFile,
                warnings: errors.length > 0 ? errors : undefined,
                errors: clashError ? [`Clash生成失败: ${clashError}`] : undefined
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

    /**
     * 诊断 Clash 配置生成问题
     */
    async diagnoseClashGeneration(): Promise<any> {
        const diagnosis: any = {
            timestamp: new Date().toISOString(),
            checks: {}
        };

        try {
            // 1. 检查文件存在性
            const subscriptionFile = path.join(config.staticDir, 'subscription.txt');
            const clashFile = path.join(config.staticDir, 'clash.yaml');
            
            diagnosis.checks.subscriptionFileExists = await fs.pathExists(subscriptionFile);
            diagnosis.checks.clashFileExists = await fs.pathExists(clashFile);
            
            if (diagnosis.checks.subscriptionFileExists) {
                const stats = await fs.stat(subscriptionFile);
                diagnosis.checks.subscriptionFileSize = stats.size;
                diagnosis.checks.subscriptionLastModified = stats.mtime.toISOString();
            }
            
            if (diagnosis.checks.clashFileExists) {
                const stats = await fs.stat(clashFile);
                diagnosis.checks.clashFileSize = stats.size;
                diagnosis.checks.clashLastModified = stats.mtime.toISOString();
            }

            // 2. 检查 subconverter 服务
            diagnosis.checks.subconverterHealthy = await this.subconverterService.checkHealth();
            
            if (diagnosis.checks.subconverterHealthy) {
                try {
                    diagnosis.checks.subconverterVersion = await this.subconverterService.getVersion();
                } catch (error) {
                    diagnosis.checks.subconverterVersionError = (error as Error).message;
                }
            }

            // 3. 检查本地订阅 URL 访问
            const localSubscriptionUrl = `http://localhost:${config.nginxPort}/subscription.txt`;
            diagnosis.checks.localSubscriptionUrl = localSubscriptionUrl;
            
            try {
                const axios = require('axios');
                const response = await axios.get(localSubscriptionUrl, { timeout: 5000 });
                diagnosis.checks.localSubscriptionAccessible = true;
                diagnosis.checks.localSubscriptionStatus = response.status;
                diagnosis.checks.localSubscriptionContentLength = response.data ? response.data.length : 0;
            } catch (error: any) {
                diagnosis.checks.localSubscriptionAccessible = false;
                diagnosis.checks.localSubscriptionError = error.message;
            }

            // 4. 如果 subconverter 可用，尝试转换
            if (diagnosis.checks.subconverterHealthy && diagnosis.checks.localSubscriptionAccessible) {
                try {
                    const clashContent = await this.subconverterService.convertToClash(localSubscriptionUrl);
                    diagnosis.checks.conversionTest = {
                        success: true,
                        contentLength: clashContent ? clashContent.length : 0,
                        hasContent: clashContent && clashContent.trim().length > 0
                    };
                } catch (error: any) {
                    diagnosis.checks.conversionTest = {
                        success: false,
                        error: error.message
                    };
                }
            }

            // 5. 检查目录权限
            try {
                const testFile = path.join(config.staticDir, '.test_write');
                await fs.writeFile(testFile, 'test', 'utf8');
                await fs.remove(testFile);
                diagnosis.checks.directoryWritable = true;
            } catch (error: any) {
                diagnosis.checks.directoryWritable = false;
                diagnosis.checks.directoryWriteError = error.message;
            }

            return diagnosis;
        } catch (error: any) {
            diagnosis.error = error.message;
            return diagnosis;
        }
    }
}