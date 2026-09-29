#!/usr/bin/env node
/**
 * Verifies every Luau file of the GameKit library.
 *
 *   1. Syntax: compiles each file with luau-web (the real Luau compiler in WASM).
 *   2. Types (optional): if luau-lsp is installed (PATH, LUAU_LSP env var or .tools/),
 *      type-checks every file against the Roblox API definitions.
 *
 * Usage: node scripts/verify-gamekit-luau.mjs [--strict]
 */
import { readdirSync, readFileSync, statSync, existsSync } from 'fs';
import { join, relative, dirname } from 'path';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const libDir = join(root, 'gamekit');

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (name.endsWith('.luau')) out.push(full);
  }
  return out;
}

const files = walk(libDir).sort();
const { LuauState } = await import('luau-web');
const state = await LuauState.createAsync();
let syntaxErrors = 0;
for (const file of files) {
  const src = readFileSync(file, 'utf8');
  const result = state.loadstring(src, '=' + relative(root, file), false);
  if (typeof result === 'string') {
    syntaxErrors++;
    console.log(`SYNTAX  ${result}`);
  }
}
console.log(`[syntax] ${files.length} files, ${syntaxErrors} with errors`);

const candidates = [process.env.LUAU_LSP, 'luau-lsp', join(root, '.tools', 'luau-lsp'), join(root, '.tools', 'luau-lsp.exe')].filter(Boolean);
let lsp = null;
for (const c of candidates) {
  const probe = spawnSync(c, ['--version'], { encoding: 'utf8' });
  if (probe.status === 0) { lsp = c; break; }
}
// Rojo-style sourcemap following the GameKit install convention, so luau-lsp can
// resolve `require(ReplicatedStorage.GameKit.Util)` and type-check across modules.
function targetFor(rel) {
  const parts = rel.split('/');
  const file = parts[parts.length - 1];
  if (parts[1] === 'runtime') return null;
  let name = file.replace(/\.luau$/, '');
  if (name.endsWith('.server')) return { path: ['ServerScriptService', 'GameKit'], name: name.slice(0, -7), className: 'Script' };
  if (name.endsWith('.client')) return { path: ['StarterPlayer', 'StarterPlayerScripts', 'GameKit'], name: name.slice(0, -7), className: 'LocalScript' };
  if (name.endsWith('.shared') || parts[1] === 'shared') return { path: ['ReplicatedStorage', 'GameKit'], name: name.replace(/\.shared$/, ''), className: 'ModuleScript' };
  return { path: ['ServerScriptService', 'GameKit'], name, className: 'ModuleScript' };
}
const sourcemap = { name: 'Game', className: 'DataModel', children: [] };
function ensure(node, name, className) {
  node.children = node.children || [];
  let child = node.children.find(c => c.name === name);
  if (!child) { child = { name, className, children: [] }; node.children.push(child); }
  return child;
}
for (const file of files) {
  const rel = relative(root, file).split('\\').join('/');
  const t = targetFor(rel);
  if (!t) continue;
  let node = sourcemap;
  t.path.forEach((seg, i) => { node = ensure(node, seg, i === 0 ? seg : (seg === 'StarterPlayerScripts' ? 'StarterPlayerScripts' : 'Folder')); });
  const leaf = ensure(node, t.name, t.className);
  leaf.filePaths = [rel];
}
const { writeFileSync, mkdtempSync } = await import('fs');
const { tmpdir } = await import('os');
const smapPath = join(mkdtempSync(join(tmpdir(), 'gk-')), 'sourcemap.json');
writeFileSync(smapPath, JSON.stringify(sourcemap));

const defs = process.env.ROBLOX_TYPES || join(root, 'reference', 'packages', 'core', 'assets', 'globalTypes.d.luau');
let typeErrors = 0;
if (lsp && existsSync(defs)) {
  const res = spawnSync(lsp, ['analyze', `--definitions=@roblox=${defs}`, `--sourcemap=${smapPath}`, ...files.map(f => relative(root, f))], { cwd: root, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const lines = `${res.stdout}\n${res.stderr}`.split(/\r?\n/).filter(l => l.trim() && !/^\[(INFO|WARN)\]/.test(l));
  typeErrors = lines.length;
  for (const l of lines) console.log(`TYPES   ${l}`);
  console.log(`[types] luau-lsp: ${typeErrors} diagnostics`);
} else {
  console.log('[types] skipped (install luau-lsp or set LUAU_LSP to enable type checking)');
}
if (syntaxErrors > 0 || (process.argv.includes('--strict') && typeErrors > 0)) process.exitCode = 1;
