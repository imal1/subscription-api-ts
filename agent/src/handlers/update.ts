import type { AgentConfig } from '../config';
import { spawn } from 'child_process';
import { hmacVerify } from '../hmac';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

export async function handleUpdate(
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

  return new Promise((resolve) => {
    const child = spawn(config.mihomo.path, ['convert'], {
      timeout: 120_000,
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';

    child.stdout?.on('data', (d: Buffer) => { stdout += d.toString(); });
    child.stderr?.on('data', (d: Buffer) => { stderr += d.toString(); });

    child.on('close', (code: number | null) => {
      if (code === 0) {
        resolve(new Response(
          JSON.stringify({
            success: true,
            data: { nodesCount: stdout.split('\n').filter(Boolean).length },
            message: '订阅更新成功',
            timestamp: new Date().toISOString(),
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        ));
      } else {
        resolve(new Response(
          JSON.stringify({
            success: false,
            error: stderr || `mihomo exited with code ${code}`,
            message: `更新失败: ${stderr || `exit code ${code}`}`,
            timestamp: new Date().toISOString(),
          }),
          { status: 500, headers: { 'Content-Type': 'application/json' } },
        ));
      }
    });

    child.on('error', (err: Error) => {
      resolve(new Response(
        JSON.stringify({ success: false, error: err.message, message: `更新失败: ${err.message}`, timestamp: new Date().toISOString() }),
        { status: 500, headers: { 'Content-Type': 'application/json' } },
      ));
    });
  });
}
