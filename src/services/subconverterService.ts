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
                url: subscriptionUrl,
                insert: 'false', // 不插入默认策略组
                config: customConfig || '', // 使用自定义配置
                emoji: 'true', // 启用emoji
                list: 'false', // 不返回节点列表
                sort: 'false' // 不排序节点
            });

            // 移除空值参数
            Array.from(params.entries()).forEach(([key, value]) => {
                if (!value) {
                    params.delete(key);
                }
            });

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
     * 使用订阅内容直接转换为Clash格式
     */
    async convertToClashByContent(subscriptionContent: string, customConfig?: string): Promise<string> {
        try {
            // 验证订阅内容
            const lines = subscriptionContent.split('\n').filter(line => line.trim().length > 0);
            logger.info(`准备转换的订阅内容: ${lines.length} 行`);
            logger.info(`前3行内容预览: ${lines.slice(0, 3).join(' | ')}`);

            if (lines.length === 0) {
                throw new Error('订阅内容为空');
            }

            // 方法1: 尝试使用data参数的GET请求（推荐方式）
            try {
                return await this.convertByDataParam(subscriptionContent, customConfig);
            } catch (dataError: any) {
                logger.warn(`Data参数方式转换失败: ${dataError.message}，尝试POST方式`);
                
                // 方法2: 使用POST请求
                return await this.convertByPost(subscriptionContent, customConfig);
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
     * 使用data参数的GET请求转换
     */
    private async convertByDataParam(subscriptionContent: string, customConfig?: string): Promise<string> {
        // 将内容进行base64编码
        const base64Content = Buffer.from(subscriptionContent).toString('base64');
        
        // 使用最简单的参数组合
        const params: any = {
            target: 'clash',
            data: base64Content
        };

        // 只有在提供了自定义配置时才添加config参数
        if (customConfig) {
            params.config = customConfig;
        }

        logger.info(`Data参数方式请求Clash转换: ${config.subconverterUrl}/sub`);
        logger.info(`请求参数: target=${params.target}, data长度=${base64Content.length}, config=${params.config || '默认'}`);

        const response: AxiosResponse<string> = await axios.get(
            `${config.subconverterUrl}/sub`,
            {
                params,
                headers: {
                    'User-Agent': 'Subscription-API-TS/1.0'
                },
                timeout: config.requestTimeout,
                responseType: 'text'
            }
        );

        return this.validateClashResponse(response);
    }

    /**
     * 使用POST请求转换
     */
    private async convertByPost(subscriptionContent: string, customConfig?: string): Promise<string> {
        // 使用最简单的参数组合
        const params: any = {
            target: 'clash'
        };

        // 只有在提供了自定义配置时才添加config参数
        if (customConfig) {
            params.config = customConfig;
        }

        const queryString = new URLSearchParams(params).toString();
        const url = `${config.subconverterUrl}/sub${queryString ? '?' + queryString : ''}`;

        logger.info(`POST方式请求Clash转换: ${url}`);
        logger.info(`请求体长度: ${subscriptionContent.length} 字符`);

        const response: AxiosResponse<string> = await axios.post(
            url,
            subscriptionContent,
            {
                headers: {
                    'Content-Type': 'text/plain; charset=utf-8',
                    'User-Agent': 'Subscription-API-TS/1.0'
                },
                timeout: config.requestTimeout,
                responseType: 'text'
            }
        );

        return this.validateClashResponse(response);
    }

    /**
     * 验证Clash转换响应
     */
    private validateClashResponse(response: AxiosResponse<string>): string {
        if (response.status === 200 && response.data) {
            logger.info(`Clash配置转换成功，长度: ${response.data.length} 字符`);
            
            // 检查返回内容是否是有效的YAML
            if (response.data.includes('proxies:') || response.data.includes('proxy-groups:')) {
                // 分析转换结果
                const proxyMatches = response.data.match(/- name:/g);
                const proxyCount = proxyMatches ? proxyMatches.length : 0;
                logger.info(`转换结果包含 ${proxyCount} 个代理节点`);
                
                return response.data;
            } else {
                logger.warn(`转换结果可能无效，内容预览: ${response.data.substring(0, 200)}`);
                throw new Error('转换结果不包含有效的Clash配置');
            }
        } else {
            throw new Error(`转换失败: HTTP ${response.status}`);
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

    /**
     * 测试 subconverter 的不同调用方式
     */
    async testSubconverterMethods(testContent: string): Promise<any> {
        const results = {
            data_get: null,
            post_body: null,
            url_get: null,
            simple_get: null
        };

        const base64Content = Buffer.from(testContent).toString('base64');

        // 方法1: data参数 GET 请求
        try {
            logger.info('测试方法1: data参数 GET 请求');
            const response = await axios.get(`${config.subconverterUrl}/sub`, {
                params: { target: 'clash', data: base64Content },
                timeout: 5000,
                responseType: 'text'
            });
            results.data_get = { status: response.status, dataLength: response.data.length, preview: response.data.substring(0, 100) };
        } catch (error: any) {
            results.data_get = { error: error.response?.status || error.message };
        }

        // 方法2: POST 请求
        try {
            logger.info('测试方法2: POST 请求');
            const response = await axios.post(`${config.subconverterUrl}/sub?target=clash`, testContent, {
                headers: { 'Content-Type': 'text/plain' },
                timeout: 5000,
                responseType: 'text'
            });
            results.post_body = { status: response.status, dataLength: response.data.length, preview: response.data.substring(0, 100) };
        } catch (error: any) {
            results.post_body = { error: error.response?.status || error.message };
        }

        // 方法3: url参数 GET 请求（如果有在线链接的话）
        try {
            logger.info('测试方法3: url参数 GET 请求');
            const response = await axios.get(`${config.subconverterUrl}/sub`, {
                params: { target: 'clash', url: 'http://example.com/test' },
                timeout: 5000,
                responseType: 'text'
            });
            results.url_get = { status: response.status, dataLength: response.data.length, preview: response.data.substring(0, 100) };
        } catch (error: any) {
            results.url_get = { error: error.response?.status || error.message };
        }

        // 方法4: 简单的 GET 请求，不带任何参数
        try {
            logger.info('测试方法4: 简单的 GET 请求');
            const response = await axios.get(`${config.subconverterUrl}/sub`, {
                timeout: 5000,
                responseType: 'text'
            });
            results.simple_get = { status: response.status, dataLength: response.data.length, preview: response.data.substring(0, 100) };
        } catch (error: any) {
            results.simple_get = { error: error.response?.status || error.message };
        }

        return results;
    }
}