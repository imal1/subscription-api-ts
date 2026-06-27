import * as crypto from 'crypto';

interface IncomingRequest {
  method?: string;
  url?: string;
  headers: Record<string, string | string[] | undefined>;
  socket?: { remoteAddress?: string };
}

const TIME_WINDOW_MS = 30_000;
const usedTimestamps = new Set<string>();
let lastCleanup = Date.now();

function cleanupTimestamps(): void {
  const now = Date.now();
  if (now - lastCleanup < 60_000) return;
  usedTimestamps.clear();
  lastCleanup = now;
}

export function hmacVerify(
  req: IncomingRequest,
  secret: string,
): { valid: boolean; error?: string } {
  const remoteAddr = req.socket?.remoteAddress || '';
  if (remoteAddr === '127.0.0.1' || remoteAddr === '::1' || remoteAddr === 'localhost') {
    return { valid: true };
  }

  const nodeId = req.headers['x-node-id'] as string;
  const timestamp = req.headers['x-timestamp'] as string;
  const signature = req.headers['x-signature'] as string;

  if (!nodeId || !timestamp || !signature) {
    return { valid: false, error: '缺少 HMAC 认证头' };
  }

  const reqTime = parseInt(timestamp, 10);
  const now = Date.now();
  if (isNaN(reqTime) || Math.abs(now - reqTime) > TIME_WINDOW_MS) {
    return { valid: false, error: `时间戳超出窗口 (${TIME_WINDOW_MS / 1000}s)` };
  }

  cleanupTimestamps();
  if (usedTimestamps.has(timestamp)) {
    return { valid: false, error: '重放请求' };
  }
  usedTimestamps.add(timestamp);

  const method = req.method || 'GET';
  const reqPath = req.url || '/';
  const payload = `${timestamp}\n${method}\n${reqPath}\n`;

  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');

  try {
    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
      return { valid: false, error: '签名不匹配' };
    }
  } catch {
    return { valid: false, error: '签名格式错误' };
  }

  return { valid: true };
}
