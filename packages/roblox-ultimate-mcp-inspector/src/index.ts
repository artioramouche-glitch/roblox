import { RobloxStudioMCPServer, getReadOnlyTools } from 'roblox-ultimate-mcp-core';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { version: VERSION } = require('../package.json');

// Read-only tools are already few: list them all unless the user picked a profile.
process.env.ROBLOX_MCP_PROFILE ??= 'full';

const server = new RobloxStudioMCPServer({
  name: 'robloxstudio-mcp-inspector',
  version: VERSION,
  tools: getReadOnlyTools(),
});

server.run().catch((error) => {
  console.error('Server failed to start:', error);
  process.exit(1);
});
