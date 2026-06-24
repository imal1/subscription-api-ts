import type { NextApiRequest, NextApiResponse } from 'next';
import { MioBridgeService } from '@/server/services/mioBridgeService';
import type { ApiResponse } from '@/server/types';

export default async function handler(req: NextApiRequest, res: NextApiResponse<ApiResponse>) {
  try {
    const status = await MioBridgeService.getInstance().getStatus();
    res.json({ success: true, data: status, timestamp: new Date().toISOString() });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message, timestamp: new Date().toISOString() });
  }
}
