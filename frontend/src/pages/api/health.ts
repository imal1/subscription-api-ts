import type { NextApiRequest, NextApiResponse } from 'next';
import { VERSION } from '@/server/version';

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  try {
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage(),
      version: VERSION,
    });
  } catch (error: any) {
    res.status(503).json({ status: 'unhealthy', error: error.message, timestamp: new Date().toISOString() });
  }
}
