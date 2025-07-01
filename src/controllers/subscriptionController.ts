import { Request, Response } from 'express';
import { SubscriptionService } from '../services/subscriptionService';
import { SingBoxService } from '../services/singBoxService';
import { config } from '../config';
import { logger } from '../utils/logger';
import { ApiResponse, ConfigUpdateRequest } from '../types';

export class SubscriptionController {
    private subscriptionService: SubscriptionService;
    private singBoxService: SingBoxService;

    constructor() {
        this.subscriptionService = SubscriptionService.getInstance();
        this.singBoxService = SingBoxService.getInstance();
    }

    /**
     * 首页 - 重定向到 Dashboard
     */
    index = (req: Request, res: Response): void => {
        // 检查请求头，如果是API请求则返回JSON，否则重定向到dashboard
        const acceptHeader = req.headers.accept || '';
        const isApiRequest = acceptHeader.includes('application/json') || req.query.format === 'json';
        
        if (isApiRequest) {
            // API 请求，返回 JSON 格式的信息
            const response: ApiResponse = {
                success: true,
                data: {
                    name: 'Subscription API',
                    version: '1.0.0',
                    description: 'TypeScript订阅转换API服务',
                    author: 'imal1',
                    timestamp: new Date().toISOString(),
                    dashboard: '/dashboard/',
                    endpoints: {
                        'GET /api/update': '更新订阅',
                        'GET /api/status': '获取状态',
                        'GET /api/diagnose/clash': '诊断Clash生成问题',
                        'GET /api/diagnose/subconverter': '检查Subconverter服务状态',
                        'GET /api/test/protocols': '测试多协议转换',
                        'GET /subscription.txt': '获取Base64编码的订阅',
                        [`GET /${config.clashFilename}`]: '获取Clash配置',
                        'GET /raw.txt': '获取原始链接',
                        'GET /api/configs': '获取可用配置列表',
                        'POST /api/configs': '更新配置列表',
                        'GET /health': '健康检查'
                    }
                },
                timestamp: new Date().toISOString()
            };
            res.json(response);
        } else {
            // 浏览器请求，重定向到 dashboard
            res.redirect('/dashboard/');
        }
    };

    /**
     * 更新订阅
     */
    updateSubscription = async (req: Request, res: Response): Promise<void> => {
        try {
            const result = await this.subscriptionService.updateSubscription();
            
            const response: ApiResponse = {
                success: true,
                data: result,
                message: '订阅更新成功',
                timestamp: new Date().toISOString()
            };

            res.json(response);
        } catch (error: any) {
            logger.error('更新订阅API错误:', error);
            
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };

    /**
     * 获取状态
     */
    getStatus = async (req: Request, res: Response): Promise<void> => {
        try {
            const status = await this.subscriptionService.getStatus();
            
            const response: ApiResponse = {
                success: true,
                data: status,
                timestamp: new Date().toISOString()
            };

            res.json(response);
        } catch (error: any) {
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };

    /**
     * 获取配置列表
     */
    getConfigs = (req: Request, res: Response): void => {
        const response: ApiResponse = {
            success: true,
            data: {
                configs: config.singBoxConfigs,
                description: '当前配置的sing-box节点名称列表',
                count: config.singBoxConfigs.length
            },
            timestamp: new Date().toISOString()
        };

        res.json(response);
    };

    /**
     * 更新配置列表
     */
    updateConfigs = (req: Request, res: Response): void => {
        try {
            const { configs }: ConfigUpdateRequest = req.body;
            
            if (!Array.isArray(configs)) {
                const response: ApiResponse = {
                    success: false,
                    error: '请提供有效的configs数组',
                    timestamp: new Date().toISOString()
                };
                
                res.status(400).json(response);
                return;
            }

            if (configs.length === 0) {
                const response: ApiResponse = {
                    success: false,
                    error: '配置列表不能为空',
                    timestamp: new Date().toISOString()
                };
                
                res.status(400).json(response);
                return;
            }

            // 更新配置
            config.singBoxConfigs = configs;
            logger.info(`配置列表已更新: ${JSON.stringify(configs)}`);

            const response: ApiResponse = {
                success: true,
                data: {
                    configs: config.singBoxConfigs,
                    count: config.singBoxConfigs.length
                },
                message: '配置列表更新成功',
                timestamp: new Date().toISOString()
            };

            res.json(response);
        } catch (error: any) {
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };

    /**
     * 获取订阅文件
     */
    getSubscriptionFile = async (req: Request, res: Response): Promise<void> => {
        try {
            const content = await this.subscriptionService.getFileContent('subscription.txt');
            
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.setHeader('Content-Disposition', 'attachment; filename="subscription.txt"');
            res.send(content);
        } catch (error: any) {
            res.status(404).send(`获取订阅文件失败: ${error.message}`);
        }
    };

    /**
     * 获取Clash配置文件
     */
    getClashFile = async (req: Request, res: Response): Promise<void> => {
        try {
            const content = await this.subscriptionService.getFileContent(config.clashFilename);
            
            res.setHeader('Content-Type', 'text/yaml; charset=utf-8');
            res.setHeader('Content-Disposition', `attachment; filename="${config.clashFilename}"`);
            res.send(content);
        } catch (error: any) {
            res.status(404).send(`获取Clash配置失败: ${error.message}`);
        }
    };

    /**
     * 获取原始链接文件
     */
    getRawFile = async (req: Request, res: Response): Promise<void> => {
        try {
            logger.info('尝试获取原始链接文件: raw.txt');
            const content = await this.subscriptionService.getFileContent('raw.txt');
            
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.setHeader('Content-Disposition', 'attachment; filename="raw.txt"');
            res.send(content);
            logger.info('成功返回原始链接文件');
        } catch (error: any) {
            logger.error(`获取原始链接文件失败: ${error.message}`, error);
            
            const response: ApiResponse = {
                success: false,
                error: `获取原始链接失败: ${error.message}`,
                message: '请确保 raw.txt 文件存在于数据目录中',
                timestamp: new Date().toISOString()
            };
            
            res.status(404).json(response);
        }
    };

    /**
     * 健康检查
     */
    healthCheck = async (req: Request, res: Response): Promise<void> => {
        try {
            const health = {
                status: 'healthy',
                timestamp: new Date().toISOString(),
                uptime: process.uptime(),
                memory: process.memoryUsage(),
                version: '1.0.0'
            };

            res.json(health);
        } catch (error: any) {
            res.status(503).json({
                status: 'unhealthy',
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
    };

    /**
     * 诊断Clash配置生成问题
     */
    diagnoseClash = async (req: Request, res: Response): Promise<void> => {
        try {
            const diagnosis = await this.subscriptionService.diagnoseClashGeneration();
            
            const response: ApiResponse = {
                success: true,
                data: diagnosis,
                message: 'Clash诊断完成',
                timestamp: new Date().toISOString()
            };

            res.json(response);
        } catch (error: any) {
            logger.error('Clash诊断API错误:', error);
            
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };

    /**
     * 测试多协议转换
     */
    testProtocolConversion = async (req: Request, res: Response): Promise<void> => {
        try {
            // 首先检查subconverter服务状态
            const subconverterHealthy = await this.subscriptionService.checkSubconverterService();
            if (!subconverterHealthy.healthy) {
                const response: ApiResponse = {
                    success: false,
                    error: `Subconverter服务不可用: ${subconverterHealthy.error}`,
                    message: '请检查subconverter服务配置和状态',
                    timestamp: new Date().toISOString()
                };
                res.status(503).json(response);
                return;
            }

            // 测试单个协议的转换效果
            const testNodes = [
                'vless://2df7ca47-b52d-4108-8db7-ca36049d7e83@104.234.37.101:43911?encryption=none&security=reality&flow=&type=h2&sni=aws.amazon.com&pbk=EMUKRSbFWEK8nju9E56Z4NsUrduOXZE7qtZwZRdOTwI&fp=chrome#test-vless',
                'hysteria2://23f75240-12d3-4fdb-8ea4-f1060b5ced8f@104.234.37.101:33911?alpn=h3&insecure=1#test-hysteria2',
                'trojan://6d483d0f-b61d-45d7-a37a-afb927367f18@104.234.37.101:55458?type=tcp&security=tls&allowInsecure=1#test-trojan',
                'tuic://3078f955-f4ab-481e-ac54-991582a0bde5:3078f955-f4ab-481e-ac54-991582a0bde5@104.234.37.101:13911?alpn=h3&allow_insecure=1&congestion_control=bbr#test-tuic'
            ];

            const results: any = {
                timestamp: new Date().toISOString(),
                subconverterStatus: subconverterHealthy,
                tests: []
            };

            // 测试每个协议单独转换
            for (const testNode of testNodes) {
                const protocol = testNode.split('://')[0];
                logger.info(`测试单独转换协议: ${protocol}`);
                
                try {
                    const clashContent = await this.subscriptionService.testSingleNodeConversion(testNode);
                    
                    const proxyMatches = clashContent.match(/- name:/g);
                    const proxyCount = proxyMatches ? proxyMatches.length : 0;
                    
                    // 分析输出协议类型
                    const lines = clashContent.split('\n');
                    let outputType = 'unknown';
                    for (const line of lines) {
                        const trimmedLine = line.trim();
                        if (trimmedLine.startsWith('type:')) {
                            outputType = trimmedLine.replace('type:', '').trim();
                            break;
                        }
                    }
                    
                    results.tests.push({
                        protocol,
                        input: testNode.substring(0, 100) + '...',
                        success: true,
                        proxyCount,
                        outputType,
                        contentLength: clashContent.length,
                        preview: clashContent.substring(0, 200) + '...'
                    });
                    
                    logger.info(`${protocol} 转换成功: ${proxyCount} 个节点，类型: ${outputType}`);
                } catch (error: any) {
                    results.tests.push({
                        protocol,
                        input: testNode.substring(0, 100) + '...',
                        success: false,
                        error: error.message,
                        errorDetails: error.stack
                    });
                    
                    logger.error(`${protocol} 转换失败: ${error.message}`);
                }
            }

            // 测试所有协议一起转换
            try {
                const allNodesContent = testNodes.join('\n');
                const allClashContent = await this.subscriptionService.testSingleNodeConversion(allNodesContent);
                
                const allProxyMatches = allClashContent.match(/- name:/g);
                const allProxyCount = allProxyMatches ? allProxyMatches.length : 0;
                
                // 分析所有输出协议类型
                const allLines = allClashContent.split('\n');
                const allOutputTypes: { [key: string]: number } = {};
                
                for (const line of allLines) {
                    const trimmedLine = line.trim();
                    if (trimmedLine.startsWith('type:')) {
                        const type = trimmedLine.replace('type:', '').trim();
                        allOutputTypes[type] = (allOutputTypes[type] || 0) + 1;
                    }
                }
                
                results.combinedTest = {
                    success: true,
                    inputCount: testNodes.length,
                    outputCount: allProxyCount,
                    outputTypes: allOutputTypes,
                    contentLength: allClashContent.length,
                    preview: allClashContent.substring(0, 500) + '...'
                };
                
                logger.info(`组合转换结果: ${allProxyCount} 个节点，类型分布: ${JSON.stringify(allOutputTypes)}`);
            } catch (error: any) {
                results.combinedTest = {
                    success: false,
                    error: error.message,
                    errorDetails: error.stack
                };
                
                logger.error(`组合转换失败: ${error.message}`);
            }

            const response: ApiResponse = {
                success: true,
                data: results,
                message: '多协议转换测试完成',
                timestamp: new Date().toISOString()
            };

            res.json(response);
        } catch (error: any) {
            logger.error('多协议测试API错误:', error);
            
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };

    /**
     * 检查subconverter服务状态
     */
    checkSubconverter = async (req: Request, res: Response): Promise<void> => {
        try {
            const status = await this.subscriptionService.checkSubconverterService();
            
            // 进行额外的 API 调用方式测试
            const testContent = 'trojan://password@server.com:443?security=tls&type=tcp#test';
            const subconverterService = new (await import('../services/subconverterService')).SubconverterService();
            const apiTests = await subconverterService.testSubconverterMethods(testContent);
            
            const response: ApiResponse = {
                success: status.healthy,
                data: {
                    basicStatus: status,
                    apiTests: apiTests
                },
                message: status.healthy ? 'Subconverter服务正常' : 'Subconverter服务异常',
                timestamp: new Date().toISOString()
            };

            res.status(status.healthy ? 200 : 503).json(response);
        } catch (error: any) {
            logger.error('检查Subconverter服务API错误:', error);
            
            const response: ApiResponse = {
                success: false,
                error: error.message,
                timestamp: new Date().toISOString()
            };

            res.status(500).json(response);
        }
    };
}