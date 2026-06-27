import * as crypto from 'crypto';
import { logger } from '../utils/logger';
import type { NodeConfig, NodeAgentInfo } from '../types';

const KERNEL_INSTALL_SCRIPTS: Record<string, string> = {
  'sing-box': "bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)",
  'xray': "bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)",
  'v2ray': "bash <(wget -qO- -o- https://github.com/233boy/v2ray/raw/master/install.sh)",
};

export interface DeployStep {
  step: 'connect' | 'bun' | 'kernel' | 'agent' | 'start' | 'verify' | 'done';
  status: 'pending' | 'running' | 'success' | 'error';
  message: string;
  progress: number;
}

export interface AgentStatus {
  deployed: boolean;
  version: string;
  status: NodeAgentInfo['status'];
  lastDeploy: string;
  bunVersion: string;
  kernelVersion: string;
}

export class DeployManager {
  private static instance: DeployManager;

  public static getInstance(): DeployManager {
    if (!DeployManager.instance) {
      DeployManager.instance = new DeployManager();
    }
    return DeployManager.instance;
  }

  private constructor() {}

  /** 获取内核安装命令 */
  getKernelInstallCmd(kernelType: string): string {
    const cmd = KERNEL_INSTALL_SCRIPTS[kernelType];
    if (!cmd) {
      throw new Error(`不支持的内核类型: ${kernelType}`);
    }
    return cmd;
  }

  /** 生成 agent.yaml 内容 */
  generateAgentYaml(
    nodeId: string,
    nodeName: string,
    secret: string,
    kernelType: string,
    kernelConfigPath?: string,
  ): string {
    const configPath = kernelConfigPath || this.getDefaultConfigPath(kernelType);
    return `# MioBridge Agent 配置 — 由控制面自动生成
node:
  id: "${nodeId}"
  name: "${nodeName}"
  secret: "${secret}"

kernel:
  type: "${kernelType}"
  configPath: "${configPath}"

mihomo:
  path: "/usr/local/bin/mihomo"

port: 3001
`;
  }

  /** 生成 systemd unit 内容 */
  generateSystemdUnit(secret: string): string {
    return `[Unit]
Description=MioBridge Agent
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/miobridge-agent
WorkingDirectory=/etc/miobridge-agent
Environment=MIOBRIDGE_NODE_SECRET=${secret}
Environment=MIOBRIDGE_AGENT_CONFIG=/etc/miobridge-agent/agent.yaml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`;
  }

  /** 生成 64 字符随机 HMAC secret */
  generateHmacSecret(): string {
    return crypto.randomBytes(32).toString('hex');
  }

  private getDefaultConfigPath(kernelType: string): string {
    const paths: Record<string, string> = {
      'sing-box': '/usr/local/etc/sing-box/config.json',
      'xray': '/usr/local/etc/xray/config.json',
      'v2ray': '/etc/v2ray/config.json',
    };
    return paths[kernelType] || '';
  }
}
