export interface Config {
    port: number;
    singBoxConfigs: string[];
    subconverterUrl: string;
    clashFilename: string;
    staticDir: string;
    logDir: string;
    backupDir: string;
    autoUpdateCron: string;
    nginxPort: number;
    maxRetries: number;
    requestTimeout: number;
}

export interface UpdateResult {
    success: boolean;
    message: string;
    timestamp: string;
    nodesCount: number;
    clashGenerated: boolean;
    backupCreated: string;
    warnings?: string[];
    errors?: string[];
}

export interface SingBoxResult {
    urls: string[];
    errors: string[];
}

export interface StatusInfo {
    subscriptionExists: boolean;
    clashExists: boolean;
    rawExists: boolean;
    subconverterRunning: boolean;
    singBoxAccessible: boolean;
    subscriptionLastUpdated?: string;
    subscriptionSize?: number;
    clashLastUpdated?: string;
    clashSize?: number;
    nodesCount?: number;
    uptime: number;
    version: string;
}

export interface ApiResponse<T = any> {
    success: boolean;
    data?: T;
    error?: string;
    message?: string;
    timestamp: string;
}

export interface ConfigUpdateRequest {
    configs: string[];
}

export interface HealthStatus {
    status: 'healthy' | 'unhealthy';
    checks: {
        database: boolean;
        subconverter: boolean;
        filesystem: boolean;
        singbox: boolean;
    };
    timestamp: string;
}