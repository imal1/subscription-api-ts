import axios, { AxiosResponse } from 'axios';
import { config } from '@/config';
import { logger } from '@/utils/logger';

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
                timeout: 5000 
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
                timeout: 5000 
            });
            return response.data || 'Unknown';
        } catch (error) {
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