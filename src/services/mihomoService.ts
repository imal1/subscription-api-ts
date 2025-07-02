import axios from 'axios';
import * as fs from 'fs-extra';
import { execSync } from 'child_process';
import * as path from 'path';
import * as os from 'os';
import * as zlib from 'zlib';
import * as yaml from 'js-yaml';
import { logger } from '../utils/logger';
import { config } from '../config';

interface ProxyConfig {
    name: string;
    type: string;
    server: string;
    port: number;
    [key: string]: any;
}

interface ClashConfig {
    proxies: ProxyConfig[];
    'proxy-groups': any[];
    rules: string[];
    dns?: any;
    tun?: any;
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
    private isDownloading = false;

    private constructor() {
        // 从环境变量读取 mihomo 路径，默认为系统临时目录
        const basePath = process.env.MIHOMO_PATH || path.join(os.tmpdir(), 'mihomo');
        this.mihomoPath = path.join(basePath, this.getMihomoExecutableName());
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
     * 获取适用于当前操作系统的 mihomo 可执行文件名
     */
    private getMihomoExecutableName(): string {
        const platform = os.platform();
        const arch = os.arch();
        
        let platformName: string;
        let archName: string;

        // 映射平台名称
        switch (platform) {
            case 'win32':
                platformName = 'windows';
                break;
            case 'darwin':
                platformName = 'darwin';
                break;
            case 'linux':
                platformName = 'linux';
                break;
            default:
                throw new Error(`不支持的操作系统: ${platform}`);
        }

        // 映射架构名称
        switch (arch) {
            case 'x64':
                archName = 'amd64';
                break;
            case 'arm64':
                archName = 'arm64';
                break;
            case 'arm':
                archName = 'armv7';
                break;
            default:
                throw new Error(`不支持的CPU架构: ${arch}`);
        }

        const extension = platform === 'win32' ? '.exe' : '';
        return `mihomo-${platformName}-${archName}${extension}`;
    }

    /**
     * 获取下载文件名（包含版本号和压缩扩展名）
     */
    private getMihomoDownloadFileName(version: string): string {
        const platform = os.platform();
        const arch = os.arch();
        
        let platformName: string;
        let archName: string;

        // 映射平台名称
        switch (platform) {
            case 'win32':
                platformName = 'windows';
                break;
            case 'darwin':
                platformName = 'darwin';
                break;
            case 'linux':
                platformName = 'linux';
                break;
            default:
                throw new Error(`不支持的操作系统: ${platform}`);
        }

        // 映射架构名称
        switch (arch) {
            case 'x64':
                archName = 'amd64';
                break;
            case 'arm64':
                archName = 'arm64';
                break;
            case 'arm':
                archName = 'armv7';
                break;
            default:
                throw new Error(`不支持的CPU架构: ${arch}`);
        }

        // GitHub 仓库中的文件名格式: mihomo-{platform}-{arch}-{version}.gz
        return `mihomo-${platformName}-${archName}-${version}.gz`;
    }

    /**
     * 检查 mihomo 是否可用，如果不可用则自动下载
     */
    public async ensureMihomoAvailable(): Promise<boolean> {
        try {
            // 检查本地是否已存在
            if (await this.checkLocalMihomo()) {
                return true;
            }

            // 如果不存在，尝试下载
            logger.info('未找到 mihomo 二进制文件，开始下载最新版本...');
            return await this.downloadLatestMihomo();
        } catch (error) {
            logger.error('确保 mihomo 可用时发生错误:', error);
            return false;
        }
    }

    /**
     * 检查本地 mihomo 是否可用
     */
    private async checkLocalMihomo(): Promise<boolean> {
        try {
            if (!fs.existsSync(this.mihomoPath)) {
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
     * 下载最新版本的 mihomo
     */
    private async downloadLatestMihomo(): Promise<boolean> {
        if (this.isDownloading) {
            logger.info('mihomo 正在下载中，请等待...');
            return false;
        }

        this.isDownloading = true;

        try {
            // 获取最新版本信息
            const latestVersion = await this.getLatestVersion();
            if (!latestVersion) {
                throw new Error('无法获取最新版本信息');
            }

            logger.info(`开始下载 mihomo ${latestVersion}...`);

            // 构建下载 URL
            const downloadFileName = this.getMihomoDownloadFileName(latestVersion);
            const downloadUrl = `https://github.com/MetaCubeX/mihomo/releases/download/${latestVersion}/${downloadFileName}`;

            logger.info(`下载地址: ${downloadUrl}`);

            // 下载压缩文件
            const response = await axios.get(downloadUrl, {
                responseType: 'stream',
                timeout: 300000, // 5分钟超时
                headers: {
                    'User-Agent': 'subscription-api-ts/1.0.0'
                }
            });

            // 创建临时文件路径
            const tempGzPath = this.mihomoPath + '.gz';

            // 保存压缩文件
            const writeStream = fs.createWriteStream(tempGzPath);
            response.data.pipe(writeStream);

            await new Promise<void>((resolve, reject) => {
                writeStream.on('finish', () => resolve());
                writeStream.on('error', reject);
            });

            // 解压缩文件
            logger.info('正在解压缩文件...');
            const gzipData = fs.readFileSync(tempGzPath);
            const decompressedData = zlib.gunzipSync(gzipData);
            fs.writeFileSync(this.mihomoPath, decompressedData);

            // 清理临时文件
            fs.removeSync(tempGzPath);

            // 设置执行权限 (非 Windows 系统)
            if (os.platform() !== 'win32') {
                fs.chmodSync(this.mihomoPath, '755');
            }

            logger.info(`mihomo ${latestVersion} 下载完成: ${this.mihomoPath}`);
            
            // 验证下载的文件
            const isValid = await this.checkLocalMihomo();
            if (!isValid) {
                throw new Error('下载的 mihomo 文件无效');
            }

            return true;
        } catch (error) {
            logger.error('下载 mihomo 失败:', error);
            // 清理可能损坏的文件
            if (fs.existsSync(this.mihomoPath)) {
                fs.removeSync(this.mihomoPath);
            }
            // 清理临时文件
            const tempGzPath = this.mihomoPath + '.gz';
            if (fs.existsSync(tempGzPath)) {
                fs.removeSync(tempGzPath);
            }
            return false;
        } finally {
            this.isDownloading = false;
        }
    }

    /**
     * 获取最新版本号
     */
    private async getLatestVersion(): Promise<string | null> {
        try {
            const response = await axios.get('https://api.github.com/repos/MetaCubeX/mihomo/releases/latest', {
                timeout: 10000,
                headers: {
                    'User-Agent': 'subscription-api-ts/1.0.0'
                }
            });

            return response.data.tag_name;
        } catch (error) {
            logger.error('获取最新版本失败:', error);
            return null;
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

        try {
            // 确保 mihomo 可用
            if (!await this.ensureMihomoAvailable()) {
                throw new Error('mihomo 服务不可用');
            }

            return await this.convertContentToClash(content);
        } catch (error) {
            logger.error('mihomo 内容转换失败:', error);
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
            // 解析代理节点
            const proxies = this.parseProxies(content);
            
            if (proxies.length === 0) {
                throw new Error('未找到有效的代理节点');
            }

            // 生成 Clash 配置
            const clashConfig = this.generateClashConfig(proxies);
            
            // 使用 mihomo 验证配置
            await this.validateClashConfig(clashConfig);

            logger.info(`成功转换 ${proxies.length} 个代理节点`);
            return clashConfig;
        } catch (error) {
            logger.error('转换内容为 Clash 配置失败:', error);
            throw error;
        }
    }

    /**
     * 解析代理节点
     */
    private parseProxies(content: string): ProxyConfig[] {
        const proxies: ProxyConfig[] = [];
        const lines = content.split('\n').filter(line => line.trim());

        for (const line of lines) {
            try {
                const proxy = this.parseProxyLine(line.trim());
                if (proxy) {
                    proxies.push(proxy);
                }
            } catch (error) {
                logger.warn(`解析代理行失败: ${line}`, error);
            }
        }

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

            return {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `vless-${urlObj.hostname}`,
                type: 'vless',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                uuid: urlObj.username,
                flow: params.get('flow') || '',
                network: params.get('type') || 'tcp',
                tls: params.get('security') === 'tls' || params.get('security') === 'reality',
                'skip-cert-verify': true,
                ...(params.get('security') === 'reality' && {
                    'reality-opts': {
                        'public-key': params.get('pbk') || '',
                        'short-id': params.get('sid') || ''
                    }
                }),
                ...(params.get('type') === 'ws' && {
                    'ws-opts': {
                        path: params.get('path') || '/',
                        headers: params.get('host') ? { Host: params.get('host')! } : {}
                    }
                }),
                ...(params.get('type') === 'grpc' && {
                    'grpc-opts': {
                        'grpc-service-name': params.get('serviceName') || ''
                    }
                })
            };
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

            return {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `trojan-${urlObj.hostname}`,
                type: 'trojan',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                password: urlObj.username,
                'skip-cert-verify': true,
                sni: params.get('sni') || urlObj.hostname,
                ...(params.get('type') === 'ws' && {
                    network: 'ws',
                    'ws-opts': {
                        path: params.get('path') || '/',
                        headers: params.get('host') ? { Host: params.get('host')! } : {}
                    }
                }),
                ...(params.get('type') === 'grpc' && {
                    network: 'grpc',
                    'grpc-opts': {
                        'grpc-service-name': params.get('serviceName') || ''
                    }
                })
            };
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

            return {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `hysteria2-${urlObj.hostname}`,
                type: 'hysteria2',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                password: urlObj.username,
                'skip-cert-verify': true,
                sni: params.get('sni') || urlObj.hostname,
                ...(params.get('obfs') && {
                    obfs: params.get('obfs'),
                    'obfs-password': params.get('obfs-password') || ''
                })
            };
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

            return {
                name: decodeURIComponent(urlObj.hash.substring(1)) || `tuic-${urlObj.hostname}`,
                type: 'tuic',
                server: urlObj.hostname,
                port: parseInt(urlObj.port) || 443,
                uuid: urlObj.username,
                password: urlObj.password,
                'skip-cert-verify': true,
                sni: params.get('sni') || urlObj.hostname,
                'congestion-controller': params.get('congestion_control') || 'cubic',
                'udp-relay-mode': params.get('udp_relay_mode') || 'native',
                'reduce-rtt': params.get('reduce_rtt') === '1'
            };
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

        return `# Clash 配置文件
# 由 subscription-api-ts 使用 mihomo 内核生成
# 生成时间: ${new Date().toISOString()}
# 节点数量: ${proxies.length}

${yaml.dump(clashConfig, { 
    flowLevel: -1, 
    styles: { 
        '!!null': 'canonical' 
    } 
})}`;
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
                // 使用 mihomo 验证配置
                execSync(`"${this.mihomoPath}" -t -f "${tempConfigPath}"`, {
                    encoding: 'utf8',
                    timeout: 10000
                });

                logger.info('Clash 配置验证通过');
            } finally {
                // 清理临时文件
                if (fs.existsSync(tempConfigPath)) {
                    fs.removeSync(tempConfigPath);
                }
            }
        } catch (error) {
            logger.error('Clash 配置验证失败:', error);
            throw new Error('生成的 Clash 配置无效');
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
