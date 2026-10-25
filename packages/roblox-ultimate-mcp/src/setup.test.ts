// node --import tsx --test packages/roblox-ultimate-mcp/src/setup.test.ts (npm test runs it)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { clientConfigs, mergeCodexConfig, mergeServerConfig } from './setup.js';

test('knows Qoder, VS Code, Codex, Gemini CLI and Antigravity', () => {
  const names = clientConfigs('/home/me', 'linux', {}).map((c) => c.name);
  for (const name of ['Qoder', 'VS Code (Copilot)', 'Codex', 'Gemini CLI', 'Antigravity']) assert.ok(names.includes(name), name);
});

test('VS Code entries go under "servers" with a type, other servers kept', () => {
  const merged = JSON.parse(mergeServerConfig('{"servers":{"other":{}},"inputs":[]}', { command: 'node', args: ['x.js'] }, false, 'servers', { type: 'stdio' }).text!);
  assert.deepEqual(merged.servers['roblox-ultimate'], { type: 'stdio', command: 'node', args: ['x.js'] });
  assert.deepEqual(merged.servers.other, {});
  assert.deepEqual(merged.inputs, []);
});

test('Codex gets a TOML table once', () => {
  const entry = { command: 'C:\\Program Files\\nodejs\\node.exe', args: ['C:\\mcp\\index.js'], env: { ROBLOX_MCP_BLENDER: '1' } };
  const added = mergeCodexConfig('model = "o3"', entry);
  assert.equal(added.status, 'added');
  assert.ok(added.text!.includes('model = "o3"\n\n[mcp_servers.roblox-ultimate]\ncommand = "C:\\\\Program Files\\\\nodejs\\\\node.exe"'));
  assert.ok(added.text!.includes('[mcp_servers.roblox-ultimate.env]\nROBLOX_MCP_BLENDER = "1"'));
  assert.deepEqual(mergeCodexConfig(added.text!, entry), { text: null, status: 'present' });
});
