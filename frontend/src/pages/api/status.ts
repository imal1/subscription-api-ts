import type { NextApiRequest, NextApiResponse } from 'next';
import { SubscriptionService } from '@/server/services/subscriptionService';
import type { ApiResponse } from '@/server/types';

export default async function handler(req: NextApiRequest, res: NextApiResponse<ApiResponse>) {
  try {
    const status = await SubscriptionService.getInstance().getStatus();
    res.json({ success: true, data: status, timestamp: new Date().toISOString() });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
