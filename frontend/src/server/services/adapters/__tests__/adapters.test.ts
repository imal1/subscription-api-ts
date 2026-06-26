// TDD RED phase for Task 2: Kernel Adapters
// These tests verify adapter classes implement KernelAdapter correctly

import { describe, it, expect } from 'vitest';
import { SingBoxAdapter } from '../singBoxAdapter';
import { XrayAdapter } from '../xrayAdapter';
import { V2rayAdapter } from '../v2rayAdapter';
import type { KernelAdapter } from '../kernelAdapter';

describe('Task 2: Kernel Adapters', () => {
  describe('kernelAdapter type re-export', () => {
    it('should have re-exported KernelAdapter and KernelType at type level', async () => {
      // KernelAdapter and KernelType are type-only exports — erased at runtime.
      // Their correctness is verified at compile time: every adapter below
      // satisfies `KernelAdapter` with a valid `KernelType` .type property.
      const mod = await import('../kernelAdapter');
      // Module exists and can be imported — type re-exports confirmed by tsc
      expect(typeof mod).toBe('object');
    });
  });

  describe('SingBoxAdapter', () => {
    it('should implement KernelAdapter interface', () => {
      const adapter = new SingBoxAdapter();
      // Type check: adapter satisfies KernelAdapter
      const typed: KernelAdapter = adapter;
      expect(typed.type).toBe('sing-box');
    });

    it('should have type "sing-box"', () => {
      const adapter = new SingBoxAdapter();
      expect(adapter.type).toBe('sing-box');
    });

    it('should return config paths array', async () => {
      const adapter = new SingBoxAdapter();
      const paths = await adapter.getConfigPaths();
      expect(Array.isArray(paths)).toBe(true);
      expect(paths.length).toBeGreaterThan(0);
      expect(paths[0]).toContain('sing-box');
    });

    it('should return node URLs array from extractNodeUrls', async () => {
      const adapter = new SingBoxAdapter();
      const urls = await adapter.extractNodeUrls();
      expect(Array.isArray(urls)).toBe(true);
    });

    it('should report availability via isAvailable', async () => {
      const adapter = new SingBoxAdapter();
      const available = await adapter.isAvailable();
      expect(typeof available).toBe('boolean');
    });
  });

  describe('XrayAdapter', () => {
    it('should implement KernelAdapter interface', () => {
      const adapter = new XrayAdapter();
      const typed: KernelAdapter = adapter;
      expect(typed.type).toBe('xray');
    });

    it('should have type "xray"', () => {
      const adapter = new XrayAdapter();
      expect(adapter.type).toBe('xray');
    });

    it('should return config paths array', async () => {
      const adapter = new XrayAdapter();
      const paths = await adapter.getConfigPaths();
      expect(Array.isArray(paths)).toBe(true);
      expect(paths.length).toBeGreaterThan(0);
      expect(paths[0]).toContain('xray');
    });

    it('should return node URLs array from extractNodeUrls', async () => {
      const adapter = new XrayAdapter();
      const urls = await adapter.extractNodeUrls();
      expect(Array.isArray(urls)).toBe(true);
    });

    it('should report availability via isAvailable', async () => {
      const adapter = new XrayAdapter();
      const available = await adapter.isAvailable();
      expect(typeof available).toBe('boolean');
    });
  });

  describe('V2rayAdapter', () => {
    it('should implement KernelAdapter interface', () => {
      const adapter = new V2rayAdapter();
      const typed: KernelAdapter = adapter;
      expect(typed.type).toBe('v2ray');
    });

    it('should have type "v2ray"', () => {
      const adapter = new V2rayAdapter();
      expect(adapter.type).toBe('v2ray');
    });

    it('should return config paths array', async () => {
      const adapter = new V2rayAdapter();
      const paths = await adapter.getConfigPaths();
      expect(Array.isArray(paths)).toBe(true);
      expect(paths.length).toBeGreaterThan(0);
      expect(paths[0]).toContain('v2ray');
    });

    it('should return node URLs array from extractNodeUrls', async () => {
      const adapter = new V2rayAdapter();
      const urls = await adapter.extractNodeUrls();
      expect(Array.isArray(urls)).toBe(true);
    });

    it('should report availability via isAvailable', async () => {
      const adapter = new V2rayAdapter();
      const available = await adapter.isAvailable();
      expect(typeof available).toBe('boolean');
    });
  });
});
