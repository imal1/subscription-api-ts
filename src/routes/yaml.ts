import { Router } from 'express';
import { YamlController } from '../controllers/yamlController';

const router = Router();
const yamlController = new YamlController();

// 验证 YAML 语法
router.get('/validate', yamlController.validateYaml.bind(yamlController));

// 获取前端配置
router.get('/frontend', yamlController.getFrontendConfig.bind(yamlController));

// 获取完整配置
router.get('/config', yamlController.getFullConfig.bind(yamlController));

// 生成配置文件
router.post('/generate', yamlController.generateConfig.bind(yamlController));

export default router;
