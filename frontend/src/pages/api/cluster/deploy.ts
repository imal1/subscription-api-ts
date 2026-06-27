import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { DeployManager } from '@/server/services/deployManager';
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

    const secret = deployManager.generateHmacSecret();

    const agentYaml = deployManager.generateAgentYaml(
      node.id, node.name, secret, node.kernel,
    );
    const systemdUnit = deployManager.generateSystemdUnit(secret);

    res.json({
      success: true,
      data: {
        nodeId,
        secret,
        agentYaml,
        systemdUnit,
      },
      message: `节点 ${node.name} 部署配置已生成`,
      timestamp: new Date().toISOString(),
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
