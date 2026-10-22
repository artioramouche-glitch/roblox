#!/usr/bin/env node
/**
 * Writes the Luau installer generated for every template, world, piece, system, UI and
 * lighting preset into a folder, so scripts/lune/validate-installers.luau can execute
 * them against Roblox's real class/property database (Lune).
 * Usage: node scripts/dump-gamekit-cases.mjs <outDir>   (run `npm run build` first)
 */
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';

const out = process.argv[2];
if (!out) { console.error('usage: dump-gamekit-cases.mjs <outDir>'); process.exit(1); }
mkdirSync(out, { recursive: true });

const dist = new URL('../packages/core/dist/gamekit/', import.meta.url);
const { buildInstallerLuau } = await import(new URL('installer.js', dist));
const { TEMPLATES } = await import(new URL('templates.js', dist));
const { SYSTEMS, systemPlacements } = await import(new URL('catalog.js', dist));
const { buildWorld, worldPlacement, WORLDS, PIECES } = await import(new URL('world.js', dist));
const { buildScreenGui, UI_EXAMPLE } = await import(new URL('ui.js', dist));
const { buildEnvironmentLuau, LIGHTING_PRESETS } = await import(new URL('environment.js', dist));

const cases = [];
const add = (name, code) => { cases.push(name); writeFileSync(join(out, `${name}.luau`), code); };

for (const t of TEMPLATES) {
  const plan = t.plan({});
  const { placements } = systemPlacements(plan.systems, { config: plan.config, resetConfig: true });
  add(`template_${t.id}`, buildInstallerLuau({ label: t.id, items: [...placements, ...plan.world] }));
}
for (const s of SYSTEMS) {
  add(`system_${s.id}`, buildInstallerLuau({ label: s.id, items: systemPlacements([s.id]).placements }));
}
for (const w of WORLDS) add(`world_${w}`, buildInstallerLuau({ label: w, items: [worldPlacement(buildWorld(w, {}))] }));
for (const p of PIECES) add(`piece_${p}`, buildInstallerLuau({ label: p, items: [worldPlacement(buildWorld(p, { position: [0, 5, 0] }))] }));
for (const d of ['easy', 'medium', 'hard']) {
  add(`obby_${d}_40`, buildInstallerLuau({ label: 'obby', items: [worldPlacement(buildWorld('obby_course', { stages: 40, difficulty: d, theme: 'neon' }))] }));
}
add('ui_example', buildInstallerLuau({ label: 'ui', items: [{ parent: ['StarterGui'], mode: 'replace', node: buildScreenGui(UI_EXAMPLE) }] }));
add('ui_all_types', buildInstallerLuau({ label: 'ui2', items: [{ parent: ['StarterGui'], mode: 'replace', node: buildScreenGui({
  name: 'AllTypes',
  children: [
    { type: 'frame', position: 'center', size: [0.5, 0.5], layout: 'grid', cell: [100, 100], gradient: ['#FF0000', '#0000FF'], stroke: '#FFFFFF', padding: 8, aspect: 1.5, children: [
      { type: 'label', text: 'hi', bind: 'stat:Coins', format: '{value}' },
      { type: 'button', text: 'go', action: 'toggle:Win' },
      { type: 'image', image: 'rbxassetid://1' },
      { type: 'imagebutton', image: 'rbxassetid://1', action: 'remote:Test' },
      { type: 'textbox', placeholder: 'type' },
      { type: 'scroll', layout: 'vertical', children: [{ type: 'label', text: 'x' }] },
      { type: 'bar', bar: 'stat:Power/stat:Capacity', bind: 'stat:Power' },
    ] },
    { type: 'frame', name: 'Win', visible: false, showIf: '!state:RoundActive', size: [300, 200], position: [0.1, 0, 0.1, 0] },
  ],
}) }] }));
for (const preset of Object.keys(LIGHTING_PRESETS)) add(`env_${preset}`, buildEnvironmentLuau({ preset, removeBaseplate: true }));
writeFileSync(join(out, 'cases.json'), JSON.stringify(cases));
console.log(`[dump] ${cases.length} cases -> ${out}`);
