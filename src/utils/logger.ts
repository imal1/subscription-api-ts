import winston from 'winston';
import * as path from 'path';
import { config } from '../config';

// 获取日志级别
const getLogLevel = (): string => {
    // 从配置模块获取日志级别
    const { getLogLevel } = require('../config/index');
    return getLogLevel();
};

const logFormat = winston.format.combine(
    winston.format.timestamp({
        format: 'YYYY-MM-DD HH:mm:ss'
    }),
    winston.format.errors({ stack: true }),
    winston.format.printf(({ level, message, timestamp, stack }) => {
        return `${timestamp} [${level.toUpperCase()}]: ${stack || message}`;
    })
);

export const logger = winston.createLogger({
    level: getLogLevel(),
    format: logFormat,
    defaultMeta: { service: 'subscription-api' },
    transports: [
        new winston.transports.File({
            filename: path.join(config.logDir, 'error.log'),
            level: 'error',
            maxsize: 5242880, // 5MB
            maxFiles: 5
        }),
        new winston.transports.File({
            filename: path.join(config.logDir, 'combined.log'),
            maxsize: 5242880, // 5MB
            maxFiles: 5
        })
    ]
});

// 获取应用环境
const getAppEnvironment = (): string => {
    try {
        // 延迟导入以避免循环依赖
        const { getAppEnvironment } = require('../config/index');
        return getAppEnvironment();
    } catch {
        return 'production';
    }
};

const appEnvironment = getAppEnvironment();
if (appEnvironment !== 'production') {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        ),
        level: 'debug'
    }));
} else {
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        )
    }));
}

export default logger;