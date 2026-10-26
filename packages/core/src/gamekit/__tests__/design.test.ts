import fs from 'fs';
import os from 'os';
import path from 'path';
import { checkLuauSyntax } from '../luau-syntax.js';
import { execFileSync } from 'child_process';
import { FIGMA_AUTOLAUNCH_PS, figmaToSpec, FigmaBridge, FigmaTools, parseLayerName, robloxFont, specToFigma, startFigmaAutoLaunch, type DrawOp, type FigmaNode } from '../figma.js';
import { buildScreenGui, UI_EXAMPLE, type UiNode } from '../ui.js';
import { designRefs, findLibrary, indexLibrary, searchLibrary } from '../refs.js';
import { collectLuau, handleVfx, LIST_LUAU, presetLuau, VFX_PRESETS } from '../vfx.js';
import { guideText } from '../knowledge.js';
import { GAMEKIT_TOOLS, type GameKitHost } from '../tools.js';

const parse = (result: any) => JSON.parse(result.content[0].text);
const solid = (r: number, g: number, b: number, opacity = 1) => [{ type: 'SOLID', color: { r, g, b }, opacity }];

async function expectCompiles(code: string, label: string) {
  const r = await checkLuauSyntax(code, label);
  if (!r.ok) throw new Error(`${label}: ${JSON.stringify(r.errors)}`);
}

/** What the plugin's serialize() would send back for the layers draw() created. */
function asFigma(ops: DrawOp[]): FigmaNode {
  const nodes: FigmaNode[] = ops.map((op) => ({
    type: op.kind === 'text' ? 'TEXT' : 'FRAME',
    name: op.name, x: op.x, y: op.y, width: op.w, height: op.h,
    visible: op.visible !== false,
    fills: op.kind === 'text' ? solid(1, 1, 1) : op.fill ? solid(0.1, 0.1, 0.1, op.fillOpacity) : [],
    characters: op.text, fontSize: op.fontSize, fontFamily: 'Inter', fontStyle: op.bold ? 'Bold' : 'Regular',
    layoutMode: op.layout, itemSpacing: op.gap, children: [],
  }));
  ops.forEach((op, i) => { if (op.parent >= 0) nodes[op.parent].children!.push(nodes[i]); });
  return nodes[0];
}

describe('Figma -> build_ui', () => {
  const screen: FigmaNode = {
    type: 'FRAME', name: 'Main HUD', x: 0, y: 0, width: 1920, height: 1080, fills: solid(0.2, 0.2, 0.2),
    children: [
      { type: 'TEXT', name: 'Coins', x: 1600, y: 40, width: 280, height: 60, characters: '💰 {stat:Coins}', fontSize: 40, fontFamily: 'Gotham', fontStyle: 'Bold', textAlign: 'RIGHT', fills: solid(1, 0.8, 0.25) },
      {
        type: 'FRAME', name: 'Shop Button [toggle:Shop Window]', x: 40, y: 900, width: 200, height: 100, cornerRadius: 16, fills: solid(1, 0.79, 0.25),
        children: [{ type: 'TEXT', name: 'Label', x: 0, y: 0, width: 200, height: 100, characters: 'Shop', fontSize: 36, fontFamily: 'Fredoka One', fills: solid(0.1, 0.1, 0.1) }],
      },
      {
        type: 'FRAME', name: 'Shop Window', x: 560, y: 240, width: 800, height: 600, visible: false, cornerRadius: 24, fills: solid(0.08, 0.08, 0.12, 0.9),
        layoutMode: 'VERTICAL', itemSpacing: 12, padding: 16, primaryAlign: 'MIN', strokes: solid(1, 1, 1), strokeWeight: 2,
        children: [
          { type: 'VECTOR', name: 'Coin Icon', x: 0, y: 0, width: 64, height: 64, png: 'iVBORw0KGgo=' },
          { type: 'ELLIPSE', name: 'Dot', x: 0, y: 0, width: 40, height: 40, fills: solid(1, 0, 0) },
          { type: 'STICKY', name: 'Note', x: 0, y: 0, width: 10, height: 10 },
        ],
      },
    ],
  };

  test('turns a screen into a responsive spec with behaviour from names and texts', () => {
    const { spec, images, warnings } = figmaToSpec(screen);
    expect(spec.name).toBe('MainHUD');
    const [coins, button, window] = spec.children;
    expect(coins).toMatchObject({ type: 'label', bind: 'stat:Coins', format: '💰 {value}', font: 'GothamBold', textAlign: 'right', maxTextSize: 40, textColor: '#FFCC40' });
    expect(coins.position).toEqual([0.8333, 0, 0.037, 0]);
    expect(button).toMatchObject({ type: 'button', name: 'ShopButton', action: 'toggle:ShopWindow', text: 'Shop', font: 'FredokaOne', corner: 16 });
    expect(button.children).toBeUndefined();
    expect(window).toMatchObject({ name: 'ShopWindow', visible: false, layout: 'vertical', gap: 12, padding: 16, align: 'start', stroke: '#FFFFFF', transparency: 0.1 });
    expect(window.children!.map((c) => c.type)).toEqual(['image', 'frame']);
    expect(window.children![1]).toMatchObject({ corner: 20, aspect: 1 });
    expect(images).toEqual([{ path: 'StarterGui/MainHUD/ShopWindow/CoinIcon', png: 'iVBORw0KGgo=' }]);
    expect(warnings.join(' ')).toMatch(/background/);
    expect(warnings.join(' ')).toMatch(/STICKY/);
    // The spec builds as is.
    expect(buildScreenGui(spec).children).toHaveLength(3);
  });

  test('a small frame is one centered panel', () => {
    const { spec } = figmaToSpec({ type: 'FRAME', name: 'Daily reward', x: 300, y: 300, width: 400, height: 300, fills: solid(0, 0, 0), children: [] });
    expect(spec.children[0]).toMatchObject({ position: 'center', size: [0, 400, 0, 300], name: 'DailyReward' });
  });

  test('layer names and fonts', () => {
    expect(parseLayerName('Buy [remote:BuyItem:Sword] [showIf:stat:Stage>5]')).toEqual({ name: 'Buy', extra: { action: 'remote:BuyItem:Sword', showIf: 'stat:Stage>5' } });
    expect(parseLayerName('2x boost').name).toBe('N2xBoost');
    expect(parseLayerName('Gem [image]').name).toBe('Gem');
    expect(robloxFont('Inter', 'Regular')).toBe('BuilderSans');
    expect(robloxFont('Inter', 'Semi Bold')).toBe('BuilderSansBold');
    expect(robloxFont('Montserrat', 'Black')).toBe('GothamBlack');
    expect(robloxFont('Comic Neue')).toBeUndefined();
  });
});

describe('build_ui -> Figma -> build_ui', () => {
  test('a drawn spec reads back with the same names, behaviour and visibility', () => {
    const ops = specToFigma(UI_EXAMPLE, [1280, 720]);
    expect(ops[0]).toMatchObject({ parent: -1, w: 1280, h: 720 });
    const menu = ops.find((o) => o.name === 'MenuWindow')!;
    expect(menu).toMatchObject({ x: 384, y: 180, w: 512, h: 360, visible: false, layout: 'VERTICAL' });
    const back = figmaToSpec(asFigma(ops)).spec;
    const find = (name: string, list: UiNode[] = back.children): UiNode | undefined =>
      list.map((n) => (n.name === name ? n : find(name, n.children ?? []))).find(Boolean);
    expect(find('CoinsPanel')!.children![0]).toMatchObject({ type: 'label', bind: 'stat:Coins', format: '💰 {value}' });
    expect(find('MenuButton')).toMatchObject({ type: 'button', text: 'Menu', action: 'toggle:MenuWindow' });
    expect(find('MenuWindow')).toMatchObject({ visible: false, layout: 'vertical' });
    expect(find('Button')).toMatchObject({ type: 'button', text: 'Close', action: 'close:MenuWindow' });
  });
});

describe('Figma bridge', () => {
  test('commands wait for the plugin, which answers them', async () => {
    const bridge = new FigmaBridge();
    await expect(bridge.send({ action: 'read' })).rejects.toThrow(/not running/);
    // A long poll held open counts as connected and gets the command as soon as it is sent.
    const poll = bridge.poll({ file: 'Game UI', selection: 1 }, 60000);
    bridge.lastSeen = 0;
    expect(bridge.connected()).toBe(true);
    const pending = bridge.send({ action: 'read' });
    const next = await poll.next;
    expect(next?.command).toEqual({ action: 'read' });
    expect(bridge.answer(next!.id, true, { root: null })).toBe(true);
    await expect(pending).resolves.toEqual({ root: null });
    expect(bridge.status()).toMatchObject({ connected: true, file: 'Game UI', selected: 1 });
    // A short poll answers at once; a cancelled long poll stops counting.
    await expect(bridge.poll({}).next).resolves.toBeUndefined();
    const held = bridge.poll({}, 60000);
    held.cancel();
    await expect(held.next).resolves.toBeUndefined();
    bridge.lastSeen = 0;
    expect(bridge.connected()).toBe(false);
  });

  test('import reads the selection, saves pictures and builds the UI', async () => {
    const built: any[] = [];
    const out = fs.mkdtempSync(path.join(os.tmpdir(), 'figma-'));
    const fakeFetch = (async (url: string, init?: any) => {
      const body = init?.body ? JSON.parse(init.body) : {};
      const result = body.action === 'read'
        ? { file: 'Game', root: { type: 'FRAME', name: 'Shop', x: 0, y: 0, width: 400, height: 300, children: [{ type: 'RECTANGLE', name: 'Gem [image]', x: 10, y: 10, width: 50, height: 50, png: Buffer.from('png').toString('base64') }] } }
        : undefined;
      return { json: async () => (url.endsWith('/status') ? { connected: true } : { ok: true, result }) };
    }) as unknown as typeof fetch;
    const figma = new FigmaTools(async (spec) => { built.push(spec); return { content: [{ type: 'text', text: JSON.stringify({ ok: true }) }] }; }, fakeFetch, out);
    const report = parse(await figma.call({ action: 'import' }));
    expect(report.ok).toBe(true);
    expect(built[0].name).toBe('Shop');
    expect(report.pictures[0].instance).toBe('StarterGui/Shop/Shop/Gem');
    expect(fs.readFileSync(report.pictures[0].file, 'utf8')).toBe('png');
  });

  test('the auto-launch watcher only starts on Windows, unless turned off, and its script parses', () => {
    expect(startFigmaAutoLaunch(58741, 'linux', {})).toBeUndefined();
    expect(startFigmaAutoLaunch(58741, 'win32', { ROBLOX_MCP_FIGMA_AUTOSTART: '0' })).toBeUndefined();
    expect(FIGMA_AUTOLAUNCH_PS).toContain('__PORT__');
    expect(FIGMA_AUTOLAUNCH_PS).toContain('__PARENT__');
    if (process.platform !== 'win32') return;
    const b64 = Buffer.from(FIGMA_AUTOLAUNCH_PS.replace('__PORT__', '1').replace('__PARENT__', '1'), 'utf16le').toString('base64');
    const errors = execFileSync('powershell.exe', ['-NoProfile', '-Command',
      `$e=$null; [void][System.Management.Automation.Language.Parser]::ParseInput([Text.Encoding]::Unicode.GetString([Convert]::FromBase64String("${b64}")), [ref]$null, [ref]$e); $e.Count`], { encoding: 'utf8' }).trim();
    expect(errors).toBe('0');
  });

  test('a missing plugin gives the setup steps', async () => {
    const fakeFetch = (async () => ({ json: async () => ({ ok: false, error: 'The Figma plugin "Roblox MCP Bridge" is not running.' }) })) as unknown as typeof fetch;
    const result = parse(await new FigmaTools(async () => ({ content: [] }), fakeFetch).call({ action: 'read' }));
    expect(result.ok).toBe(false);
    expect(result.steps.join(' ')).toMatch(/Import plugin from manifest/);
  });
});

describe('design_refs', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'refs-'));
  const add = (rel: string, readme?: string) => {
    fs.mkdirSync(path.join(root, rel), { recursive: true });
    fs.writeFileSync(path.join(root, rel, 'shot-1.png'), 'x');
    if (readme) fs.writeFileSync(path.join(root, rel, 'README.md'), readme);
  };
  add('ui-styles/09-modern-cartoon-simulator', '# Modern cartoon simulator\n\n2 images in this folder.\n');
  add('vfx/14-fireball-explosion', '# Fireball explosion\n');
  add('style-refs/simulator', '# Simulator\n\nCurrency pills, big shop cards, icon sets and bright sky-blue simulator HUDs.\n');
  add('roblox-docs/ui');

  test('finds the library and ranks folders by the query', () => {
    expect(findLibrary({ ROBLOX_REFS_DIR: root }, '/nowhere')).toBe(root);
    expect(findLibrary({}, '/nowhere')).toBeUndefined();
    const folders = indexLibrary(root);
    const hits = searchLibrary(folders, 'simulator shop');
    expect(hits[0].rel).toBe('style-refs/simulator');
    expect(hits[0].about).toMatch(/Currency pills/);
    expect(searchLibrary(folders, 'fireballs')[0].rel).toBe('vfx/14-fireball-explosion');
  });

  test('returns paths, the collections, or the pictures themselves', () => {
    const here = () => root;
    expect(parse(designRefs({}, here)).collections).toMatchObject({ 'ui-styles': 1, vfx: 1 });
    const found = parse(designRefs({ query: 'cartoon simulator' }, here));
    expect(found.results[0].images[0]).toContain('shot-1.png');
    const shown = designRefs({ query: 'fireball', show: true }, here);
    expect(shown.content.filter((c) => c.type === 'image')).toHaveLength(1);
    expect(parse(designRefs({ query: 'x' }, () => undefined)).problem).toMatch(/not found/);
  });
});

describe('make_vfx', () => {
  test('every preset, collect and list compile', async () => {
    for (const [id, preset] of Object.entries(VFX_PRESETS)) await expectCompiles(presetLuau(id, 'Fx', preset.emitters, 'Workspace/Torch'), id);
    await expectCompiles(collectLuau('MyEffect'), 'collect');
    await expectCompiles(LIST_LUAU, 'list');
  });

  test('presets are tinted and give the line that plays them', async () => {
    const calls: string[] = [];
    const host = {
      isStudioConnected: () => true,
      runLuau: async (code: string) => { calls.push(code); return { success: true, returnValue: JSON.stringify({ ok: true, template: 'ReplicatedStorage.GameKit.Effects.SwordHit', utilInstalled: true }) }; },
    } as unknown as GameKitHost;
    const result = parse(await handleVfx(host, { preset: 'hit_spark', name: 'sword hit', color: '#FF0000' }));
    expect(result.play).toContain('Util.vfx("SwordHit", part)');
    expect(calls[0]).toContain('"#FF0000"');
    await expect(handleVfx(host, { preset: 'nope' })).rejects.toThrow(/needs a preset/);
  });
});

describe('guides and tools', () => {
  test('the new tools are listed and documented', () => {
    for (const name of ['design_refs', 'figma', 'make_vfx']) expect(GAMEKIT_TOOLS.find((t) => t.name === name)?.tier).toBe('starter');
    expect(guideText('figma')).toMatch(/Roblox MCP Bridge/);
    expect(guideText('vfx')).toMatch(/Util\.vfx/);
  });
});
