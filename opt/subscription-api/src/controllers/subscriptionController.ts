import { Request, Response } from 'express';
import { SubscriptionService } from '@/services/subscriptionService';
import { SingBoxService } from '@/services/singBoxService';
import { config } from '@/config';
import { logger } from '@/utils/logger';
import { ApiResponse, ConfigUpdateRequest } from '@/types';

export class SubscriptionController {
    private subscriptionService: SubscriptionService;
    private singBoxService: SingBoxService;

    constructor() {
        this.subscriptionService = SubscriptionService.getInstance();
        this.singBoxService = SingBoxService.getInstance();
    }

    /**
     * 首页 - API文档
     */
    index = (req: Request, res: Response): void => {
        const response: ApiResponse = {
            success: true,
            data: {
                name: 'Subscription API',
                version: '1.0.0',
                description: 'TypeScript订阅转换API服务',
                author: 'imal1',
                timestamp: new Date().toISOString(),
                endpoints: {
                    'GET /': 'API文档',
                    'POST /api/update': '更新订阅',
                    'GET /api/status': '获取状态',
                    'GET /subscription.txt': '获取Base64编码的订阅',
                    'GET /clash.yaml': '获取Clash配置',
                    'GET /raw.txt': '获取原始链接',
                    'GET /api/configs': '获取可用配置列表',
                    'POST /api/configs': '更新配置列表',
                    'GET /health': '健康检查'
                }
            },
            timestamp: new Date().toISOString()
        };

        res.json(response);
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
            const content = await this.subscriptionService.getFileContent('clash.yaml');
            
            res.setHeader('Content-Type', 'text/yaml; charset=utf-8');
            res.setHeader('Content-Disposition', 'attachment; filename="clash.yaml"');
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
            const content = await this.subscriptionService.getFileContent('raw_links.txt');
            
            res.setHeader('Content-Type', 'text/plain; charset=utf-8');
            res.setHeader('Content-Disposition', 'attachment; filename="raw_links.txt"');
            res.send(content);
        } catch (error: any) {
            res.status(404).send(`获取原始链接失败: ${error.message}`);
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
}