import axios, { AxiosResponse } from 'axios';
import { config } from '../config';
import { logger } from '../utils/logger';

export class SubconverterService {
    private static instance: SubconverterService;
    
    public static getInstance(): SubconverterService {
        if (!SubconverterService.instance) {
            SubconverterService.instance = new SubconverterService();
        }
        return SubconverterService.instance;
    }

    /**
     * 检查subconverter服务状态
     */
    async checkHealth(): Promise<boolean> {
        try {
            const response = await axios.get(`${config.subconverterUrl}/version`, { 
                timeout: config.requestTimeout 
            });
            return response.status === 200;
        } catch (error) {
            logger.error('Subconverter健康检查失败:', error);
            return false;
        }
    }

    /**
     * 获取subconverter版本信息
     */
    async getVersion(): Promise<string> {
        try {
            const response = await axios.get(`${config.subconverterUrl}/version`, { 
                timeout: config.requestTimeout 
            });
            return response.data || 'Unknown';
        } catch (error: any) {
            logger.error('获取Subconverter版本失败:', error);
            throw new Error('获取Subconverter版本失败');
        }
    }

    /**
     * 转换订阅为Clash格式
     */
    async convertToClash(subscriptionUrl: string, customConfig?: string): Promise<string> {
        try {
            const params = new URLSearchParams({
                target: 'clash',
                url: subscriptionUrl
            });

            if (customConfig) {
                params.append('config', customConfig);
            }

            logger.info(`请求Clash转换: ${config.subconverterUrl}/sub?${params.toString()}`);

            const response: AxiosResponse<string> = await axios.get(
                `${config.subconverterUrl}/sub`,
                {
                    params: Object.fromEntries(params),
                    timeout: config.requestTimeout,
                    responseType: 'text'
                }
            );

            if (response.status === 200 && response.data) {
                logger.info('Clash配置转换成功');
                return response.data;
            } else {
                throw new Error(`转换失败: HTTP ${response.status}`);
            }
        } catch (error: any) {
            logger.error('Clash转换失败:', error);
            if (error.response) {
                throw new Error(`转换失败: ${error.response.status} - ${error.response.data}`);
            } else if (error.request) {
                throw new Error('转换请求超时或网络错误');
            } else {
                throw new Error(`转换异常: ${error.message}`);
            }
        }
    }

    /**
     * 使用订阅内容直接转换为Clash格式（通过POST请求）
     */
    async convertToClashByContent(subscriptionContent: string, customConfig?: string): Promise<string> {
        try {
            const params = new URLSearchParams({
                target: 'clash'
            });

            if (customConfig) {
                params.append('config', customConfig);
            }

            // 验证订阅内容
            const lines = subscriptionContent.split('\n').filter(line => line.trim().length > 0);
            logger.info(`准备转换的订阅内容: ${lines.length} 行`);
            logger.info(`前3行内容预览: ${lines.slice(0, 3).join(' | ')}`);

            if (lines.length === 0) {
                throw new Error('订阅内容为空');
            }

            logger.info(`通过内容请求Clash转换: ${config.subconverterUrl}/sub`);

            // 使用 POST 请求直接发送订阅内容
            const response: AxiosResponse<string> = await axios.post(
                `${config.subconverterUrl}/sub?${params.toString()}`,
                subscriptionContent,
                {
                    headers: {
                        'Content-Type': 'text/plain; charset=utf-8'
                    },
                    timeout: config.requestTimeout,
                    responseType: 'text'
                }
            );

            if (response.status === 200 && response.data) {
                logger.info(`Clash配置转换成功（通过内容），长度: ${response.data.length} 字符`);
                
                // 检查返回内容是否是有效的YAML
                if (response.data.includes('proxies:') || response.data.includes('proxy-groups:')) {
                    return response.data;
                } else {
                    logger.warn(`转换结果可能无效，内容预览: ${response.data.substring(0, 200)}`);
                    throw new Error('转换结果不包含有效的Clash配置');
                }
            } else {
                throw new Error(`转换失败: HTTP ${response.status}`);
            }
        } catch (error: any) {
            logger.error('Clash转换失败（通过内容）:', error);
            if (error.response) {
                logger.error(`响应状态: ${error.response.status}`);
                logger.error(`响应数据: ${error.response.data}`);
                throw new Error(`转换失败: ${error.response.status} - ${error.response.data}`);
            } else if (error.request) {
                throw new Error('转换请求超时或网络错误');
            } else {
                throw new Error(`转换异常: ${error.message}`);
            }
        }
    }

    /**
     * 转换订阅为其他格式
     */
    async convertTo(target: string, subscriptionUrl: string, customConfig?: string): Promise<string> {
        try {
            const params = new URLSearchParams({
                target,
                url: subscriptionUrl
            });

            if (customConfig) {
                params.append('config', customConfig);
            }

            const response: AxiosResponse<string> = await axios.get(
                `${config.subconverterUrl}/sub`,
                {
                    params: Object.fromEntries(params),
                    timeout: config.requestTimeout,
                    responseType: 'text'
                }
            );

            if (response.status === 200) {
                return response.data;
            } else {
                throw new Error(`转换失败: HTTP ${response.status}`);
            }
        } catch (error: any) {
            logger.error(`${target}转换失败:`, error);
            throw new Error(`转换为${target}格式失败: ${error.message}`);
        }
    }
}