import { Router } from 'express';
import { SubscriptionController } from '@/controllers/subscriptionController';

const router = Router();
const subscriptionController = new SubscriptionController();

// API文档
router.get('/', subscriptionController.index);

// 订阅管理
router.post('/api/update', subscriptionController.updateSubscription);
router.get('/api/status', subscriptionController.getStatus);

// 配置管理
router.get('/api/configs', subscriptionController.getConfigs);
router.post('/api/configs', subscriptionController.updateConfigs);

// 文件下载
router.get('/subscription.txt', subscriptionController.getSubscriptionFile);
router.get('/clash.yaml', subscriptionController.getClashFile);
router.get('/raw.txt', subscriptionController.getRawFile);

// 健康检查
router.get('/health', subscriptionController.healthCheck);

export default router;