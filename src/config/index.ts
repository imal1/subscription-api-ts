import { Config } from '../types';
import * as os from 'os';
import * as path from 'path';

// 获取统一的基础目录
const getSubscriptionBaseDir = (): string => {
    // 优先使用环境变量，否则使用默认的 $HOME/.config/.subscription
    return process.env.BASE_DIR || path.join(os.homedir(), '.config', '.subscription');
};

export const config: Config = {
    port: parseInt(process.env.PORT || '3000'),
    singBoxConfigs: (process.env.SING_BOX_CONFIGS || 'vless-reality,hysteria2,trojan,tuic,vmess').split(','),
    mihomoPath: process.env.MIHOMO_PATH || '',
    clashFilename: 'clash.yaml',
    staticDir: process.env.DATA_DIR || path.join(getSubscriptionBaseDir(), 'www'),
    logDir: process.env.LOG_DIR || path.join(getSubscriptionBaseDir(), 'log'),
    backupDir: process.env.BACKUP_DIR || path.join(getSubscriptionBaseDir(), 'www', 'backup'),
    autoUpdateCron: process.env.AUTO_UPDATE_CRON || '0 */2 * * *',
    nginxPort: parseInt(process.env.NGINX_PORT || '3080'),
    maxRetries: parseInt(process.env.MAX_RETRIES || '3'),
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT || '30000')
};

export const validateConfig = (): void => {
    const requiredFields: (keyof Config)[] = ['port', 'singBoxConfigs'];
    
    for (const field of requiredFields) {
        if (!config[field]) {
            throw new Error(`配置字段 ${field} 是必需的`);
        }
    }
    
    if (config.singBoxConfigs.length === 0) {
        throw new Error('至少需要配置一个sing-box配置名称');
    }
};