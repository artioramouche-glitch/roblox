#!/usr/bin/env node
/**
 * Full-chain integration test: MCP client -> this server (stdio) -> HTTP bridge ->
 * fake Studio plugin (Lune, real Roblox class database) -> GameKit Luau -> results.
 * Needs the `lune` binary (PATH or LUNE env var). Usage: npm run build && node scripts/gamekit-integration.mjs
 */
import { spawn, spawnSync } from 'child_process';
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

// Pure Luau unit test of the translation module.
const lang = spawnSync(lune, ['run', 'scripts/lune/test-lang.luau'], { encoding: 'utf8' });
console.log((lang.stdout || lang.stderr || '').trim());
const langFailed = lang.status !== 0;

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
  for (const template of ['obby', 'tycoon', 'simulator', 'arena', 'survival', 'horror_escape', 'tower_defense', 'farming', 'racing', 'fishing', 'craft_survival']) {
    const r = await call('create_game', { template, options: { title: `Test ${template}` } });
    if (r.install?.warnings?.length) { failed++; console.log(r.install.warnings); }
    if (template === 'tycoon') {
      const eco = await call('balance_economy', { fromGame: true });
      if (!eco.tycoon?.timeline?.length) { failed++; console.log('balance_economy did not read the tycoon'); }
    }
  }
  // Every create_game after the first one saved a backup of the previous game.
  const backups = await call('backup_game', { action: 'list' });
  if (!(backups.backups?.length >= 1)) { failed++; console.log('no automatic backup'); }
  await call('backup_game', { action: 'save', label: 'integration' });
  await call('backup_game', { action: 'restore' });

  // Team board: two agents, atomic claims, zones that cannot overlap.
  await call('team', { action: 'plan', template: 'farming', replace: true });
  const a = await call('team', { action: 'claim', agent: 'claude-1' });
  const b = await call('team', { action: 'claim', agent: 'gemini-1' });
  if (!a.claimed || !b.claimed || a.claimed.id === b.claimed.id) { failed++; console.log('claims are not exclusive'); }
  await call('team', { action: 'claim_zone', agent: 'claude-1', zone: 'north', center: [0, 20, 150], size: [100, 40, 100] });
  const clash = await client.callTool({ name: 'team', arguments: { action: 'claim_zone', agent: 'gemini-1', zone: 'north2', center: [30, 20, 160], size: [100, 40, 100] } });
  if (JSON.parse(clash.content[0].text).ok !== false) { failed++; console.log('overlapping zone was accepted'); }
  await call('team', { action: 'done', agent: 'claude-1', task: a.claimed?.id, note: 'built it' });

  // Decoration in a zone (the fake Studio has no physics: no snapping/overlap checks).
  await call('populate_world', { theme: 'forest', count: 15, zone: 'north', snap: false, avoidGameplay: false });
  await call('build_world', { kind: 'tower_pad', zone: 'north', options: { tower: 'Cannon' } });

  // Background job + publish checklist + Blender offline message.
  const job = await call('start_job', { tool: 'check_game', arguments: {} });
  const jobResult = await client.callTool({ name: 'job_status', arguments: { id: job.jobId, wait: 60 } });
  const head = JSON.parse(jobResult.content[0].text);
  console.log(`${head.status === 'done' ? 'ok  ' : 'FAIL'} job ${job.jobId} -> ${head.status}`);
  if (head.status !== 'done') failed++;
  await call('publish_checklist', {});
  const blender = await call('blender_status', {});
  if (blender.connected !== false) { failed++; console.log('blender_status should report offline'); }
  await call('add_system', { system: 'shop', config: { Currency: 'Gems' } });
  await call('build_world', { kind: 'jump_pad', name: 'MyPad', options: { position: [10, 60, 0], power: 150 } });
  await call('build_ui', { spec: { name: 'CoinsUI', children: [{ type: 'label', position: 'top', size: [200, 40], bind: 'stat:Coins', format: '💰 {value}' }] } });
  await call('set_environment', { preset: 'sunset' });
  await call('write_script', { path: 'ServerScriptService/Hello', source: 'print("hello from write_script")' });

  // Coding aids: recipe -> read -> edit (validated) -> outline; JS-style code gets auto-fixed.
  await call('code_recipe', {});
  const recipe = await call('code_recipe', { recipe: 'touch_reward', params: { target: 'Workspace/GameKit/MyPad', amount: 10 } });
  const scriptPath = recipe.installed?.[0]?.split(' ')[0];
  if (!scriptPath) { failed++; console.log('recipe not installed'); }
  const read = await client.callTool({ name: 'read_script', arguments: { path: scriptPath, find: 'Amount' } });
  if (!/Amount = 10/.test(read.content[0].text)) { failed++; console.log('read_script', read.content[0].text.slice(0, 300)); }
  const edit = await call('edit_script', { path: scriptPath, find: 'Amount = 10,', replace: 'Amount = 99,' });
  if (!edit.written) failed++;
  const reread = await client.callTool({ name: 'read_script', arguments: { path: scriptPath, find: 'Amount = 99' } });
  if (!/Amount = 99/.test(reread.content[0].text)) { failed++; console.log('edit not applied'); }
  const refused = await client.callTool({ name: 'edit_script', arguments: { path: scriptPath, find: 'local ready', replace: 'local ready = = 1 --' } });
  if (JSON.parse(refused.content[0].text).written !== false) { failed++; console.log('broken edit was written'); }
  const fixed = await call('write_script', { path: 'ServerScriptService/JsStyle', source: 'let total = 0\n// count\nif total != 1 && !false then\n\tconsole.log("Total: " + total)\nend' });
  if (!fixed.autofixed?.length) { failed++; console.log('no autofix reported'); }
  const outline = await client.callTool({ name: 'code_outline', arguments: {} });
  console.log(`ok   code_outline -> ${outline.content[0].text.split('\n')[0]}`);
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
if (langFailed) failed++;
console.log(failed ? `INTEGRATION FAILED (${failed})` : 'INTEGRATION OK');
process.exit(failed ? 1 : 0);
