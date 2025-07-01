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

            // 从原始URLs中提取纯净的代理URL
            const validProxyProtocols = ['vless://', 'vmess://', 'ss://', 'ssr://', 'trojan://', 'hysteria2://', 'tuic://', 'wireguard://'];
            const extractedUrls: string[] = [];
            const protocolStats: { [key: string]: number } = {};
            
            for (const rawUrl of urls) {
                // 移除ANSI颜色代码 - 使用字符代码27 (ESC)
                const ansiRegex = new RegExp(String.fromCharCode(27) + '\\[[0-9;]*m', 'g');
                const cleanUrl = rawUrl.replace(ansiRegex, '');
                
                // 将内容按行分割
                const lines = cleanUrl.split('\n');
                
                for (const line of lines) {
                    const trimmedLine = line.trim();
                    
                    // 跳过空行
                    if (!trimmedLine) continue;
                    
                    // 检查是否是有效的代理URL
                    const matchedProtocol = validProxyProtocols.find(protocol => trimmedLine.startsWith(protocol));
                    
                    if (matchedProtocol) {
                        // 进一步验证URL格式
                        if (trimmedLine.includes('@') && trimmedLine.includes(':') && trimmedLine.length > 20) {
                            extractedUrls.push(trimmedLine);
                            
                            // 统计协议类型
                            const protocolName = matchedProtocol.replace('://', '');
                            protocolStats[protocolName] = (protocolStats[protocolName] || 0) + 1;
                            
                            logger.info(`提取到有效代理URL [${protocolName}]: ${trimmedLine.substring(0, 50)}...`);
                        }
                    }
                }
            }
            
            logger.info(`URL提取结果: 从${urls.length}个原始条目中提取出${extractedUrls.length}个有效代理URL`);
            logger.info(`协议分布统计: ${JSON.stringify(protocolStats, null, 2)}`);
            
            if (extractedUrls.length === 0) {
                throw new Error(`没有找到有效的代理URL。原始URLs: ${urls.slice(0, 3).join(', ')}...`);
            }

            // 打印前几个URL用于调试
            logger.info(`前3个有效代理URL: ${extractedUrls.slice(0, 3).join(', ')}`);

            // 创建订阅内容 - 只包含纯净的代理URL
            const subscriptionContent = extractedUrls.join('\n');
            const encodedContent = Buffer.from(subscriptionContent).toString('base64');

            // 保存文件
            const subscriptionFile = path.join(config.staticDir, 'subscription.txt');
            const rawFile = path.join(config.staticDir, 'raw.txt');

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
                
                let clashContent: string;
                
                // 首先尝试直接使用订阅内容转换（避免网络访问问题）
                try {
                    // 使用原始的订阅内容（非base64编码）
                    logger.info(`开始直接内容转换，内容长度: ${subscriptionContent.length} 字符`);
                    logger.info(`内容协议统计: ${JSON.stringify(protocolStats, null, 2)}`);
                    
                    clashContent = await this.subconverterService.convertToClashByContent(subscriptionContent);
                    
                    // 验证转换结果
                    if (clashContent && clashContent.includes('proxies:')) {
                        const proxyMatches = clashContent.match(/- name:/g);
                        const proxyCount = proxyMatches ? proxyMatches.length : 0;
                        logger.info(`使用订阅内容直接转换成功，生成 ${proxyCount} 个代理节点`);
                        
                        // 详细分析转换结果
                        const lines = clashContent.split('\n');
                        const outputProtocols: { [key: string]: number } = {};
                        
                        for (const line of lines) {
                            const trimmedLine = line.trim();
                            if (trimmedLine.startsWith('type:')) {
                                const type = trimmedLine.replace('type:', '').trim();
                                outputProtocols[type] = (outputProtocols[type] || 0) + 1;
                            }
                        }
                        
                        logger.info(`Clash输出协议分布: ${JSON.stringify(outputProtocols, null, 2)}`);
                        
                        // 检查是否所有协议都被转换
                        const totalInputNodes = Object.values(protocolStats).reduce((sum, count) => sum + count, 0);
                        if (proxyCount < totalInputNodes) {
                            logger.warn(`转换节点数量不匹配: 输入 ${totalInputNodes} 个，输出 ${proxyCount} 个`);
                            logger.warn(`输入协议: ${JSON.stringify(protocolStats)}`);
                            logger.warn(`输出协议: ${JSON.stringify(outputProtocols)}`);
                            
                            // 检查哪些协议可能被忽略
                            for (const [inputProtocol, inputCount] of Object.entries(protocolStats)) {
                                const found = Object.keys(outputProtocols).some(outputType => 
                                    outputType.toLowerCase().includes(inputProtocol.toLowerCase()) ||
                                    inputProtocol.toLowerCase().includes(outputType.toLowerCase())
                                );
                                
                                if (!found) {
                                    logger.error(`协议 ${inputProtocol} (${inputCount}个) 可能未被转换或不受支持`);
                                }
                            }
                            
                            // 输出部分转换内容用于调试
                            logger.warn(`Clash配置预览 (前1000字符): ${clashContent.substring(0, 1000)}`);
                        }
                    } else {
                        throw new Error('转换结果不包含有效的代理配置');
                    }
                } catch (contentError: any) {
                    logger.warn(`直接内容转换失败: ${contentError.message}，尝试使用URL方式`);
                    logger.warn(`输入内容预览: ${subscriptionContent.substring(0, 200)}...`);
                    
                    // 如果直接内容转换失败，回退到 URL 方式
                    // 优先使用 Nginx 代理端口（通常可用）
                    const proxyPort = process.env.NGINX_PROXY_PORT || '3888';
                    const externalHost = process.env.EXTERNAL_HOST || 'localhost';
                    let subscriptionUrl = `http://${externalHost}:${proxyPort}/subscription.txt`;
                    
                    try {
                        const axios = require('axios');
                        await axios.get(subscriptionUrl, { timeout: 3000 });
                        logger.info(`使用外部代理URL: ${subscriptionUrl}`);
                    } catch (proxyError: any) {
                        // 如果代理端口也不行，尝试原来的静态文件端口
                        const localSubscriptionUrl = `http://localhost:${config.nginxPort}/subscription.txt`;
                        try {
                            const axios2 = require('axios');
                            await axios2.get(localSubscriptionUrl, { timeout: 3000 });
                            subscriptionUrl = localSubscriptionUrl;
                            logger.info(`回退到本地静态URL: ${subscriptionUrl}`);
                        } catch (localError: any) {
                            logger.warn(`代理端口错误: ${proxyError.message}, 本地端口错误: ${localError.message}`);
                            logger.info(`使用外部代理URL: ${subscriptionUrl}`);
                        }
                    }
                    
                    clashContent = await this.subconverterService.convertToClash(subscriptionUrl);
                }
                
                if (!clashContent || clashContent.trim().length === 0) {
                    throw new Error('转换返回空内容');
                }
                
                const clashFile = path.join(config.staticDir, config.clashFilename);
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
                message: `订阅更新成功，共 ${extractedUrls.length} 个节点${clashGenerated ? '' : ' (Clash生成失败)'}`,
                timestamp: new Date().toISOString(),
                nodesCount: extractedUrls.length,
                clashGenerated,
                backupCreated: backupFile,
                warnings: errors.length > 0 ? errors : undefined,
                errors: clashError ? [`Clash生成失败: ${clashError}`] : undefined
            };

            logger.info(`订阅更新完成: ${extractedUrls.length} 个节点, Clash生成: ${clashGenerated}`);
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
        const clashFile = path.join(config.staticDir, config.clashFilename);
        const rawFile = path.join(config.staticDir, 'raw.txt');

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
            // 如果是raw.txt文件不存在，尝试创建默认文件
            if (filename === 'raw.txt') {
                await this.createDefaultRawFile();
                logger.info(`已创建默认的 ${filename} 文件`);
            } else {
                throw new Error(`文件 ${filename} 不存在`);
            }
        }

        return await fs.readFile(filePath);
    }

    /**
     * 创建默认的raw.txt文件
     */
    private async createDefaultRawFile(): Promise<void> {
        const filePath = path.join(config.staticDir, 'raw.txt');
        const defaultContent = `# 原始订阅链接文件
# 请在此添加你的订阅链接，每行一个
# 示例:
# https://example.com/subscription1
# https://example.com/subscription2

`;
        
        await fs.ensureDir(config.staticDir);
        await fs.writeFile(filePath, defaultContent, 'utf8');
        logger.info(`已创建默认的raw.txt文件: ${filePath}`);
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
            const clashFile = path.join(config.staticDir, config.clashFilename);
            
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

            // 3. 检查订阅 URL 访问（测试多个端点）
            const localSubscriptionUrl = `http://localhost:${config.nginxPort}/subscription.txt`;
            const proxyPort = process.env.NGINX_PROXY_PORT || '3888';
            const externalHost = process.env.EXTERNAL_HOST || 'localhost';
            const externalSubscriptionUrl = `http://${externalHost}:${proxyPort}/subscription.txt`;
            
            diagnosis.checks.localSubscriptionUrl = localSubscriptionUrl;
            diagnosis.checks.externalSubscriptionUrl = externalSubscriptionUrl;
            
            // 测试本地 URL
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
            
            // 测试外部代理 URL
            try {
                const axios = require('axios');
                const response = await axios.get(externalSubscriptionUrl, { timeout: 5000 });
                diagnosis.checks.externalSubscriptionAccessible = true;
                diagnosis.checks.externalSubscriptionStatus = response.status;
                diagnosis.checks.externalSubscriptionContentLength = response.data ? response.data.length : 0;
            } catch (error: any) {
                diagnosis.checks.externalSubscriptionAccessible = false;
                diagnosis.checks.externalSubscriptionError = error.message;
            }

            // 4. 如果 subconverter 可用，尝试转换
            if (diagnosis.checks.subconverterHealthy) {
                // 优先使用外部代理 URL 进行测试
                const testUrl = diagnosis.checks.externalSubscriptionAccessible ? 
                    externalSubscriptionUrl : localSubscriptionUrl;
                
                try {
                    const clashContent = await this.subconverterService.convertToClash(testUrl);
                    diagnosis.checks.conversionTest = {
                        success: true,
                        testUrl: testUrl,
                        contentLength: clashContent ? clashContent.length : 0,
                        hasContent: clashContent && clashContent.trim().length > 0
                    };
                } catch (error: any) {
                    diagnosis.checks.conversionTest = {
                        success: false,
                        testUrl: testUrl,
                        error: error.message
                    };
                    
                    // 如果URL转换失败，尝试直接内容转换
                    if (diagnosis.checks.subscriptionFileExists) {
                        try {
                            const rawFile = path.join(config.staticDir, 'raw.txt');
                            if (await fs.pathExists(rawFile)) {
                                const rawContent = await fs.readFile(rawFile, 'utf8');
                                const directClashContent = await this.subconverterService.convertToClashByContent(rawContent);
                                diagnosis.checks.directContentConversionTest = {
                                    success: true,
                                    contentLength: directClashContent ? directClashContent.length : 0,
                                    hasContent: directClashContent && directClashContent.trim().length > 0
                                };
                            }
                        } catch (directError: any) {
                            diagnosis.checks.directContentConversionTest = {
                                success: false,
                                error: directError.message
                            };
                        }
                    }
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

    /**
     * 测试单个节点或多个节点的转换
     */
    async testSingleNodeConversion(nodeContent: string): Promise<string> {
        return await this.subconverterService.convertToClashByContent(nodeContent);
    }

    /**
     * 检查subconverter服务详细状态
     */
    async checkSubconverterService(): Promise<{ healthy: boolean; url: string; version?: string; error?: string; endpoints?: any }> {
        const result: any = {
            healthy: false,
            url: config.subconverterUrl
        };

        try {
            // 1. 检查基本健康状态
            const healthCheck = await this.subconverterService.checkHealth();
            if (!healthCheck) {
                result.error = '健康检查失败';
                return result;
            }

            // 2. 尝试获取版本信息
            try {
                result.version = await this.subconverterService.getVersion();
            } catch (versionError: any) {
                result.versionError = versionError.message;
            }

            // 3. 测试不同的端点
            const axios = require('axios');
            const endpoints = {
                '/version': { method: 'GET', description: '版本信息' },
                '/sub': { method: 'GET', description: '订阅转换' },
                '/': { method: 'GET', description: '根路径' }
            };

            result.endpoints = {};

            for (const [path, info] of Object.entries(endpoints)) {
                try {
                    const response = await axios({
                        method: info.method,
                        url: `${config.subconverterUrl}${path}`,
                        timeout: 5000,
                        validateStatus: (status: number) => status < 500 // 接受所有非5xx错误
                    });

                    result.endpoints[path] = {
                        status: response.status,
                        accessible: true,
                        description: info.description
                    };
                } catch (error: any) {
                    result.endpoints[path] = {
                        status: error.response?.status || 'ERROR',
                        accessible: false,
                        error: error.message,
                        description: info.description
                    };
                }
            }

            // 4. 检查是否所有必要端点都可访问
            const requiredEndpoints = ['/version', '/sub'];
            const accessibleRequired = requiredEndpoints.filter(endpoint => 
                result.endpoints[endpoint]?.accessible
            );

            if (accessibleRequired.length === requiredEndpoints.length) {
                result.healthy = true;
            } else {
                result.error = `必要端点不可访问: ${requiredEndpoints.filter(ep => !result.endpoints[ep]?.accessible).join(', ')}`;
            }

        } catch (error: any) {
            result.error = error.message;
        }

        return result;
    }
}