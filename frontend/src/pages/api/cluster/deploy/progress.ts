import type { NextApiRequest, NextApiResponse } from 'next';
import { getDeployProgress } from '@/server/services/deployProgressStore';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');

  const nodeId = (req.query.node as string) || '';
  let sentCount = 0;

  // Send any already-completed steps
  const initialSteps = getDeployProgress(nodeId);
  for (const step of initialSteps) {
    res.write(`data: ${JSON.stringify(step)}\n\n`);
    sentCount++;
  }

  if (initialSteps.length === 0) {
    res.write(`data: ${JSON.stringify({ step: 'connect', status: 'pending', message: '等待部署开始...', progress: 0 })}\n\n`);
  }

  // Poll for progress updates every 500ms
  const interval = setInterval(() => {
    const steps = getDeployProgress(nodeId);
    // Send any new steps since last poll
    while (sentCount < steps.length) {
      res.write(`data: ${JSON.stringify(steps[sentCount])}\n\n`);
      sentCount++;
    }

    // Check if done
    const lastStep = steps[steps.length - 1];
    if (lastStep && (lastStep.step === 'done' || lastStep.status === 'error')) {
      clearInterval(interval);
      res.end();
    }
  }, 500);

  req.on('close', () => {
    clearInterval(interval);
    res.end();
  });
}
