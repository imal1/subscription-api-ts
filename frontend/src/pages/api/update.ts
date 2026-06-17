import type { NextApiRequest, NextApiResponse } from 'next';
import { SubscriptionService } from '@/server/services/subscriptionService';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export const config = {
  // 订阅更新会 spawn mihomo/sing-box，耗时较长
  maxDuration: 120,
};

export default async function handler(req: NextApiRequest, res: NextApiResponse<ApiResponse>) {
  try {
    const result = await SubscriptionService.getInstance().updateSubscription();
    res.json({ success: true, data: result, message: '订阅更新成功', timestamp: new Date().toISOString() });
  } catch (error: any) {
    logger.error('更新订阅API错误:', error);
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
