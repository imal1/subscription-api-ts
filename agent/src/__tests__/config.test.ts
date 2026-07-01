import { describe, it, expect, beforeAll, afterAll } from 'bun:test';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { loadConfig, getDefaultConfig } from '../config';

const TMP_DIR = path.join(os.tmpdir(), 'miobridge-agent-test-' + Date.now());
const CONFIG_PATH = path.join(TMP_DIR, 'agent.yaml');

describe('Agent Config', () => {
  beforeAll(() => {
    fs.mkdirSync(TMP_DIR, { recursive: true });
  });

  afterAll(() => {
    fs.rmSync(TMP_DIR, { recursive: true, force: true });
  });

  describe('getDefaultConfig', () => {
    it('should return default config with port 3001', () => {
      const cfg = getDefaultConfig();
      expect(cfg.port).toBe(3001);
      expect(cfg.node.id).toBe('');
      expect(cfg.node.secret).toBe('');
    });
  });

  describe('loadConfig', () => {
    it('should return default config when file does not exist', async () => {
      const cfg = await loadConfig('/nonexistent/agent.yaml');
      expect(cfg.port).toBe(3001);
    });

    it('should parse valid agent.yaml', async () => {
      const yaml = `
node:
  id: "node-sg"
  name: "新加坡"
  secret: "abc123"
kernel:
  type: "xray"
  configPath: "/etc/xray/config.json"
mihomo:
  path: "/usr/bin/mihomo"
port: 3002
`;
      fs.writeFileSync(CONFIG_PATH, yaml);
      const cfg = await loadConfig(CONFIG_PATH);
      expect(cfg.node.id).toBe('node-sg');
      expect(cfg.node.name).toBe('新加坡');
      expect(cfg.node.secret).toBe('abc123');
      expect(cfg.kernel.type).toBe('xray');
      expect(cfg.kernel.configPath).toBe('/etc/xray/config.json');
      expect(cfg.mihomo.path).toBe('/usr/bin/mihomo');
      expect(cfg.port).toBe(3002);
    });

    it('should handle missing optional fields with defaults', async () => {
      const yaml = `
node:
  id: "minimal"
kernel:
  type: "sing-box"
`;
      fs.writeFileSync(CONFIG_PATH, yaml);
      const cfg = await loadConfig(CONFIG_PATH);
      expect(cfg.node.id).toBe('minimal');
      expect(cfg.node.secret).toBe('');
      expect(cfg.kernel.configPath).toBe('/etc/sing-box/config.json');
      expect(cfg.port).toBe(3001);
    });
  });
});
