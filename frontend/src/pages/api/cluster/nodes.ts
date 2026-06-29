import type { NextApiRequest, NextApiResponse } from 'next';
import { NodeManager } from '@/server/services/nodeManager';
import { logger } from '@/server/utils/logger';
import type { ApiResponse, NodeConfig } from '@/server/types';

export default async function handler(
  req: NextApiRequest,
  res: NextApiResponse<ApiResponse>,
) {
  if (req.method !== 'POST') {
    return res.status(405).json({ success: false, error: 'Method Not Allowed', timestamp: new Date().toISOString() });
  }

  try {
    const { name, host, kernel, location, sshUser, sshKey, sshPassword } = req.body || {};

    if (!name || !host) {
      return res.status(400).json({ success: false, error: '缺少必填字段 name 或 host', timestamp: new Date().toISOString() });
    }

    const nodeManager = NodeManager.getInstance();

    // Build NodeConfig from form data
    const nodeConfig: NodeConfig = {
      id: '', // will be auto-generated
      name,
      host,
      secret: '', // will be auto-generated
      kernel: kernel || 'sing-box',
      location: location || '',
      enabled: true,
      ssh: {
        user: sshUser || 'root',
        keyPath: sshKey || '',
        hostKey: '',
        password: sshPassword || '',
      },
      agent: {
        deployed: false,
        version: '',
        status: 'not_deployed',
        lastDeploy: '',
      },
    };

    const saved = await nodeManager.writeNodeToYaml(nodeConfig);

    res.status(201).json({
      success: true,
      data: saved,
      message: `节点 ${saved.name} 已添加`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    logger.error('添加节点失败:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
}
