import type { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const nodeId = (req.query.node as string) || '';

  // Initial status
  res.write(`data: ${JSON.stringify({ step: 'connect', status: 'pending', message: '等待部署开始...', progress: 0 })}\n\n`);

  req.on('close', () => {
    res.end();
  });
}
