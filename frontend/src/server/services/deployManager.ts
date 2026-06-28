import * as crypto from 'crypto';
import * as path from 'path';
import { Client, type ClientChannel } from 'ssh2';
import { logger } from '../utils/logger';
import type { NodeConfig, NodeAgentInfo } from '../types';

const KERNEL_INSTALL_SCRIPTS: Record<string, string> = {
  'sing-box': "bash <(wget -qO- -o- https://github.com/233boy/sing-box/raw/main/install.sh)",
  'xray': "bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)",
  'v2ray': "bash <(wget -qO- -o- https://github.com/233boy/v2ray/raw/master/install.sh)",
};

const AGENT_LOCAL_BINARY = path.resolve(process.cwd(), '..', 'agent', 'miobridge-agent');
const AGENT_REMOTE_PATH = '/usr/local/bin/miobridge-agent';
const AGENT_CONFIG_DIR = '/etc/miobridge-agent';
const AGENT_CONFIG_PATH = '/etc/miobridge-agent/agent.yaml';

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

export interface DeployTarget {
  nodeId: string;
  ssh: {
    host: string;
    user: string;
    port: number;
    keyPath: string;
    hostKey: string;
    password?: string;
  };
  agentPort?: number;
}

export interface DeployResult {
  success: boolean;
  message: string;
}

export type DeployProgressCallback = (step: DeployStep) => void;

export class DeployManager {
  private static instance: DeployManager;

  public static getInstance(): DeployManager {
    if (!DeployManager.instance) {
      DeployManager.instance = new DeployManager();
    }
    return DeployManager.instance;
  }

  private constructor() {}

  /** 部署 Agent 到远程节点 */
  async deployToNode(
    target: DeployTarget,
    onProgress?: DeployProgressCallback,
  ): Promise<DeployResult> {
    const emit = (step: DeployStep) => {
      logger.info(`DeployManager [${target.nodeId}]: ${step.step} — ${step.message}`);
      onProgress?.(step);
    };

    try {
      // Step 1: connect
      emit({ step: 'connect', status: 'running', message: '正在建立 SSH 连接...', progress: 5 });

      const ssh = await this.connectSsh(target);

      emit({ step: 'connect', status: 'success', message: 'SSH 连接成功', progress: 15 });

      // Step 2: bun
      emit({ step: 'bun', status: 'running', message: '检查 Bun 运行时...', progress: 20 });

      const bunOk = await this.ensureBun(ssh, emit);
      if (!bunOk) {
        return { success: false, message: 'Bun 安装失败' };
      }

      emit({ step: 'bun', status: 'success', message: 'Bun 已就绪', progress: 35 });

      // Step 3: kernel
      emit({ step: 'kernel', status: 'running', message: '检查内核...', progress: 40 });

      const kernelType = target.nodeId.includes('xray') ? 'xray' : 'sing-box';
      await this.ensureKernel(ssh, kernelType, emit);

      emit({ step: 'kernel', status: 'success', message: '内核已就绪', progress: 55 });

      // Step 4: agent
      emit({ step: 'agent', status: 'running', message: '上传 Agent 二进制...', progress: 60 });

      await this.uploadAgent(ssh, target, emit);

      emit({ step: 'agent', status: 'success', message: 'Agent 部署完成', progress: 80 });

      // Step 5: start
      emit({ step: 'start', status: 'running', message: '启动 Agent 服务...', progress: 85 });

      await this.startAgent(ssh, emit);

      emit({ step: 'start', status: 'success', message: 'Agent 已启动', progress: 92 });

      // Step 6: verify
      emit({ step: 'verify', status: 'running', message: '验证 Agent 健康状态...', progress: 95 });

      await this.verifyAgent(ssh, target, emit);

      emit({ step: 'verify', status: 'success', message: 'Agent 健康检查通过', progress: 98 });

      // Done
      emit({ step: 'done', status: 'success', message: '部署完成', progress: 100 });

      ssh.end();
      return { success: true, message: `Agent 部署到节点 ${target.nodeId} 成功` };
    } catch (error: any) {
      logger.error(`DeployManager: 部署到节点 ${target.nodeId} 失败: ${error.message}`);
      return { success: false, message: error.message };
    }
  }

  // ==================== SSH Helpers ====================

  private connectSsh(target: DeployTarget): Promise<Client> {
    return new Promise((resolve, reject) => {
      const conn = new Client();

      conn.on('ready', () => resolve(conn));
      conn.on('error', (err: Error) => reject(new Error(`SSH 连接失败: ${err.message}`)));

      const connectOpts: any = {
        host: target.ssh.host,
        port: target.ssh.port || 22,
        username: target.ssh.user || 'root',
        readyTimeout: 15000,
        // Skip host key verification for first-time connections
        algorithms: {
          serverHostKey: ['ssh-rsa', 'ssh-dss', 'ecdsa-sha2-nistp256', 'ssh-ed25519'],
        },
      };

      // Auth: prefer key, fallback to password
      if (target.ssh.keyPath) {
        connectOpts.privateKey = target.ssh.keyPath;
        if (target.ssh.password) {
          connectOpts.passphrase = target.ssh.password;
        }
      } else if (target.ssh.password) {
        connectOpts.password = target.ssh.password;
      } else {
        // Try agent-based auth
        connectOpts.agent = process.env.SSH_AUTH_SOCK || undefined;
      }

      // Add host key verification if provided
      if (target.ssh.hostKey) {
        connectOpts.hostHash = 'sha256';
        connectOpts.hostVerifier = (hashedKey: Buffer) => {
          return hashedKey.toString('base64') === target.ssh.hostKey;
        };
      } else {
        // Accept any host key on first connect
        connectOpts.hostVerifier = () => true;
      }

      conn.connect(connectOpts);
    });
  }

  private execSsh(ssh: Client, command: string): Promise<{ stdout: string; stderr: string; code: number }> {
    return new Promise((resolve, reject) => {
      ssh.exec(command, (err: Error | undefined, channel: ClientChannel) => {
        if (err) return reject(err);

        let stdout = '';
        let stderr = '';

        channel.on('data', (data: Buffer) => { stdout += data.toString(); });
        channel.stderr.on('data', (data: Buffer) => { stderr += data.toString(); });

        channel.on('close', (code: number) => {
          resolve({ stdout, stderr, code: code ?? -1 });
        });
      });
    });
  }

  // ==================== Deploy Steps ====================

  private async ensureBun(ssh: Client, emit: (s: DeployStep) => void): Promise<boolean> {
    const check = await this.execSsh(ssh, 'which bun 2>/dev/null && bun --version 2>/dev/null || echo "NOT_FOUND"');

    if (check.stdout.includes('NOT_FOUND')) {
      logger.info('DeployManager: Bun 未安装，正在安装...');
      emit({ step: 'bun', status: 'running', message: '正在安装 Bun...', progress: 25 });

      const install = await this.execSsh(
        ssh,
        'curl -fsSL https://bun.sh/install | bash 2>&1',
      );

      if (install.code !== 0) {
        emit({ step: 'bun', status: 'error', message: `Bun 安装失败: ${install.stderr}`, progress: 30 });
        return false;
      }

      // Add bun to PATH via .bashrc
      await this.execSsh(ssh, 'export BUN_INSTALL="$HOME/.bun" && export PATH="$BUN_INSTALL/bin:$PATH" && echo \'export BUN_INSTALL="$HOME/.bun"\' >> ~/.bashrc && echo \'export PATH="$BUN_INSTALL/bin:$PATH"\' >> ~/.bashrc');

      // Verify installation
      const verify = await this.execSsh(ssh, 'export PATH="$HOME/.bun/bin:$PATH" && bun --version 2>&1');
      if (verify.code !== 0) {
        emit({ step: 'bun', status: 'error', message: `Bun 安装验证失败: ${verify.stderr}`, progress: 30 });
        return false;
      }

      logger.info(`DeployManager: Bun ${verify.stdout.trim()} 安装成功`);
    } else {
      logger.info(`DeployManager: Bun 已安装: ${check.stdout.trim()}`);
    }

    return true;
  }

  private async ensureKernel(
    ssh: Client,
    kernelType: string,
    emit: (s: DeployStep) => void,
  ): Promise<void> {
    // Check if kernel is already installed
    const kernelBin = kernelType === 'xray' ? 'xray' : (kernelType === 'v2ray' ? 'v2ray' : 'sing-box');
    const check = await this.execSsh(ssh, `which ${kernelBin} 2>/dev/null && echo "FOUND" || echo "NOT_FOUND"`);

    if (check.stdout.includes('NOT_FOUND')) {
      const installCmd = KERNEL_INSTALL_SCRIPTS[kernelType];
      if (!installCmd) {
        emit({ step: 'kernel', status: 'error', message: `不支持的内核: ${kernelType}`, progress: 50 });
        throw new Error(`不支持的内核类型: ${kernelType}`);
      }

      emit({ step: 'kernel', status: 'running', message: `正在安装 ${kernelType} 内核...`, progress: 45 });

      const install = await this.execSsh(ssh, installCmd + ' 2>&1');

      if (install.code !== 0 && !install.stdout.includes('installed') && !install.stdout.includes('success')) {
        emit({ step: 'kernel', status: 'error', message: `内核安装失败: ${install.stderr || install.stdout}`, progress: 50 });
        throw new Error(`内核安装失败: ${install.stderr || install.stdout}`);
      }

      logger.info(`DeployManager: ${kernelType} 内核安装完成`);
    } else {
      logger.info(`DeployManager: ${kernelType} 内核已安装`);
    }
  }

  private uploadAgent(
    ssh: Client,
    target: DeployTarget,
    emit: (s: DeployStep) => void,
  ): Promise<void> {
    return new Promise((resolve, reject) => {
      ssh.sftp((err: Error | undefined, sftp: any) => {
        if (err) {
          emit({ step: 'agent', status: 'error', message: `SFTP 失败: ${err.message}`, progress: 70 });
          return reject(err);
        }

        // Create directories
        const mkdirCmd = `mkdir -p ${AGENT_CONFIG_DIR} /usr/local/bin 2>&1`;
        this.execSsh(ssh, mkdirCmd).then(() => {
          // Upload agent binary
          sftp.fastPut(
            AGENT_LOCAL_BINARY,
            AGENT_REMOTE_PATH,
            { mode: 0o755 },
            (putErr: Error | undefined) => {
              if (putErr) {
                emit({ step: 'agent', status: 'error', message: `上传失败: ${putErr.message}`, progress: 70 });
                return reject(putErr);
              }

              logger.info('DeployManager: Agent 二进制上传完成');

              // Write agent.yaml
              const secret = crypto.randomBytes(32).toString('hex');
              const agentYaml = this.generateAgentYaml(
                target.nodeId,
                target.nodeId,
                secret,
                'sing-box',
              );

              const writeYamlCmd = `cat > ${AGENT_CONFIG_PATH} << 'YAML_EOF'\n${agentYaml}YAML_EOF\n`;
              this.execSsh(ssh, writeYamlCmd).then(() => {
                // Write systemd unit
                const systemdUnit = this.generateSystemdUnit(secret);
                const writeUnitCmd = `cat > /etc/systemd/system/miobridge-agent.service << 'UNIT_EOF'\n${systemdUnit}UNIT_EOF\n`;

                this.execSsh(ssh, writeUnitCmd).then(() => {
                  logger.info('DeployManager: agent.yaml 和 systemd unit 已写入');
                  resolve();
                }).catch(reject);
              }).catch(reject);
            },
          );
        }).catch(reject);
      });
    });
  }

  private async startAgent(ssh: Client, emit: (s: DeployStep) => void): Promise<void> {
    const result = await this.execSsh(
      ssh,
      'systemctl daemon-reload && systemctl enable miobridge-agent 2>&1 && systemctl start miobridge-agent 2>&1 || systemctl restart miobridge-agent 2>&1',
    );

    if (result.code !== 0) {
      emit({ step: 'start', status: 'error', message: `启动失败: ${result.stderr || result.stdout}`, progress: 90 });
      throw new Error(`systemctl 启动失败: ${result.stderr || result.stdout}`);
    }

    // Wait a moment for the service to come up
    await new Promise(r => setTimeout(r, 2000));

    const status = await this.execSsh(ssh, 'systemctl is-active miobridge-agent 2>&1');
    if (!status.stdout.includes('active')) {
      emit({ step: 'start', status: 'error', message: `服务未运行: ${status.stdout.trim()}`, progress: 90 });
      throw new Error(`服务状态异常: ${status.stdout.trim()}`);
    }

    logger.info('DeployManager: Agent 服务已启动');
  }

  private async verifyAgent(
    ssh: Client,
    target: DeployTarget,
    emit: (s: DeployStep) => void,
  ): Promise<void> {
    const port = target.agentPort || 3001;
    const healthUrl = `http://localhost:${port}/health`;

    // Try curl health check from remote host
    const result = await this.execSsh(
      ssh,
      `for i in 1 2 3 4 5; do curl -s -o /dev/null -w "%{http_code}" ${healthUrl} 2>/dev/null && break; sleep 2; done`,
    );

    if (!result.stdout.includes('200')) {
      emit({ step: 'verify', status: 'error', message: `健康检查失败: HTTP ${result.stdout.trim() || 'timeout'}`, progress: 98 });
      throw new Error(`Agent 健康检查失败: ${result.stdout.trim() || 'timeout'}`);
    }

    logger.info('DeployManager: Agent 健康检查通过');
  }

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
