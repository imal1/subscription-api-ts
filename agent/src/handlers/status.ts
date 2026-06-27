import type { AgentConfig } from '../config';
import * as fs from 'fs';
import { hmacVerify } from '../hmac';

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
    let nodesCount = 0;
    let kernelAccessible = false;

    if (fs.existsSync(config.kernel.configPath)) {
      kernelAccessible = true;
      try {
        const raw = fs.readFileSync(config.kernel.configPath, 'utf8');
        const cfg = JSON.parse(raw);
        nodesCount = (cfg.outbounds || []).length;
      } catch {
        // config exists but can't be parsed
      }
    }

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
          nodesCount,
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
