import type { AgentConfig } from '../config';
import * as fs from 'fs';
import { hmacVerify } from '../hmac';
import { discoverKernelConfigFiles, extractNodeUrls } from './urls';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

export async function handleStatus(
  req: IncomingRequest,
  config: AgentConfig,
): Promise<Response> {
  if (config.node.secret) {
    const { valid, error } = hmacVerify(req, config.node.secret);
    if (!valid) {
      return new Response(
        JSON.stringify({ success: false, error: `认证失败: ${error}`, timestamp: new Date().toISOString() }),
        { status: 401, headers: { 'Content-Type': 'application/json' } },
      );
    }
  }

  try {
    const hostHeader = req.headers.host;
    const host = (Array.isArray(hostHeader) ? hostHeader[0] : hostHeader || '').split(':')[0];
    const urls = extractNodeUrls(config, host);
    const kernelAccessible = discoverKernelConfigFiles(config).length > 0;

    const subscriptionExists = fs.existsSync('/etc/miobridge-agent/www/subscription.txt');
    const clashExists = fs.existsSync('/etc/miobridge-agent/www/clash.yaml');

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          subscriptionExists,
          clashExists,
          rawExists: subscriptionExists,
          mihomoAvailable: fs.existsSync(config.mihomo.path),
          singBoxAccessible: kernelAccessible,
          nodesCount: urls.length,
          uptime: process.uptime(),
          version: '1.0.0',
        },
        timestamp: new Date().toISOString(),
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message, timestamp: new Date().toISOString() }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
}
