import * as fs from 'fs-extra';
import * as path from 'path';
import * as os from 'os';
import * as crypto from 'crypto';
import { logger } from '../utils/logger';
import { MioBridgeService } from './mioBridgeService';
import type { NodeConfig, NodeStatus, ClusterStatus, NodesYaml, NodeAgentInfo } from '../types';

const NODES_YAML_PATH = path.join(os.homedir(), '.config', 'miobridge', 'nodes.yaml');
const REMOTE_TIMEOUT_MS = 10_000;
/** fs.watch 去抖延迟：文件可能连续触发多次 change 事件 */
const WATCH_DEBOUNCE_MS = 500;

export class NodeManager {
  private static instance: NodeManager;
  private nodes: NodeConfig[] = [];
  private localService: MioBridgeService;
  /** In-memory cache of last known remote node statuses */
  private nodeCache: Map<string, NodeStatus> = new Map();
  private watcher: fs.FSWatcher | null = null;
  private watchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

  private constructor() {
    this.localService = MioBridgeService.getInstance();
  }

  public static getInstance(): NodeManager {
    if (!NodeManager.instance) {
      NodeManager.instance = new NodeManager();
    }
    return NodeManager.instance;
  }

  /** 启动 nodes.yaml 文件监听（热加载） */
  startWatch(): void {
    if (this.watcher) return; // 防止重复启动

    try {
      // 确保父目录存在后再监听（目录不存在时 watch 会失败）
      const dir = path.dirname(NODES_YAML_PATH);
      if (!fs.existsSync(dir)) {
        logger.info('NodeManager: nodes.yaml 目录不存在，跳过文件监听');
        return;
      }

      this.watcher = fs.watch(NODES_YAML_PATH, (eventType) => {
        if (eventType !== 'change') return;
        // 去抖：短时间内的重复事件只触发一次
        if (this.watchDebounceTimer) clearTimeout(this.watchDebounceTimer);
        this.watchDebounceTimer = setTimeout(async () => {
          logger.info('NodeManager: 检测到 nodes.yaml 变更，重新加载节点...');
          await this.loadNodes();
        }, WATCH_DEBOUNCE_MS);
      });

      logger.info('NodeManager: nodes.yaml 文件监听已启动');
    } catch (error: any) {
      logger.warn(`NodeManager: 启动文件监听失败: ${error.message}`);
    }
  }

  /** 停止文件监听 */
  stopWatch(): void {
    if (this.watcher) {
      this.watcher.close();
      this.watcher = null;
    }
    if (this.watchDebounceTimer) {
      clearTimeout(this.watchDebounceTimer);
      this.watchDebounceTimer = null;
    }
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
    let subSection = '';
    const lines = raw.split('\n');

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed === '') continue;

      if (trimmed.startsWith('- id:')) {
        if (current.id) { nodes.push(current as NodeConfig); }
        current = { id: this.extractYamlValue(trimmed, 'id') };
        subSection = '';
      } else if (trimmed === 'ssh:') {
        subSection = 'ssh';
        current.ssh = { user: 'root', port: 22, keyPath: '', hostKey: '' };
      } else if (trimmed === 'agent:') {
        subSection = 'agent';
        current.agent = { deployed: false, version: '', status: 'not_deployed', lastDeploy: '' };
      } else if (trimmed === 'kernelInfo:') {
        subSection = 'kernelInfo';
        current.kernelInfo = { installed: false, version: '', installScript: '' };
      } else if (subSection === 'ssh') {
        if (trimmed.startsWith('user:')) current.ssh!.user = this.extractYamlValue(trimmed, 'user');
        else if (trimmed.startsWith('port:')) current.ssh!.port = parseInt(this.extractYamlValue(trimmed, 'port')) || 22;
        else if (trimmed.startsWith('keyPath:')) current.ssh!.keyPath = this.extractYamlValue(trimmed, 'keyPath');
        else if (trimmed.startsWith('hostKey:')) current.ssh!.hostKey = this.extractYamlValue(trimmed, 'hostKey');
      } else if (subSection === 'agent') {
        if (trimmed.startsWith('deployed:')) current.agent!.deployed = this.extractYamlValue(trimmed, 'deployed') === 'true';
        else if (trimmed.startsWith('version:')) current.agent!.version = this.extractYamlValue(trimmed, 'version');
        else if (trimmed.startsWith('status:')) current.agent!.status = this.extractYamlValue(trimmed, 'status') as NodeAgentInfo['status'];
        else if (trimmed.startsWith('lastDeploy:')) current.agent!.lastDeploy = this.extractYamlValue(trimmed, 'lastDeploy');
      } else if (subSection === 'kernelInfo') {
        if (trimmed.startsWith('installed:')) current.kernelInfo!.installed = this.extractYamlValue(trimmed, 'installed') === 'true';
        else if (trimmed.startsWith('version:')) current.kernelInfo!.version = this.extractYamlValue(trimmed, 'version');
        else if (trimmed.startsWith('installScript:')) current.kernelInfo!.installScript = this.extractYamlValue(trimmed, 'installScript');
      } else if (trimmed.startsWith('name:')) {
        current.name = this.extractYamlValue(trimmed, 'name');
      } else if (trimmed.startsWith('host:')) {
        current.host = this.extractYamlValue(trimmed, 'host');
      } else if (trimmed.startsWith('port:') && !line.includes('ssh')) {
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

  /** 获取节点缓存（供 Dashboard 使用） */
  getNodeCache(): Map<string, NodeStatus> {
    return this.nodeCache;
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

  // ==================== 远程节点 HTTP 轮询 ====================

  /** 从远程节点获取状态 */
  private async fetchRemoteStatus(node: NodeConfig): Promise<NodeStatus> {
    const baseStatus: NodeStatus = {
      nodeId: node.id,
      name: node.name,
      kernel: node.kernel,
      location: node.location,
      online: false,
    };

    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), REMOTE_TIMEOUT_MS);

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...this.signRequest(node, 'GET', '/api/status'),
      };

      const url = `https://${node.host}:${node.port}/api/status`;
      const response = await fetch(url, {
        method: 'GET',
        headers,
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!response.ok) {
        return {
          ...baseStatus,
          online: false,
          error: `HTTP ${response.status}: ${response.statusText}`,
        };
      }

      const json = await response.json();
      const data = json.data || json;

      const status: NodeStatus = {
        ...baseStatus,
        online: true,
        latency: 0, // will be set by health check
        nodesCount: data.nodesCount,
        subscriptionExists: data.subscriptionExists,
        clashExists: data.clashExists,
        mihomoAvailable: data.mihomoAvailable,
        kernelAccessible: data.singBoxAccessible,
        version: data.version,
        uptime: data.uptime,
        agent: node.agent,
      };

      this.nodeCache.set(node.id, status);
      return status;
    } catch (error: any) {
      const errorMsg = error.name === 'AbortError'
        ? '请求超时'
        : `连接失败: ${error.message}`;
      const status: NodeStatus = { ...baseStatus, online: false, error: errorMsg };
      this.nodeCache.set(node.id, status);
      return status;
    }
  }

  /** 触发远程节点更新 */
  private async fetchRemoteUpdate(node: NodeConfig): Promise<{ success: boolean; message: string }> {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), REMOTE_TIMEOUT_MS * 3); // update takes longer

      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        ...this.signRequest(node, 'GET', '/api/update'),
      };

      const url = `https://${node.host}:${node.port}/api/update`;
      const response = await fetch(url, {
        method: 'GET',
        headers,
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!response.ok) {
        return { success: false, message: `节点 ${node.name} HTTP ${response.status}` };
      }

      const json = await response.json();
      return { success: true, message: `节点 ${node.name}: ${json.message || '更新成功'}` };
    } catch (error: any) {
      const errorMsg = error.name === 'AbortError'
        ? '请求超时'
        : `节点 ${node.name} 离线: ${error.message}`;
      return { success: false, message: errorMsg };
    }
  }

  /** 远程节点健康检查（测延迟） */
  private async fetchRemoteHealth(node: NodeConfig): Promise<{ online: boolean; latency: number }> {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), REMOTE_TIMEOUT_MS);

      const headers: Record<string, string> = {
        ...this.signRequest(node, 'GET', '/api/health'),
      };

      const url = `https://${node.host}:${node.port}/health`;
      const start = Date.now();
      const response = await fetch(url, {
        method: 'GET',
        headers,
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (!response.ok) {
        return { online: false, latency: 0 };
      }

      return { online: true, latency: Date.now() - start };
    } catch {
      return { online: false, latency: 0 };
    }
  }

  // ==================== 集群聚合操作 ====================

  /** 聚合集群状态 */
  async getClusterStatus(): Promise<ClusterStatus> {
    // 获取本地节点状态
    const localStatus = await this.getLocalNodeStatus();
    const allStatuses: NodeStatus[] = [localStatus];

    // 并发轮询所有远程节点
    if (this.nodes.length > 0) {
      const remoteResults = await Promise.allSettled(
        this.nodes.map(node => this.fetchRemoteStatus(node))
      );

      for (const result of remoteResults) {
        if (result.status === 'fulfilled') {
          allStatuses.push(result.value);
        }
        // rejected results are silently skipped — the node will be missing from the cluster view
      }
    }

    return this.buildClusterStatus(allStatuses);
  }

  /** 构建本地节点状态 */
  private async getLocalNodeStatus(): Promise<NodeStatus> {
    try {
      const status = await this.localService.getStatus();
      const nodeStatus: NodeStatus = {
        nodeId: 'local',
        name: '本地',
        kernel: 'sing-box',
        location: '本地',
        online: true,
        latency: 0,
        nodesCount: status.nodesCount || 0,
        subscriptionExists: status.subscriptionExists,
        clashExists: status.clashExists,
        mihomoAvailable: status.mihomoAvailable,
        kernelAccessible: status.singBoxAccessible,
        version: status.version,
        uptime: status.uptime,
      };
      this.nodeCache.set('local', nodeStatus);
      return nodeStatus;
    } catch (error: any) {
      return {
        nodeId: 'local',
        name: '本地',
        kernel: 'sing-box',
        location: '本地',
        online: false,
        error: error.message,
      };
    }
  }

  /** 构建 ClusterStatus */
  private buildClusterStatus(allStatuses: NodeStatus[]): ClusterStatus {
    const onlineNodes = allStatuses.filter(n => n.online);
    const totalProxies = allStatuses.reduce((sum, n) => sum + (n.nodesCount || 0), 0);
    return {
      totalNodes: allStatuses.length,
      onlineNodes: onlineNodes.length,
      totalProxies,
      nodes: allStatuses,
      lastUpdated: new Date().toISOString(),
    };
  }

  /** 触发更新（本地 + 远程） */
  async triggerUpdate(nodeId?: string): Promise<{
    results: Record<string, { success: boolean; message: string }>;
  }> {
    const results: Record<string, { success: boolean; message: string }> = {};

    // If a specific remote node is requested
    if (nodeId && nodeId !== 'local') {
      const targetNode = this.nodes.find(n => n.id === nodeId);
      if (targetNode) {
        results[nodeId] = await this.fetchRemoteUpdate(targetNode);
      } else {
        results[nodeId] = { success: false, message: `节点 ${nodeId} 不存在` };
      }
      return { results };
    }

    // Update local
    try {
      const result = await this.localService.updateSubscription();
      results['local'] = { success: true, message: result.message };
    } catch (error: any) {
      results['local'] = { success: false, message: error.message };
    }

    // Update all remote nodes concurrently
    if (this.nodes.length > 0) {
      const remoteResults = await Promise.allSettled(
        this.nodes.map(async (node) => {
          const r = await this.fetchRemoteUpdate(node);
          return { nodeId: node.id, result: r };
        })
      );

      for (const r of remoteResults) {
        if (r.status === 'fulfilled') {
          results[r.value.nodeId] = r.value.result;
        }
      }
    }

    return { results };
  }

  /** 健康检查（本地 + 远程） */
  async healthCheck(nodeId?: string): Promise<
    Record<string, { online: boolean; latency: number }>
  > {
    const results: Record<string, { online: boolean; latency: number }> = {};

    // If a specific remote node is requested
    if (nodeId && nodeId !== 'local') {
      const targetNode = this.nodes.find(n => n.id === nodeId);
      if (targetNode) {
        results[nodeId] = await this.fetchRemoteHealth(targetNode);
      } else {
        results[nodeId] = { online: false, latency: 0 };
      }
      return results;
    }

    // Check local
    try {
      const start = Date.now();
      await this.localService.getStatus();
      results['local'] = { online: true, latency: Date.now() - start };
    } catch {
      results['local'] = { online: false, latency: 0 };
    }

    // Check all remote nodes concurrently
    if (this.nodes.length > 0) {
      const remoteResults = await Promise.allSettled(
        this.nodes.map(async (node) => {
          const r = await this.fetchRemoteHealth(node);
          return { nodeId: node.id, result: r };
        })
      );

      for (const r of remoteResults) {
        if (r.status === 'fulfilled') {
          results[r.value.nodeId] = r.value.result;
        }
      }
    }

    return results;
  }
}
