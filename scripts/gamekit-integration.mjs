#!/usr/bin/env node
/**
 * Full-chain integration test: MCP client -> this server (stdio) -> HTTP bridge ->
 * fake Studio plugin (Lune, real Roblox class database) -> GameKit Luau -> results.
 * Needs the `lune` binary (PATH or LUNE env var). Usage: npm run build && node scripts/gamekit-integration.mjs
 */
import { spawn } from 'child_process';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const port = process.env.ROBLOX_STUDIO_PORT || '3920';
const lune = process.env.LUNE || 'lune';
const transport = new StdioClientTransport({ command: process.execPath, args: ['packages/roblox-ultimate-mcp/dist/index.js'], env: { ...process.env, ROBLOX_STUDIO_PORT: port }, stderr: 'ignore' });
const client = new Client({ name: 'gamekit-integration', version: '1.0.0' });
await client.connect(transport);
const studio = spawn(lune, ['run', 'scripts/lune/fake-studio.luau', port], { stdio: ['ignore', 'pipe', 'inherit'] });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failed = 0;

async function call(name, args = {}) {
  const res = await client.callTool({ name, arguments: args });
  const text = res.content[0].text;
  let body;
  try { body = JSON.parse(text); } catch { body = { raw: text }; }
  const ok = !res.isError && body.ok !== false && body.written !== false;
  if (!ok) failed++;
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name} ${JSON.stringify(args).slice(0, 60)} -> ${(body.summary ?? body.raw ?? body.verdict ?? '').toString().slice(0, 140)}`);
  if (!ok) console.log(JSON.stringify(body, null, 1).slice(0, 1500));
  return body;
}

try {
  for (let i = 0; i < 40; i++) {
    const s = await call('roblox_start_here');
    if (s.studio?.connected) { failed = 0; break; }
    failed = 0;
    await sleep(500);
  }
  const start = await call('roblox_start_here');
  if (!start.studio?.connected) throw new Error('fake studio never connected');
  for (const template of ['obby', 'tycoon', 'simulator', 'arena', 'survival', 'horror_escape']) {
    const r = await call('create_game', { template, options: { title: `Test ${template}` } });
    if (r.install?.warnings?.length) { failed++; console.log(r.install.warnings); }
  }
  await call('add_system', { system: 'shop', config: { Currency: 'Gems' } });
  await call('build_world', { kind: 'jump_pad', name: 'MyPad', options: { position: [10, 60, 0], power: 150 } });
  await call('build_ui', { spec: { name: 'CoinsUI', children: [{ type: 'label', position: 'top', size: [200, 40], bind: 'stat:Coins', format: '💰 {value}' }] } });
  await call('set_environment', { preset: 'sunset' });
  await call('write_script', { path: 'ServerScriptService/Hello', source: 'print("hello from write_script")' });
  const audit = await call('check_game', {});
  console.log(`check_game: ${audit.verdict} (${audit.errors} errors, ${audit.warnings} warnings, ${audit.scripts} scripts)`);
  for (const f of (audit.findings ?? []).filter((x) => x.severity === 'error').slice(0, 10)) console.log('   error:', f.where, f.line ?? '', f.problem);
  if (audit.errors > 0) failed++;
} catch (err) {
  failed++;
  console.error(err);
} finally {
  studio.kill();
  await client.close();
}
console.log(failed ? `INTEGRATION FAILED (${failed})` : 'INTEGRATION OK');
process.exit(failed ? 1 : 0);
