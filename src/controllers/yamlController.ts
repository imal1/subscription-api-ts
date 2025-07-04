import { Request, Response } from 'express';
import { yamlService } from '../services/yamlService';
import { logger } from '../utils/logger';

export class YamlController {
    
    /**
     * 验证 YAML 文件语法
     * GET /api/yaml/validate
     */
    public async validateYaml(req: Request, res: Response): Promise<void> {
        try {
            const isValid = yamlService.validateConfig();
            
            res.json({
                success: true,
                valid: isValid,
                message: isValid ? 'YAML 配置文件语法正确' : 'YAML 配置文件语法错误'
            });
        } catch (error) {
            logger.error('验证 YAML 文件失败:', error);
            res.status(500).json({
                success: false,
                message: '验证过程中发生错误'
            });
        }
    }

    /**
     * 获取前端所需的配置
     * GET /api/yaml/frontend
     */
    public async getFrontendConfig(req: Request, res: Response): Promise<void> {
        try {
            const fullConfig = yamlService.getFullConfig();
            
            // 提取前端所需的配置
            const frontendConfig = {
                app: fullConfig.app || {},
                network: fullConfig.network || {},
                external: fullConfig.external || {},
                protocols: fullConfig.protocols || {},
                cors: fullConfig.cors || {}
            };
            
            res.json({
                success: true,
                data: frontendConfig
            });
        } catch (error) {
            logger.error('获取前端配置失败:', error);
            res.status(500).json({
                success: false,
                message: '获取前端配置过程中发生错误'
            });
        }
    }

    /**
     * 获取完整配置
     * GET /api/yaml/config
     */
    public async getFullConfig(req: Request, res: Response): Promise<void> {
        try {
            const config = yamlService.getFullConfig();
            
            res.json({
                success: true,
                data: config
            });
        } catch (error) {
            logger.error('获取完整配置失败:', error);
            res.status(500).json({
                success: false,
                message: '获取配置过程中发生错误'
            });
        }
    }

    /**
     * 生成配置文件
     * POST /api/yaml/generate
     * Body: { templatePath: string, outputPath?: string }
     */
    public async generateConfig(req: Request, res: Response): Promise<void> {
        try {
            const { templatePath, outputPath } = req.body;
            
            if (!templatePath || typeof templatePath !== 'string') {
                res.status(400).json({
                    success: false,
                    message: '请提供模板文件路径 (templatePath)'
                });
                return;
            }
            
            const result = yamlService.generateConfig(templatePath, outputPath);
            
            res.json({
                success: result,
                message: result ? '配置文件生成成功' : '配置文件生成失败'
            });
        } catch (error) {
            logger.error('生成配置文件失败:', error);
            res.status(500).json({
                success: false,
                message: '生成配置文件过程中发生错误'
            });
        }
    }
}