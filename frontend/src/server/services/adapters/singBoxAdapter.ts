import { exec } from 'child_process';
import { promisify } from 'util';
import { config } from '../../config';
import { logger } from '../../utils/logger';
import type { KernelAdapter, KernelType } from './kernelAdapter';

const execAsync = promisify(exec);

export class SingBoxAdapter implements KernelAdapter {
  readonly type: KernelType = 'sing-box';

  async getConfigPaths(): Promise<string[]> {
    // sing-box 233boy 安装的配置路径
    return ['/usr/local/etc/sing-box/config.json'];
  }

  async extractNodeUrls(): Promise<string[]> {
    const urls: string[] = [];
    for (const cfg of config.singBoxConfigs) {
      try {
        const { stdout } = await execAsync(`sing-box url ${cfg}`, {
          timeout: config.requestTimeout,
        });
        if (stdout && stdout.trim()) {
          urls.push(stdout.trim());
        }
      } catch (error: any) {
        logger.warn(`SingBoxAdapter: 获取 ${cfg} URL 失败: ${error.message}`);
      }
    }
    return urls;
  }

  async isAvailable(): Promise<boolean> {
    try {
      await execAsync('sing-box version', { timeout: 5000 });
      return true;
    } catch {
      return false;
    }
  }
}
