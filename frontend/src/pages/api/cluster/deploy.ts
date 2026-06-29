import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { DeployManager } from '@/server/services/deployManager';
import { setDeployStatus } from '@/server/services/deployProgressStore';
import { logger } from '@/server/utils/logger';
import type { ApiResponse, DeployStatus } from '@/server/types';

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

    // Initialize progress tracking (single DeployStatus per design)
    const startedAt = Date.now();
    const initialStatus: DeployStatus = {
      nodeId: node.id,
      step: 'connect',
      status: 'running',
      message: '正在建立 SSH 连接...',
      progress: 0,
      startedAt,
    };
    setDeployStatus(nodeId, initialStatus);

    // Start deploy asynchronously
    const deployPromise = deployManager.deployToNode(
      {
        nodeId: node.id,
        ssh: {
          host: node.host,
          user: node.ssh.user,
          keyPath: node.ssh.keyPath,
          hostKey: node.ssh.hostKey,
          password: node.ssh.password,
        },
        kernel: node.kernel || 'sing-box',
      },
      (step) => {
        // Map old DeployStep to new DeployStatus format
        const status: DeployStatus = {
          nodeId: node.id,
          step: step.step,
          status: step.status,
          message: step.message,
          progress: step.progress,
          startedAt,
        };
        setDeployStatus(nodeId, status);
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
      // Update progress store with final status
      const finalStatus: DeployStatus = {
        nodeId,
        step: result.success ? 'done' : 'connect',
        status: result.success ? 'success' : 'error',
        message: result.message,
        progress: result.success ? 100 : 0,
        startedAt,
      };
      setDeployStatus(nodeId, finalStatus);
    }).catch((err) => {
      logger.error(`Deploy API: 节点 ${nodeId} 部署异常: ${err.message}`);
      // Bug fix: Update progress store with error status so frontend doesn't hang
      const errorStatus: DeployStatus = {
        nodeId,
        step: 'connect',
        status: 'error',
        message: `部署异常: ${err.message}`,
        progress: 0,
        startedAt,
      };
      setDeployStatus(nodeId, errorStatus);
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
