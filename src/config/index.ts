import { Config } from '../types';

export const config: Config = {
    port: parseInt(process.env.PORT || '3000'),
    singBoxConfigs: (process.env.SING_BOX_CONFIGS || 'vless-reality,hysteria2,trojan,tuic,vmess').split(','),
    subconverterUrl: process.env.SUBCONVERTER_URL || 'http://localhost:25500',
    staticDir: process.env.DATA_DIR || './data',
    logDir: process.env.LOG_DIR || './logs',
    backupDir: process.env.BACKUP_DIR || './data/backup',
    autoUpdateCron: process.env.AUTO_UPDATE_CRON || '0 */2 * * *',
    nginxPort: parseInt(process.env.NGINX_PORT || '3080'),
    maxRetries: parseInt(process.env.MAX_RETRIES || '3'),
    requestTimeout: parseInt(process.env.REQUEST_TIMEOUT || '30000')
};

export const validateConfig = (): void => {
    const requiredFields: (keyof Config)[] = ['port', 'singBoxConfigs', 'subconverterUrl'];
    
    for (const field of requiredFields) {
        if (!config[field]) {
            throw new Error(`配置字段 ${field} 是必需的`);
        }
    }
    
    if (config.singBoxConfigs.length === 0) {
        throw new Error('至少需要配置一个sing-box配置名称');
    }
};