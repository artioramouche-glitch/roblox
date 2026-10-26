#!/usr/bin/env node

/**
 * Copies what the published package needs from the repository before npm pack/publish:
 * the built Studio plugins (studio-plugin/*.rbxmx), the "MCP for Blender" addon, the
 * README and the licence. Run from a publishable package directory via its "prepack" script.
 */

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, writeFileSync } from 'fs';
import { join } from 'path';

const packageDir = process.cwd();
const rootDir = join(packageDir, '..', '..');
const copied = [];

const pluginSource = join(rootDir, 'studio-plugin');
const pluginDest = join(packageDir, 'studio-plugin');
if (existsSync(pluginSource)) {
  if (!existsSync(pluginDest)) copied.push('studio-plugin');
  mkdirSync(pluginDest, { recursive: true });
  // Each package ships its own plugin (the inspector edition has its own file).
  const inspector = packageDir.includes('inspector');
  const wanted = (f) => f.endsWith('.rbxmx') && f.includes('Inspector') === inspector;
  for (const file of readdirSync(pluginSource).filter(wanted)) {
    copyFileSync(join(pluginSource, file), join(pluginDest, file));
    console.log(`Copied studio-plugin/${file}`);
  }
} else {
  console.error('studio-plugin/ not found at project root, skipping the plugin');
}

const addon = join(rootDir, 'integrations', 'blender-mcp', 'addon.py');
if (existsSync(addon)) {
  if (!existsSync(join(packageDir, 'blender'))) copied.push('blender');
  mkdirSync(join(packageDir, 'blender'), { recursive: true });
  copyFileSync(addon, join(packageDir, 'blender', 'addon.py'));
  const licence = join(rootDir, 'integrations', 'blender-mcp', 'LICENSE');
  if (existsSync(licence)) copyFileSync(licence, join(packageDir, 'blender', 'LICENSE'));
  console.log('Copied the Blender addon to blender/addon.py');
}

const imageTo3d = join(rootDir, 'integrations', 'blender-image-to-3d');
if (existsSync(imageTo3d) && !packageDir.includes('inspector')) {
  if (!existsSync(join(packageDir, 'blender'))) copied.push('blender');
  cpSync(imageTo3d, join(packageDir, 'blender', 'image-to-3d'), { recursive: true });
  console.log('Copied the blender-image-to-3d skill to blender/image-to-3d/');
}

const figma = join(rootDir, 'figma-plugin');
if (existsSync(figma) && !packageDir.includes('inspector')) {
  if (!existsSync(join(packageDir, 'figma-plugin'))) copied.push('figma-plugin');
  mkdirSync(join(packageDir, 'figma-plugin'), { recursive: true });
  for (const file of readdirSync(figma)) copyFileSync(join(figma, file), join(packageDir, 'figma-plugin', file));
  console.log('Copied the Figma plugin to figma-plugin/');
}

for (const file of ['README.md', 'LICENSE']) {
  const source = join(rootDir, file);
  if (existsSync(source) && !existsSync(join(packageDir, file))) {
    copyFileSync(source, join(packageDir, file));
    copied.push(file);
  }
}
// postpack removes exactly what was copied here (never a file the package already had).
writeFileSync(join(packageDir, '.prepack-copied.json'), JSON.stringify(copied));
