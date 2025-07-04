import axios from 'axios';
import * as fs from 'fs-extra';
import { execSync } from 'child_process';
import * as path from 'path';
import * as os from 'os';
import { logger } from '../utils/logger';
import { config } from '../config';

interface ProxyConfig {
    name: string;
    type: string;
    server: string;
    port: number;
    [key: string]: any;
}

interface MihomoVersionInfo {
    version: string;
    build_time: string;
    commit: string;
}

export class MihomoService {
    private static instance: MihomoService;
    private mihomoPath: string;
    private configPath: string;

    private constructor() {
        // 使用默认路径
        const basePath = path.join(os.homedir(), '.config', 'subscription', 'mihomo');
        this.mihomoPath = path.join(basePath, 'mihomo');
        this.configPath = path.join(basePath, 'config.yaml');
        
        // 确保目录存在
        fs.ensureDirSync(path.dirname(this.mihomoPath));
    }

    public static getInstance(): MihomoService {
        if (!MihomoService.instance) {
            MihomoService.instance = new MihomoService();
        }
        return MihomoService.instance;
    }

    /**
     * 检查本地 mihomo 是否可用
     */
    private async checkLocalMihomo(): Promise<boolean> {
        try {
            if (!fs.existsSync(this.mihomoPath)) {
                logger.error(`mihomo 二进制文件不存在: ${this.mihomoPath}`);
                logger.info('请确保已通过安装脚本安装 mihomo');
                return false;
            }

            // 尝试执行版本命令
            const result = execSync(`"${this.mihomoPath}" -v`, { 
                encoding: 'utf8',
                timeout: 5000 
            });
            
            logger.info(`本地 mihomo 版本: ${result.trim()}`);
            return true;
        } catch (error) {
            logger.error('检查本地 mihomo 失败:', error);
            return false;
        }
    }

    /**
     * 确保 mihomo 可用
     */
    public async ensureMihomoAvailable(): Promise<boolean> {
        try {
            return await this.checkLocalMihomo();
        } catch (error) {
            logger.error('检查 mihomo 可用性时发生错误:', error);
            return false;
        }
    }

    /**
     * 检查 mihomo 服务状态
     */
    public async checkHealth(): Promise<boolean> {
        try {
            return await this.ensureMihomoAvailable();
        } catch (error) {
            logger.error('mihomo 健康检查失败:', error);
            return false;
        }
    }

    /**
     * 获取 mihomo 版本信息
     */
    public async getVersion(): Promise<MihomoVersionInfo | null> {
        try {
            if (!await this.ensureMihomoAvailable()) {
                throw new Error('mihomo 不可用');
            }

            const result = execSync(`"${this.mihomoPath}" -v`, { 
                encoding: 'utf8',
                timeout: 5000 
            });

            // 解析版本输出
            const lines = result.trim().split('\n');
            const versionLine = lines.find(line => line.includes('Mihomo'));
            
            if (versionLine) {
                const versionMatch = versionLine.match(/Mihomo\s+(\S+)/);
                if (versionMatch) {
                    return {
                        version: versionMatch[1],
                        build_time: new Date().toISOString(),
                        commit: 'unknown'
                    };
                }
            }

            return {
                version: 'unknown',
                build_time: new Date().toISOString(),
                commit: 'unknown'
            };
        } catch (error) {
            logger.error('获取 mihomo 版本失败:', error);
            return null;
        }
    }

    /**
     * 解析代理 URL 并转换为 Clash 配置
     */
    public async convertToClash(subscriptionUrl: string): Promise<string> {
        logger.info(`开始使用 mihomo 转换订阅: ${subscriptionUrl}`);

        try {
            // 确保 mihomo 可用
            if (!await this.ensureMihomoAvailable()) {
                throw new Error('mihomo 服务不可用');
            }

            // 下载订阅内容
            const subscriptionContent = await this.fetchSubscriptionContent(subscriptionUrl);
            
            // 转换为 Clash 配置
            return await this.convertContentToClash(subscriptionContent);
        } catch (error) {
            logger.error('mihomo 转换失败:', error);
            throw error;
        }
    }

    /**
     * 通过内容转换为 Clash 配置
     */
    public async convertToClashByContent(content: string): Promise<string> {
        logger.info('开始使用 mihomo 转换订阅内容');
        logger.debug(`内容长度: ${content.length} 字符`);

        try {
            // 确保 mihomo 可用
            if (!await this.ensureMihomoAvailable()) {
                throw new Error('mihomo 服务不可用');
            }

            return await this.convertContentToClash(content);
        } catch (error) {
            logger.error('mihomo 内容转换失败:', {
                message: error instanceof Error ? error.message : String(error),
                stack: error instanceof Error ? error.stack : undefined
            });
            throw error;
        }
    }

    /**
     * 获取订阅内容
     */
    private async fetchSubscriptionContent(url: string): Promise<string> {
        try {
            const response = await axios.get(url, {
                timeout: config.requestTimeout,
                headers: {
                    'User-Agent': 'subscription-api-ts/1.0.0'
                }
            });

            return response.data;
        } catch (error) {
            logger.error('获取订阅内容失败:', error);
            throw new Error('获取订阅内容失败');
        }
    }

    /**
     * 将订阅内容转换为 Clash 配置
     */
    private async convertContentToClash(content: string): Promise<string> {
        try {
            logger.info('开始解析代理节点...');
            
            // 解析代理节点
            const proxies = this.parseProxies(content);
            
            logger.info(`解析完成，发现 ${proxies.length} 个代理节点`);
            
            if (proxies.length === 0) {
                logger.warn('未找到有效的代理节点');
                throw new Error('未找到有效的代理节点');
            }

            logger.info('开始生成 Clash 配置...');
            
            // 生成 Clash 配置
            const clashConfig = this.generateClashConfig(proxies);
            
            logger.info(`Clash 配置生成完成，长度: ${clashConfig.length} 字符`);
            
            // 使用 mihomo 验证配置
            logger.info('开始验证生成的配置...');
            await this.validateClashConfig(clashConfig);
            logger.info('配置验证通过');

            logger.info(`成功转换 ${proxies.length} 个代理节点`);
            return clashConfig;
        } catch (error) {
            logger.error('转换内容为 Clash 配置失败:', {
                message: error instanceof Error ? error.message : String(error),
                stack: error instanceof Error ? error.stack : undefined
            });
            throw error;
        }
    }

    /**
     * 解析代理节点
     */
    private parseProxies(content: string): ProxyConfig[] {
        const proxies: ProxyConfig[] = [];
        const lines = content.split('\n').filter(line => line.trim());

        logger.info(`开始解析订阅内容，总行数: ${lines.length}`);
        
        // 记录支持的协议类型
        const supportedProtocols = ['vmess://', 'vless://', 'trojan://', 'hysteria2://', 'hy2://', 'tuic://', 'ss://'];
        logger.debug(`支持的协议: ${supportedProtocols.join(', ')}`);

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line) continue;

            try {
                const proxy = this.parseProxyLine(line);
                if (proxy) {
                    proxies.push(proxy);
                    logger.debug(`成功解析第 ${i + 1} 行: ${proxy.name} (${proxy.type})`);
                } else {
                    // 记录未识别的协议
                    const protocol = line.split('://')[0];
                    logger.debug(`第 ${i + 1} 行未识别协议: ${protocol}://...`);
                }
            } catch (error) {
                logger.warn(`解析第 ${i + 1} 行失败: ${line.substring(0, 50)}...`, {
                    error: error instanceof Error ? error.message : String(error)
                });
            }
        }

        logger.info(`解析完成，成功解析 ${proxies.length}/${lines.length} 个节点`);
        return proxies;
    }

    /**
     * 解析单个代理行
     */
    private parseProxyLine(line: string): ProxyConfig | null {
        try {
            // 处理各种协议
            if (line.startsWith('vmess://')) {
                return this.parseVmess(line);
            } else if (line.startsWith('vless://')) {
                return this.parseVless(line);
            } else if (line.startsWith('trojan://')) {
                return this.parseTrojan(line);
            } else if (line.startsWith('hysteria2://') || line.startsWith('hy2://')) {
                return this.parseHysteria2(line);
            } else if (line.startsWith('tuic://')) {
                return this.parseTuic(line);
            } else if (line.startsWith('ss://')) {
                return this.parseShadowsocks(line);
            }
            
            return null;
        } catch (error) {
            logger.warn(`解析代理行失败: ${line}`, error);
            return null;
        }
    }

    /**
     * 解析 VMess 协议
     */
    private parseVmess(url: string): ProxyConfig | null {
        try {
            const data = url.replace('vmess://', '');
            const config = JSON.parse(Buffer.from(data, 'base64').toString());

            return {
                name: config.ps || `vmess-${config.add}`,
                type: 'vmess',
                server: config.add,
                port: parseInt(config.port),
                uuid: config.id,
                alterId: parseInt(config.aid) || 0,
                cipher: config.scy || 'auto',
                network: config.net || 'tcp',
                tls: config.tls === 'tls',
                'skip-cert-verify': true,
                ...(config.net === 'ws' && {
                    'ws-opts': {
                        path: config.path || '/',
                        headers: config.host ? { Host: config.host } : {}
                    }
                }),
                ...(config.net === 'h2' && {
                    'h2-opts': {
                        host: config.host ? [config.host] : [],
                        path: config.path || '/'
                    }
                }),
                ...(config.net === 'grpc' && {
                    'grpc-opts': {
                        'grpc-service-name': config.path || ''
                    }
                })
            };
        } catch (error) {
            logger.warn('解析 VMess 失败:', error);
            return null;
        }
    }

    /**
     * 解析 VLESS 协议
     */
    private parseVless(url: string): ProxyConfig | null {
        try {
            const urlObj = new URL(url);
            const params = new URLSearchParams(urlObj.search);

            const config: ProxyConfig = {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `vless-${urlObj.hostname}`,
                type: 'vless',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                uuid: urlObj.username,
                'skip-cert-verify': true,
            };

            // 处理 flow
            const flow = params.get('flow');
            if (flow) {
                config.flow = flow;
            }

            // 处理传输类型
            const networkType = params.get('type') || 'tcp';
            config.network = networkType;

            // 处理安全设置
            const security = params.get('security');
            if (security === 'tls' || security === 'reality') {
                config.tls = true;
                
                if (security === 'reality') {
                    config['reality-opts'] = {
                        'public-key': params.get('pbk') || '',
                        'short-id': params.get('sid') || ''
                    };
                }
                
                // 处理 SNI
                const sni = params.get('sni');
                if (sni) {
                    config.sni = sni;
                }
            }

            // 处理不同的传输类型
            if (networkType === 'ws') {
                config['ws-opts'] = {
                    path: params.get('path') || '/',
                    headers: params.get('host') ? { Host: params.get('host')! } : {}
                };
            } else if (networkType === 'h2') {
                config['h2-opts'] = {
                    host: params.get('host') ? [params.get('host')!] : [],
                    path: params.get('path') || '/'
                };
            } else if (networkType === 'grpc') {
                config['grpc-opts'] = {
                    'grpc-service-name': params.get('serviceName') || params.get('path') || ''
                };
            }

            return config;
        } catch (error) {
            logger.warn('解析 VLESS 失败:', error);
            return null;
        }
    }

    /**
     * 解析 Trojan 协议
     */
    private parseTrojan(url: string): ProxyConfig | null {
        try {
            const urlObj = new URL(url);
            const params = new URLSearchParams(urlObj.search);

            const config: ProxyConfig = {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `trojan-${urlObj.hostname}`,
                type: 'trojan',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                password: urlObj.username,
                'skip-cert-verify': params.get('allowInsecure') === '1',
            };

            // 处理 SNI
            const sni = params.get('sni');
            if (sni) {
                config.sni = sni;
            } else {
                config.sni = urlObj.hostname;
            }

            // 处理传输类型
            const networkType = params.get('type');
            if (networkType === 'ws') {
                config.network = 'ws';
                config['ws-opts'] = {
                    path: params.get('path') || '/',
                    headers: params.get('host') ? { Host: params.get('host')! } : {}
                };
            } else if (networkType === 'grpc') {
                config.network = 'grpc';
                config['grpc-opts'] = {
                    'grpc-service-name': params.get('serviceName') || params.get('path') || ''
                };
            }

            return config;
        } catch (error) {
            logger.warn('解析 Trojan 失败:', error);
            return null;
        }
    }

    /**
     * 解析 Hysteria2 协议
     */
    private parseHysteria2(url: string): ProxyConfig | null {
        try {
            const cleanUrl = url.replace('hy2://', 'hysteria2://');
            const urlObj = new URL(cleanUrl);
            const params = new URLSearchParams(urlObj.search);

            const config: ProxyConfig = {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `hysteria2-${urlObj.hostname}`,
                type: 'hysteria2',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                password: urlObj.username,
                'skip-cert-verify': params.get('insecure') === '1',
            };

            // 处理 SNI
            const sni = params.get('sni');
            if (sni) {
                config.sni = sni;
            } else {
                config.sni = urlObj.hostname;
            }

            // 处理混淆
            const obfs = params.get('obfs');
            if (obfs) {
                config.obfs = obfs;
                const obfsPassword = params.get('obfs-password');
                if (obfsPassword) {
                    config['obfs-password'] = obfsPassword;
                }
            }

            // 处理 ALPN
            const alpn = params.get('alpn');
            if (alpn) {
                config.alpn = alpn.split(',');
            }

            return config;
        } catch (error) {
            logger.warn('解析 Hysteria2 失败:', error);
            return null;
        }
    }

    /**
     * 解析 TUIC 协议
     */
    private parseTuic(url: string): ProxyConfig | null {
        try {
            const urlObj = new URL(url);
            const params = new URLSearchParams(urlObj.search);

            const config: ProxyConfig = {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `tuic-${urlObj.hostname}`,
                type: 'tuic',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                uuid: urlObj.username,
                password: urlObj.password,
                'skip-cert-verify': params.get('allow_insecure') === '1',
            };

            // 处理 SNI
            const sni = params.get('sni');
            if (sni) {
                config.sni = sni;
            } else {
                config.sni = urlObj.hostname;
            }

            // 处理拥塞控制算法
            const congestionControl = params.get('congestion_control');
            if (congestionControl) {
                config['congestion-controller'] = congestionControl;
            } else {
                config['congestion-controller'] = 'cubic';
            }

            // 处理 UDP 中继模式
            const udpRelayMode = params.get('udp_relay_mode');
            if (udpRelayMode) {
                config['udp-relay-mode'] = udpRelayMode;
            } else {
                config['udp-relay-mode'] = 'native';
            }

            // 处理 reduce RTT
            const reduceRtt = params.get('reduce_rtt');
            if (reduceRtt === '1') {
                config['reduce-rtt'] = true;
            }

            // 处理 ALPN
            const alpn = params.get('alpn');
            if (alpn) {
                config.alpn = alpn.split(',');
            }

            return config;
        } catch (error) {
            logger.warn('解析 TUIC 失败:', error);
            return null;
        }
    }

    /**
     * 解析 Shadowsocks 协议
     */
    private parseShadowsocks(url: string): ProxyConfig | null {
        try {
            const urlObj = new URL(url);
            
            let method: string;
            let password: string;
            
            if (urlObj.username && urlObj.password) {
                method = urlObj.username;
                password = urlObj.password;
            } else {
                // 解析 base64 编码的用户信息
                const userInfo = Buffer.from(urlObj.username, 'base64').toString();
                const [methodPart, passwordPart] = userInfo.split(':');
                method = methodPart;
                password = passwordPart;
            }

            return {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `ss-${urlObj.hostname}`,
                type: 'ss',
                server: urlObj.hostname,
                port: parseInt(urlObj.port),
                cipher: method,
                password: password
            };
        } catch (error) {
            logger.warn('解析 Shadowsocks 失败:', error);
            return null;
        }
    }

    /**
     * 生成 Clash 配置
     */
    private generateClashConfig(proxies: ProxyConfig[]): string {
        const proxyNames = proxies.map(p => p.name);
        
        const clashConfig = {
            port: 7890,
            'socks-port': 7891,
            'allow-lan': false,
            mode: 'rule',
            'log-level': 'info',
            'external-controller': '127.0.0.1:9090',
            dns: {
                enable: true,
                listen: '0.0.0.0:53',
                'default-nameserver': ['223.5.5.5', '119.29.29.29'],
                'enhanced-mode': 'fake-ip',
                'fake-ip-range': '198.18.0.1/16',
                nameserver: ['https://doh.pub/dns-query', 'https://dns.alidns.com/dns-query']
            },
            proxies: proxies,
            'proxy-groups': [
                {
                    name: '🚀 节点选择',
                    type: 'select',
                    proxies: ['♻️ 自动选择', '🔯 故障转移', '🔮 负载均衡', '🎯 全球直连', ...proxyNames]
                },
                {
                    name: '♻️ 自动选择',
                    type: 'url-test',
                    proxies: proxyNames,
                    url: 'http://www.gstatic.com/generate_204',
                    interval: 300
                },
                {
                    name: '🔯 故障转移',
                    type: 'fallback',
                    proxies: proxyNames,
                    url: 'http://www.gstatic.com/generate_204',
                    interval: 300
                },
                {
                    name: '🔮 负载均衡',
                    type: 'load-balance',
                    proxies: proxyNames,
                    url: 'http://www.gstatic.com/generate_204',
                    interval: 300
                },
                {
                    name: '🎯 全球直连',
                    type: 'select',
                    proxies: ['DIRECT']
                },
                {
                    name: '🐟 漏网之鱼',
                    type: 'select',
                    proxies: ['🚀 节点选择', '🎯 全球直连', '♻️ 自动选择']
                }
            ],
            rules: [
                'DOMAIN-SUFFIX,local,DIRECT',
                'IP-CIDR,127.0.0.0/8,DIRECT',
                'IP-CIDR,172.16.0.0/12,DIRECT',
                'IP-CIDR,192.168.0.0/16,DIRECT',
                'IP-CIDR,10.0.0.0/8,DIRECT',
                'IP-CIDR,17.0.0.0/8,DIRECT',
                'IP-CIDR,100.64.0.0/10,DIRECT',
                'DOMAIN-SUFFIX,cn,DIRECT',
                'GEOIP,CN,DIRECT',
                'MATCH,🐟 漏网之鱼'
            ]
        };

        return this.convertObjectToYaml(clashConfig, proxies.length);
    }
    
    /**
     * 将配置对象转换为 YAML 字符串
     */
    private convertObjectToYaml(config: any, proxyCount: number): string {
        try {
            // 创建临时 JSON 文件
            const tempJsonPath = path.join(path.dirname(this.configPath), 'temp-config.json');
            fs.writeFileSync(tempJsonPath, JSON.stringify(config, null, 2));
            
            try {
                // 获取 yq 工具路径
                const yqPath = this.getYqPath();
                
                // 使用 yq 将 JSON 转换为 YAML
                const yamlResult = execSync(`${yqPath} eval -P '.' "${tempJsonPath}"`, {
                    encoding: 'utf8',
                    timeout: 10000
                });
                
                // 添加注释头
                const header = `# Clash 配置文件
# 由 subscription-api-ts 使用 mihomo 内核生成
# 生成时间: ${new Date().toISOString()}
# 节点数量: ${proxyCount}

`;
                
                return header + yamlResult;
            } finally {
                // 清理临时文件
                if (fs.existsSync(tempJsonPath)) {
                    fs.removeSync(tempJsonPath);
                }
            }
        } catch (error) {
            logger.error('转换配置为 YAML 失败:', error);
            throw new Error('配置转换失败');
        }
    }
    
    /**
     * 获取 yq 工具路径
     */
    private getYqPath(): string {
        const baseDir = path.join(os.homedir(), '.config', 'subscription');
        const yqPath = path.join(baseDir, 'bin', 'yq');
        
        // 检查 BASE_DIR/bin/yq 是否存在
        if (fs.existsSync(yqPath)) {
            return yqPath;
        }
        
        // 向后兼容：检查项目根目录的 bin/yq
        const projectRoot = path.resolve(__dirname, '../../');
        const fallbackYqPath = path.join(projectRoot, 'bin', 'yq');
        if (fs.existsSync(fallbackYqPath)) {
            return fallbackYqPath;
        }
        
        // 最后尝试系统 yq
        return 'yq';
    }

    /**
     * 验证 Clash 配置
     */
    private async validateClashConfig(config: string): Promise<void> {
        try {
            // 将配置写入临时文件
            const tempConfigPath = path.join(path.dirname(this.configPath), 'temp-config.yaml');
            await fs.writeFile(tempConfigPath, config);

            try {
                logger.debug(`使用 mihomo 验证配置文件: ${tempConfigPath}`);
                
                // 使用 mihomo -t 参数验证配置
                const result = execSync(`"${this.mihomoPath}" -t -f "${tempConfigPath}"`, {
                    encoding: 'utf8',
                    timeout: 10000,
                    stdio: ['ignore', 'pipe', 'pipe']
                });

                logger.info('Clash 配置验证通过');
                logger.debug(`验证输出: ${result.trim()}`);
            } catch (execError: any) {
                // 获取详细的错误信息
                const stderr = execError.stderr || '';
                const stdout = execError.stdout || '';
                const errorMessage = stderr || stdout || execError.message;
                
                logger.error('Mihomo 配置验证失败:', {
                    stderr: stderr.trim(),
                    stdout: stdout.trim(),
                    message: execError.message,
                    status: execError.status
                });
                
                // 输出配置内容用于调试 (只输出前500字符)
                logger.debug('验证失败的配置内容:', config.substring(0, 500) + (config.length > 500 ? '...' : ''));
                
                throw new Error(`配置验证失败: ${errorMessage.trim()}`);
            } finally {
                // 清理临时文件
                try {
                    if (fs.existsSync(tempConfigPath)) {
                        fs.removeSync(tempConfigPath);
                    }
                } catch (cleanupError) {
                    logger.warn('清理临时文件失败:', cleanupError);
                }
            }
        } catch (error) {
            if (error instanceof Error && error.message.includes('配置验证失败')) {
                throw error; // 重新抛出详细的验证错误
            }
            
            logger.error('配置验证过程失败:', {
                message: error instanceof Error ? error.message : String(error),
                stack: error instanceof Error ? error.stack : undefined
            });
            
            throw new Error(`配置验证过程失败: ${error instanceof Error ? error.message : String(error)}`);
        }
    }

    /**
     * 测试 mihomo 的不同调用方式
     */
    public async testConversion(): Promise<{
        success: boolean;
        message: string;
        version?: string;
        testResults?: any;
    }> {
        try {
            logger.info('开始测试 mihomo 转换功能');

            // 检查 mihomo 可用性
            const available = await this.ensureMihomoAvailable();
            if (!available) {
                return {
                    success: false,
                    message: 'mihomo 不可用，无法进行测试'
                };
            }

            // 获取版本信息
            const versionInfo = await this.getVersion();
            const version = versionInfo?.version || 'unknown';

            logger.info(`使用 mihomo ${version} 进行测试`);

            // 测试简单的配置生成
            const testProxies: ProxyConfig[] = [
                {
                    name: 'test-vmess',
                    type: 'vmess',
                    server: 'test.example.com',
                    port: 443,
                    uuid: '12345678-1234-1234-1234-123456789012',
                    alterId: 0,
                    cipher: 'auto',
                    network: 'tcp',
                    tls: true,
                    'skip-cert-verify': true
                }
            ];

            const testConfig = this.generateClashConfig(testProxies);
            
            // 验证生成的配置
            await this.validateClashConfig(testConfig);

            return {
                success: true,
                message: `mihomo ${version} 测试成功`,
                version: version,
                testResults: {
                    configGenerated: true,
                    configValid: true,
                    proxiesCount: testProxies.length
                }
            };
        } catch (error: any) {
            logger.error('mihomo 测试失败:', error);
            return {
                success: false,
                message: `mihomo 测试失败: ${error?.message || '未知错误'}`
            };
        }
    }
}
