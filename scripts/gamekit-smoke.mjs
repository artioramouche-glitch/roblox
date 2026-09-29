#!/usr/bin/env node
/**
 * End-to-end MCP smoke test: starts dist/index.js over stdio like an AI client would,
 * then checks instructions, tool profiles, prompts, resources and an offline tool call.
 * Usage: npm run build && node scripts/gamekit-smoke.mjs
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const transport = new StdioClientTransport({
  command: process.execPath,
  args: ['packages/roblox-ultimate-mcp/dist/index.js'],
  env: { ...process.env, ROBLOX_STUDIO_PORT: process.env.ROBLOX_STUDIO_PORT || '3910' },
  stderr: 'ignore',
});
const client = new Client({ name: 'gamekit-smoke', version: '1.0.0' });
const fail = (msg) => { console.error(`FAIL ${msg}`); process.exitCode = 1; };

await client.connect(transport);
const info = client.getServerVersion();
const instructions = client.getInstructions() ?? '';
console.log(`server: ${info?.name} ${info?.version}`);
if (!instructions.includes('roblox_start_here')) fail('instructions missing');

let tools = (await client.listTools()).tools.map((t) => t.name);
console.log(`starter profile: ${tools.length} tools`);
for (const needed of ['roblox_start_here', 'create_game', 'test_game', 'write_script', 'find_tools', 'call_tool']) {
  if (!tools.includes(needed)) fail(`missing tool ${needed}`);
}
if (tools.includes('terrain_fill_block')) fail('advanced tool visible in starter profile');

await client.callTool({ name: 'set_tool_profile', arguments: { profile: 'full' } });
tools = (await client.listTools()).tools.map((t) => t.name);
console.log(`full profile: ${tools.length} tools`);
if (!tools.includes('terrain_fill_block')) fail('full profile incomplete');
await client.callTool({ name: 'set_tool_profile', arguments: { profile: 'starter' } });

const lint = await client.callTool({ name: 'check_luau', arguments: { source: 'if x != 1 then end', kind: 'server' } });
const lintBody = JSON.parse(lint.content[0].text);
console.log(`check_luau: ok=${lintBody.ok} first error: ${lintBody.errors[0]?.problem} | ${lintBody.errors[0]?.fix}`);
if (lintBody.ok !== false) fail('check_luau did not catch the error');

const viaGateway = await client.callTool({ name: 'call_tool', arguments: { name: 'roblox_guide', arguments: { topic: 'errors' } } });
if (!viaGateway.content[0].text.includes('attempt to index nil')) fail('call_tool gateway');

const start = await client.callTool({ name: 'roblox_start_here', arguments: {} });
const startBody = JSON.parse(start.content[0].text);
console.log(`start_here (no Studio): connected=${startBody.studio.connected}`);

const prompts = (await client.listPrompts()).prompts.map((p) => p.name);
console.log(`prompts: ${prompts.join(', ')}`);
const prompt = await client.getPrompt({ name: 'make_game', arguments: { idea: 'a candy obby' } });
if (!prompt.messages[0].content.text.includes('create_game')) fail('make_game prompt');

const resources = (await client.listResources()).resources;
console.log(`resources: ${resources.length}`);
const guide = await client.readResource({ uri: 'gamekit://guide/workflow' });
if (!guide.contents[0].text.includes('golden path')) fail('workflow resource');

const offline = await client.callTool({ name: 'create_game', arguments: { template: 'obby' } });
console.log(`create_game without Studio -> isError=${offline.isError}`);
if (!offline.isError) fail('create_game should explain that Studio is not connected');

await client.close();
console.log(process.exitCode ? 'SMOKE FAILED' : 'SMOKE OK');
