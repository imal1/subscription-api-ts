import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { DeployManager } from '@/server/services/deployManager';
import type { DeployStep } from '@/server/services/deployManager';
import { setDeployProgress } from '@/server/services/deployProgressStore';
import { logger } from '@/server/utils/logger';
import type { ApiResponse } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { nodeId } = req.body || {};
    if (!nodeId) {
      return res.status(400).json({ success: false, error: '缺少 nodeId', timestamp: new Date().toISOString() });
    }

    const nodeManager = NodeManager.getInstance();
    const deployManager = DeployManager.getInstance();
    const nodes = await nodeManager.loadNodes();
    const node = nodes.find(n => n.id === nodeId);

    if (!node) {
      return res.status(404).json({ success: false, error: `节点 ${nodeId} 不存在`, timestamp: new Date().toISOString() });
    }

    if (!node.ssh) {
      return res.status(400).json({ success: false, error: '节点未配置 SSH 信息', timestamp: new Date().toISOString() });
    }

    // Initialize progress tracking
    const steps: DeployStep[] = [];
    setDeployProgress(nodeId, steps);

    // Start deploy asynchronously
    const deployPromise = deployManager.deployToNode(
      {
        nodeId: node.id,
        ssh: {
          host: node.host,
          user: node.ssh.user,
          port: node.ssh.port,
          keyPath: node.ssh.keyPath,
          hostKey: node.ssh.hostKey,
          password: node.ssh.password,
        },
        agentPort: 3001,
      },
      (step: DeployStep) => {
        steps.push(step);
        setDeployProgress(nodeId, [...steps]);
      },
    );

    // Return immediately with 202 Accepted
    res.status(202).json({
      success: true,
      message: `节点 ${node.name} 部署已启动`,
      timestamp: new Date().toISOString(),
    });

    // Wait for deploy to finish (in background, after response sent)
    deployPromise.then((result) => {
      logger.info(`Deploy API: 节点 ${nodeId} 部署完成: ${result.success ? '成功' : '失败'} - ${result.message}`);
    }).catch((err) => {
      logger.error(`Deploy API: 节点 ${nodeId} 部署异常: ${err.message}`);
    });
  } catch (error: any) {
    logger.error('部署失败:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
}
