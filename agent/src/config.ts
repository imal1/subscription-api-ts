import * as fs from 'fs';

export interface AgentNodeConfig {
  id: string;
  name: string;
  secret: string;
}

export interface AgentKernelConfig {
  type: 'sing-box' | 'xray' | 'v2ray';
  configPath: string;
}

export interface AgentMihomoConfig {
  path: string;
}

export interface AgentConfig {
  node: AgentNodeConfig;
  kernel: AgentKernelConfig;
  mihomo: AgentMihomoConfig;
  port: number;
}

const DEFAULT_CONFIG_PATHS: Record<string, string> = {
  'sing-box': '/usr/local/etc/sing-box/config.json',
  'xray': '/usr/local/etc/xray/config.json',
  'v2ray': '/etc/v2ray/config.json',
};

export function getDefaultConfig(): AgentConfig {
  return {
    node: { id: '', name: '', secret: '' },
    kernel: { type: 'sing-box', configPath: '/usr/local/etc/sing-box/config.json' },
    mihomo: { path: '/usr/local/bin/mihomo' },
    port: 3001,
  };
}

function extractYamlValue(line: string): string {
  const idx = line.indexOf(':');
  if (idx === -1) return '';
  let val = line.substring(idx + 1).trim();
  if ((val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))) {
    val = val.slice(1, -1);
  }
  return val;
}

export async function loadConfig(filePath: string): Promise<AgentConfig> {
  const defaults = getDefaultConfig();

  try {
    if (!fs.existsSync(filePath)) {
      console.log(`[config] ${filePath} 不存在，使用默认配置`);
      return defaults;
    }

    const raw = fs.readFileSync(filePath, 'utf8');
    const lines = raw.split('\n');
    let section = '';

    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed === '') continue;

      // Reset section on top-level keys (non-indented)
      if (!line.startsWith(' ') && !line.startsWith('\t')) {
        section = '';
      }

      if (trimmed.startsWith('node:')) { section = 'node'; continue; }
      if (trimmed.startsWith('kernel:')) { section = 'kernel'; continue; }
      if (trimmed.startsWith('mihomo:')) { section = 'mihomo'; continue; }

      const val = extractYamlValue(trimmed);

      if (section === 'node') {
        if (trimmed.startsWith('id:')) defaults.node.id = val;
        else if (trimmed.startsWith('name:')) defaults.node.name = val;
        else if (trimmed.startsWith('secret:')) defaults.node.secret = val;
      } else if (section === 'kernel') {
        if (trimmed.startsWith('type:')) defaults.kernel.type = val as AgentConfig['kernel']['type'];
        else if (trimmed.startsWith('configPath:')) defaults.kernel.configPath = val;
      } else if (section === 'mihomo') {
        if (trimmed.startsWith('path:')) defaults.mihomo.path = val;
      }

      if (trimmed.startsWith('port:') && section === '') {
        defaults.port = parseInt(val) || 3001;
      }
    }

    // 如果没有指定 configPath，使用内核类型默认路径
    if (!defaults.kernel.configPath || defaults.kernel.configPath === '') {
      defaults.kernel.configPath = DEFAULT_CONFIG_PATHS[defaults.kernel.type] || '';
    }

    return defaults;
  } catch (error: any) {
    console.error(`[config] 解析失败: ${error.message}`);
    return defaults;
  }
}
