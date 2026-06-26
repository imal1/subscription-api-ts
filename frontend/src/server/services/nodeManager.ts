import * as fs from 'fs-extra';
import * as path from 'path';
import * as os from 'os';
import * as crypto from 'crypto';
import { logger } from '../utils/logger';
import type { NodeConfig, NodeStatus, ClusterStatus, NodesYaml } from '../types';

const NODES_YAML_PATH = path.join(os.homedir(), '.config', 'miobridge', 'nodes.yaml');

export class NodeManager {
  private static instance: NodeManager;
  private nodes: NodeConfig[] = [];

  private constructor() {}

  public static getInstance(): NodeManager {
    if (!NodeManager.instance) {
      NodeManager.instance = new NodeManager();
    }
    return NodeManager.instance;
  }

  /** 读取 nodes.yaml */
  async loadNodes(): Promise<NodeConfig[]> {
    try {
      if (!(await fs.pathExists(NODES_YAML_PATH))) {
        this.nodes = [];
        logger.info('NodeManager: nodes.yaml 不存在，运行在单机模式');
        return [];
      }
      const raw = await fs.readFile(NODES_YAML_PATH, 'utf8');
      const parsed = this.parseNodesYaml(raw);
      this.nodes = parsed.nodes.filter(n => n.enabled);
      logger.info(`NodeManager: 加载了 ${this.nodes.length} 个节点`);
      return this.nodes;
    } catch (error: any) {
      logger.error(`NodeManager: 加载 nodes.yaml 失败: ${error.message}`);
      this.nodes = [];
      return [];
    }
  }

  /** 简易 YAML 解析（只解析 nodes 数组） */
  private parseNodesYaml(raw: string): NodesYaml {
    const nodes: NodeConfig[] = [];
    let current: Partial<NodeConfig> = {};
    const lines = raw.split('\n');

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed === '') continue;

      if (trimmed.startsWith('- id:')) {
        if (current.id) { nodes.push(current as NodeConfig); }
        current = { id: this.extractYamlValue(trimmed, 'id') };
      } else if (trimmed.startsWith('name:')) {
        current.name = this.extractYamlValue(trimmed, 'name');
      } else if (trimmed.startsWith('host:')) {
        current.host = this.extractYamlValue(trimmed, 'host');
      } else if (trimmed.startsWith('port:')) {
        current.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 443;
      } else if (trimmed.startsWith('secret:')) {
        current.secret = this.extractYamlValue(trimmed, 'secret');
      } else if (trimmed.startsWith('kernel:')) {
        current.kernel = this.extractYamlValue(trimmed, 'kernel') as NodeConfig['kernel'];
      } else if (trimmed.startsWith('location:')) {
        current.location = this.extractYamlValue(trimmed, 'location');
      } else if (trimmed.startsWith('enabled:')) {
        current.enabled = this.extractYamlValue(trimmed, 'enabled') !== 'false';
      }
    }
    if (current.id) { nodes.push(current as NodeConfig); }
    return { nodes };
  }

  private extractYamlValue(line: string, _key: string): string {
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) return '';
    let val = line.substring(colonIdx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) ||
        (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    return val;
  }

  /** 检查是否有远程节点 */
  hasRemoteNodes(): boolean {
    return this.nodes.length > 0;
  }

  /** HMAC-SHA256 签名 */
  signRequest(
    node: NodeConfig,
    method: string,
    reqPath: string,
    body?: string,
  ): Record<string, string> {
    // localhost 节点不签名
    if (node.host === 'localhost' || node.host === '127.0.0.1') {
      return {};
    }
    const timestamp = Date.now().toString();
    const payload = `${timestamp}\n${method}\n${reqPath}\n${body ?? ''}`;
    const signature = crypto
      .createHmac('sha256', node.secret || '')
      .update(payload)
      .digest('hex');
    return {
      'X-Node-Id': node.id,
      'X-Timestamp': timestamp,
      'X-Signature': signature,
    };
  }
}
