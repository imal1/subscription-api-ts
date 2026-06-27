import { loadConfig } from './config';
import * as path from 'path';
import * as os from 'os';

const CONFIG_PATH = process.env.MIOBRIDGE_AGENT_CONFIG ||
  path.join(os.homedir(), '.config', 'miobridge-agent', 'agent.yaml');

async function main() {
  console.log('MioBridge Agent starting...');
  const config = await loadConfig(CONFIG_PATH);
  console.log(`Config loaded: node=${config.node.id}, kernel=${config.kernel.type}, port=${config.port}`);
  // HTTP server will be added in Task 2
}

main().catch((err) => {
  console.error('Agent failed to start:', err);
  process.exit(1);
});
