// node --import tsx --test packages/roblox-ultimate-mcp/src/setup.test.ts (npm test runs it)
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addFigmaPlugin, clientConfigs, figmaSettingsFile, mergeCodexConfig, mergeServerConfig } from './setup.js';

test('the Figma plugin is added to Figma settings once, with the smallest free id', () => {
  const manifest = 'C:\\mcp\\figma-plugin\\manifest.json';
  const before = JSON.stringify({ windows: [{ id: 1 }], localFileExtensions: [{ id: 1, manifestPath: 'C:\\other\\manifest.json' }, { id: 3, manifestPath: 'C:\\other\\code.js' }] });
  const added = addFigmaPlugin(before, manifest);
  assert.equal(added.status, 'added');
  const settings = JSON.parse(added.text!);
  assert.deepEqual(settings.windows, [{ id: 1 }]);
  assert.deepEqual(settings.localFileExtensions[2], { id: 2, manifestPath: manifest, lastKnownName: 'Roblox MCP Bridge', lastKnownPluginId: 'roblox-ultimate-mcp-bridge' });
  assert.deepEqual(addFigmaPlugin(added.text!, 'c:/mcp/figma-plugin/manifest.json'), { text: null, status: 'present' });
  assert.equal(JSON.parse(addFigmaPlugin('{}', manifest).text!).localFileExtensions[0].id, 1);
  assert.match(figmaSettingsFile('C:\\Users\\me', 'win32', { APPDATA: 'C:\\Users\\me\\AppData\\Roaming' })!, /Roaming[\\/]Figma[\\/]settings\.json$/);
  assert.equal(figmaSettingsFile('/home/me', 'linux', {}), undefined);
});

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
