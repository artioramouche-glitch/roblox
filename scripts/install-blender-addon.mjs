#!/usr/bin/env node
/**
 * Installs the "MCP for Blender" addon (integrations/blender-mcp/addon.py) into the
 * newest Blender found on this machine, then tries to enable it.
 * Usage: npm run install-blender-addon [-- --addons-dir <path>]
 * Env: BLENDER_USER_ADDONS / BLENDERMCP_ADDONS_DIR (addons folder), BLENDER_EXE (blender binary).
 */
import { spawnSync } from 'child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync, statSync } from 'fs';
import { homedir, platform } from 'os';
import { join, resolve } from 'path';

const source = resolve('integrations', 'blender-mcp', 'addon.py');
if (!existsSync(source)) {
  console.error(`Addon not found: ${source} (run this from the repository root).`);
  process.exit(1);
}

function candidates() {
  const flag = process.argv.indexOf('--addons-dir');
  const explicit = flag > 0 ? process.argv[flag + 1] : process.env.BLENDER_USER_ADDONS || process.env.BLENDERMCP_ADDONS_DIR;
  if (explicit) return [resolve(explicit)];
  const home = homedir();
  const base = platform() === 'darwin'
    ? join(home, 'Library', 'Application Support', 'Blender')
    : platform() === 'win32'
      ? (process.env.APPDATA ? join(process.env.APPDATA, 'Blender Foundation', 'Blender') : null)
      : join(home, '.config', 'blender');
  if (!base || !existsSync(base)) return [];
  const versions = readdirSync(base)
    .filter((name) => /^\d+\.\d+/.test(name) && statSync(join(base, name)).isDirectory())
    .sort((a, b) => b.localeCompare(a, undefined, { numeric: true }));
  return versions.map((v) => join(base, v, 'scripts', 'addons'));
}

const dirs = candidates();
if (!dirs.length) {
  console.error('No Blender user folder found. Start Blender once (so it creates its settings), or pass --addons-dir <Blender>/<version>/scripts/addons.');
  console.error('Manual install: Blender > Edit > Preferences > Add-ons > Install from disk > choose integrations/blender-mcp/addon.py');
  process.exit(1);
}
const target = dirs[0];
mkdirSync(target, { recursive: true });
const installed = join(target, 'blender_mcp.py');
copyFileSync(source, installed);
console.log(`Installed MCP for Blender addon -> ${installed}`);

const blender = process.env.BLENDER_EXE || 'blender';
const enable = spawnSync(blender, ['--background', '--python-expr',
  "import bpy, addon_utils; addon_utils.enable('blender_mcp', default_set=True, persistent=True); bpy.ops.wm.save_userpref()"], { encoding: 'utf8', timeout: 120000 });
if (enable.error) {
  console.log('Enable it once in Blender: Edit > Preferences > Add-ons > search "MCP" > tick "Interface: MCP for Blender".');
} else {
  console.log(enable.status === 0 ? 'Addon enabled in Blender preferences.' : 'Could not enable automatically: tick "MCP for Blender" in Edit > Preferences > Add-ons.');
}
console.log('Then in the 3D viewport: press N > tab "MCP for Blender" > "Connect to MCP server". Your AI checks the link with blender_status.');
