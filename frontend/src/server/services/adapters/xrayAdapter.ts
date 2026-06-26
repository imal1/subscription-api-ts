import * as fs from 'fs-extra';
import { logger } from '../../utils/logger';
import type { KernelAdapter, KernelType } from './kernelAdapter';

interface XrayOutbound {
  protocol: string;
  settings?: {
    vnext?: Array<{
      address: string;
      port: number;
      users?: Array<{
        id: string;
        flow?: string;
        encryption?: string;
      }>;
    }>;
    servers?: Array<{
      address: string;
      port: number;
      method?: string;
      password?: string;
    }>;
  };
  streamSettings?: {
    network?: string;
    security?: string;
    wsSettings?: { path?: string; headers?: Record<string, string> };
    realitySettings?: {
      serverName?: string;
      publicKey?: string;
      shortId?: string;
    };
    tlsSettings?: { serverName?: string };
  };
  tag?: string;
}

export class XrayAdapter implements KernelAdapter {
  readonly type: KernelType = 'xray';
  private configPath = '/usr/local/etc/xray/config.json';

  async getConfigPaths(): Promise<string[]> {
    return [this.configPath];
  }

  async extractNodeUrls(): Promise<string[]> {
    const urls: string[] = [];
    try {
      if (!(await fs.pathExists(this.configPath))) {
        logger.warn('XrayAdapter: config.json 不存在');
        return urls;
      }
      const raw = await fs.readFile(this.configPath, 'utf8');
      const cfg = JSON.parse(raw);

      for (const outbound of cfg.outbounds || []) {
        const url = this.outboundToUrl(outbound);
        if (url) urls.push(url);
      }
    } catch (error: any) {
      logger.error(`XrayAdapter: 解析配置失败: ${error.message}`);
    }
    return urls;
  }

  private outboundToUrl(out: XrayOutbound): string | null {
    const tag = out.tag || out.protocol;
    const vnext = out.settings?.vnext?.[0];
    const server = out.settings?.servers?.[0];

    if (out.protocol === 'vless' && vnext) {
      const user = vnext.users?.[0];
      const host = vnext.address;
      const port = vnext.port;
      const uuid = user?.id || '';
      const flow = user?.flow || '';
      const net = out.streamSettings?.network || 'tcp';
      const sec = out.streamSettings?.security || 'none';
      const sni = out.streamSettings?.tlsSettings?.serverName
        || out.streamSettings?.realitySettings?.serverName || host;
      const params = new URLSearchParams();
      params.set('type', net);
      if (sec !== 'none') params.set('security', sec);
      params.set('sni', sni);
      if (flow) params.set('flow', flow);
      if (net === 'ws' && out.streamSettings?.wsSettings?.path) {
        params.set('path', out.streamSettings.wsSettings.path);
      }
      if (sec === 'reality' && out.streamSettings?.realitySettings) {
        params.set('pbk', out.streamSettings.realitySettings.publicKey || '');
        params.set('sid', out.streamSettings.realitySettings.shortId || '');
      }
      return `vless://${uuid}@${host}:${port}?${params.toString()}#${encodeURIComponent(tag)}`;
    }

    if (out.protocol === 'vmess' && vnext) {
      const user = vnext.users?.[0];
      const vmessObj = {
        v: '2', ps: tag, add: vnext.address, port: vnext.port.toString(),
        id: user?.id || '', aid: '0', scy: 'auto', net: out.streamSettings?.network || 'tcp',
        type: 'none', host: '', path: '/', tls: out.streamSettings?.security === 'tls' ? 'tls' : '',
      };
      if (out.streamSettings?.wsSettings?.path) {
        vmessObj.path = out.streamSettings.wsSettings.path;
      }
      return `vmess://${Buffer.from(JSON.stringify(vmessObj)).toString('base64')}`;
    }

    if (out.protocol === 'trojan' && server) {
      const password = server.password || '';
      const host = server.address;
      const port = server.port;
      const sni = out.streamSettings?.tlsSettings?.serverName || host;
      const net = out.streamSettings?.network || 'tcp';
      const params = new URLSearchParams();
      if (net !== 'tcp') params.set('type', net);
      params.set('sni', sni);
      params.set('security', 'tls');
      return `trojan://${password}@${host}:${port}?${params.toString()}#${encodeURIComponent(tag)}`;
    }

    if ((out.protocol === 'shadowsocks' || out.protocol === 'ss') && server) {
      const method = server.method || 'aes-256-gcm';
      const password = server.password || '';
      const host = server.address;
      const port = server.port;
      const userinfo = Buffer.from(`${method}:${password}`).toString('base64');
      return `ss://${userinfo}@${host}:${port}#${encodeURIComponent(tag)}`;
    }

    return null;
  }

  async isAvailable(): Promise<boolean> {
    try {
      return await fs.pathExists(this.configPath);
    } catch {
      return false;
    }
  }
}
