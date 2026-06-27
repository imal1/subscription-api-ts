import { describe, it, expect, beforeEach } from 'vitest';
import { DeployManager } from '../deployManager';

describe('Task 5: DeployManager', () => {
  describe('singleton', () => {
    it('getInstance should return same instance', () => {
      const d1 = DeployManager.getInstance();
      const d2 = DeployManager.getInstance();
      expect(d1).toBe(d2);
    });
  });

  describe('getKernelInstallCmd', () => {
    it('should return sing-box 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('sing-box');
      expect(cmd).toContain('233boy/sing-box');
      expect(cmd).toContain('install.sh');
    });

    it('should return xray 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('xray');
      expect(cmd).toContain('233boy/Xray');
    });

    it('should return v2ray 233boy install command', () => {
      const dm = DeployManager.getInstance();
      const cmd = dm.getKernelInstallCmd('v2ray');
      expect(cmd).toContain('233boy/v2ray');
    });

    it('should throw for unknown kernel type', () => {
      const dm = DeployManager.getInstance();
      expect(() => dm.getKernelInstallCmd('unknown' as any)).toThrow('不支持的内核类型');
    });
  });

  describe('generateAgentYaml', () => {
    it('should generate valid agent.yaml content', () => {
      const dm = DeployManager.getInstance();
      const yaml = dm.generateAgentYaml('node-sg', '新加坡', 'secret123', 'xray', '/etc/xray/config.json');
      expect(yaml).toContain('id: "node-sg"');
      expect(yaml).toContain('name: "新加坡"');
      expect(yaml).toContain('secret: "secret123"');
      expect(yaml).toContain('type: "xray"');
    });
  });

  describe('generateSystemdUnit', () => {
    it('should generate valid systemd unit with secret', () => {
      const dm = DeployManager.getInstance();
      const unit = dm.generateSystemdUnit('my-secret-key');
      expect(unit).toContain('[Unit]');
      expect(unit).toContain('Description=MioBridge Agent');
      expect(unit).toContain('MIOBRIDGE_NODE_SECRET=my-secret-key');
      expect(unit).toContain('Restart=always');
    });
  });

  describe('generateHmacSecret', () => {
    it('should generate 64-char hex string', () => {
      const dm = DeployManager.getInstance();
      const secret = dm.generateHmacSecret();
      expect(secret).toMatch(/^[a-f0-9]{64}$/);
    });

    it('should generate unique secrets', () => {
      const dm = DeployManager.getInstance();
      const s1 = dm.generateHmacSecret();
      const s2 = dm.generateHmacSecret();
      expect(s1).not.toBe(s2);
    });
  });
});
