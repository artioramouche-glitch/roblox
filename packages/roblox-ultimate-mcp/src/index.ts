import { RobloxStudioMCPServer, getAllTools } from 'roblox-ultimate-mcp-core';
import { createRequire } from 'module';

const command = process.argv[2];
const fail = (err: unknown) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exitCode = 1;
};

if (command === 'setup') {
  const { runSetup } = await import('./setup.js');
  runSetup().catch(fail);
} else if (command === 'doctor') {
  const { runDoctor } = await import('./doctor.js');
  runDoctor().then(() => process.exit(process.exitCode ?? 0), fail);
} else if (command === 'help' || process.argv.includes('--help') || process.argv.includes('-h')) {
  const { HELP } = await import('./setup.js');
  console.log(HELP);
} else if (process.argv.includes('--install-plugin')) {
  const { installPlugin } = await import('./install-plugin.js');
  installPlugin().catch(fail);
} else if (process.argv.includes('--install-blender-addon')) {
  const { installBlenderAddon } = await import('./setup.js');
  console.log(installBlenderAddon().join('\n'));
} else if (process.stdin.isTTY && process.argv.length <= 2) {
  // A person typed the command in a terminal: AI apps start the server with pipes, not a TTY.
  const { HELP } = await import('./setup.js');
  console.log(HELP);
  console.log('Pour tout installer : npx roblox-ultimate-mcp setup');
} else {
  const flagValue = (flag: string): string | undefined => {
    const idx = process.argv.indexOf(flag);
    return idx !== -1 && idx + 1 < process.argv.length ? process.argv[idx + 1] : undefined;
  };

  const openCloudKey = flagValue('--open-cloud-key');
  const creatorId = flagValue('--creator-id');
  const creatorGroupId = flagValue('--creator-group-id');
  // Documented in the README since the multi-Studio instructions were written, and read
  // by nothing until now -- so `--port 58742` silently did nothing and the server landed
  // whereever the bind order happened to put it. Folded into the env var the core reads
  // rather than threaded through ServerConfig, so there is still one source for the port.
  const port = flagValue('--port');

  if (port) {
    if (!/^\d+$/.test(port) || Number(port) < 1 || Number(port) > 65535) {
      console.error(`--port must be a number between 1 and 65535, got "${port}"`);
      process.exit(1);
    }
    process.env.ROBLOX_STUDIO_PORT = port;
  }

  if (openCloudKey) process.env.ROBLOX_OPEN_CLOUD_API_KEY = openCloudKey;
  if (creatorId) process.env.ROBLOX_CREATOR_USER_ID = creatorId;
  if (creatorGroupId) process.env.ROBLOX_CREATOR_GROUP_ID = creatorGroupId;

  const require = createRequire(import.meta.url);
  const { version: VERSION } = require('../package.json');

  const server = new RobloxStudioMCPServer({
    name: 'roblox-ultimate-mcp',
    version: VERSION,
    tools: getAllTools(),
  });

  server.run().catch((error) => {
    console.error('Server failed to start:', error);
    process.exit(1);
  });
}
