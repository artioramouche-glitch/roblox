import { execFileSync } from 'child_process';
import { existsSync } from 'fs';
import { join } from 'path';
import { LUAU_SOURCES } from '../generated/luau-sources.js';
import { checkLuauSyntax } from '../luau-syntax.js';
import { lintLuau, stripCommentsAndStrings, contextFor } from '../luau-lint.js';
import { buildInstallerLuau, scriptTarget, splitPath } from '../installer.js';
import { SYSTEMS, systemPlacements, resolveSystems } from '../catalog.js';
import { TEMPLATES } from '../templates.js';
import { buildWorld, countParts, obbyCourse, PIECES, WORLDS, OBSTACLES } from '../world.js';
import { buildScreenGui, missingActionTargets, UI_EXAMPLE } from '../ui.js';
import { buildEnvironmentLuau, LIGHTING_PRESETS, TERRAIN_MODES } from '../environment.js';
import { configModule, longString, toLuau } from '../luau-table.js';
import { guideText, GUIDES, catalogText } from '../knowledge.js';
import { PROMPTS, listResources, SERVER_INSTRUCTIONS } from '../mcp-extras.js';
import { baseToolVisible, getProfile, setProfile } from '../profiles.js';
import { hintForRuntimeError, parseRuntimeError } from '../hints.js';
import { GameKit, GAMEKIT_TOOLS, type GameKitHost } from '../tools.js';
import type { InstanceNode } from '../installer.js';

const parse = (result: any) => JSON.parse(result.content[0].text);

async function expectCompiles(code: string, label: string) {
  const r = await checkLuauSyntax(code, label);
  if (!r.ok) throw new Error(`${label}: ${JSON.stringify(r.errors)}`);
  expect(r.available).toBe(true);
}

describe('Luau syntax checker', () => {
  test('accepts modern Luau', async () => {
    const r = await checkLuauSyntax('local x: number = 1\nx += 1\nlocal s = `v={x}`\nfor _, v in {1} do continue end\nreturn s');
    expect(r).toEqual({ available: true, ok: true, errors: [] });
  });

  test('reports line and a friendly hint for JS-isms', async () => {
    const r = await checkLuauSyntax('local a = 1\nif a != 2 then\n  print(a)\nend');
    expect(r.ok).toBe(false);
    expect(r.errors[0].line).toBe(2);
    expect(r.errors[0].hint).toMatch(/~=/);
  });

  test('explains a missing end', async () => {
    const r = await checkLuauSyntax('for i = 1, 3 do\n  print(i)\n');
    expect(r.ok).toBe(false);
    expect(r.errors[0].hint).toMatch(/end/);
  });
});

describe('Beginner linter', () => {
  const rules = (src: string, ctx: any) => lintLuau(src, ctx).map((i) => i.rule);

  test('client APIs in a server script', () => {
    expect(rules('local p = game.Players.LocalPlayer', 'server')).toContain('client-api-in-server');
    expect(rules('remote:FireServer(1)', 'server')).toContain('client-api-in-server');
  });

  test('server APIs in a LocalScript', () => {
    expect(rules('local ds = game:GetService("DataStoreService")', 'client')).toContain('server-api-in-client');
    expect(rules('remote.OnServerEvent:Connect(function() end)', 'client')).toContain('server-api-in-client');
    expect(rules('player.leaderstats.Coins.Value = 5', 'client')).toContain('client-writes-leaderstats');
  });

  test('infinite loop without yield, but not with task.wait', () => {
    expect(rules('while true do\n  x += 1\nend', 'server')).toContain('loop-without-yield');
    expect(rules('while true do\n  if x then\n    y()\n  end\n  task.wait(1)\nend', 'server')).not.toContain('loop-without-yield');
  });

  test('deprecated globals and helpers', () => {
    const found = rules('wait(1)\nspawn(f)\ndelay(1, f)\npart.Touched:connect(f)\nlocal t = tick()', 'server');
    expect(found).toEqual(expect.arrayContaining(['deprecated-wait', 'deprecated-spawn', 'deprecated-delay', 'lowercase-connect', 'deprecated-tick']));
    expect(rules('task.wait(1)\ntask.spawn(f)', 'server')).toEqual([]);
  });

  test('ignores comments and strings', () => {
    expect(rules('-- wait(1) is deprecated\nprint("wait(1)")', 'server')).toEqual([]);
    expect(stripCommentsAndStrings('a = "x" -- c').includes('c')).toBe(false);
  });

  test('datastore without pcall, trusting the client, interpolation quotes', () => {
    expect(rules('local v = store:GetAsync(key)', 'server')).toContain('datastore-no-pcall');
    expect(rules('local ok, v = pcall(function() return store:GetAsync(key) end)', 'server')).not.toContain('datastore-no-pcall');
    expect(rules('remote.OnServerEvent:Connect(function(player, amount)\n  player.leaderstats.Coins.Value += amount\nend)', 'server')).toContain('trusts-client-value');
    expect(rules('print("Coins: {coins}")', 'server')).toContain('string-interpolation-quotes');
    expect(rules('local c = Color3.new(255, 0, 0)', 'server')).toContain('color3-range');
  });

  test('script context from class', () => {
    expect(contextFor('LocalScript')).toBe('client');
    expect(contextFor('Script', '', 'Client')).toBe('client');
    expect(contextFor('Script')).toBe('server');
    expect(contextFor('ModuleScript')).toBe('module');
  });
});

describe('Luau library', () => {
  test('every embedded Luau file compiles', async () => {
    const files = Object.keys(LUAU_SOURCES);
    expect(files.length).toBeGreaterThan(30);
    for (const file of files) await expectCompiles(LUAU_SOURCES[file], file);
  });

  test('embedded sources are up to date with gamekit/', () => {
    const script = [join(process.cwd(), 'scripts', 'embed-gamekit.mjs'), join(process.cwd(), '..', '..', 'scripts', 'embed-gamekit.mjs')].find(existsSync)!;
    expect(() => execFileSync(process.execPath, [script, '--check'], { stdio: 'pipe' })).not.toThrow();
    // Same for the Roblox API index (generated from packages/core/assets/globalTypes.d.luau).
    expect(() => execFileSync(process.execPath, [script.replace('embed-gamekit.mjs', 'embed-roblox-api.mjs'), '--check'], { stdio: 'pipe' })).not.toThrow();
  });

  test('GameKit scripts pass the beginner linter (no errors)', () => {
    for (const [file, source] of Object.entries(LUAU_SOURCES)) {
      if (file.startsWith('runtime/')) continue;
      const target = scriptTarget(file)!;
      const errors = lintLuau(source, contextFor(target.className, target.parent.join('.'))).filter((i) => i.severity === 'error');
      expect({ file, errors }).toEqual({ file, errors: [] });
    }
  });

  test('install targets follow the naming convention', () => {
    expect(scriptTarget('systems/shop/Shop.server.luau')).toEqual({ parent: ['ServerScriptService', 'GameKit'], name: 'Shop', className: 'Script' });
    expect(scriptTarget('systems/shop/Shop.client.luau')).toEqual({ parent: ['StarterPlayer', 'StarterPlayerScripts', 'GameKit'], name: 'ShopClient', className: 'LocalScript' });
    expect(scriptTarget('shared/Net.luau')?.parent).toEqual(['ReplicatedStorage', 'GameKit']);
    expect(scriptTarget('core/PlayerData.luau')?.className).toBe('ModuleScript');
    expect(scriptTarget('runtime/Applier.luau')).toBeNull();
  });
});

describe('Catalog', () => {
  test('every system file exists and dependencies resolve', () => {
    for (const s of SYSTEMS) {
      for (const f of s.files) expect(LUAU_SOURCES[f]).toBeDefined();
      const order = resolveSystems([s.id]).map((x) => x.id);
      expect(order[0]).toBe('core');
      for (const dep of s.requires) expect(order.indexOf(dep)).toBeLessThan(order.indexOf(s.id));
    }
  });

  test('config defaults match the defaults inside the Luau scripts', () => {
    for (const s of SYSTEMS) {
      for (const cfg of s.configs) {
        const users = s.files.map((f) => LUAU_SOURCES[f]).filter((src) => src.includes(`Util.config("${cfg.name}"`));
        if (cfg.name === 'Theme') {
          expect(LUAU_SOURCES['shared/UIKit.luau']).toContain('Util.config("Theme"');
          continue;
        }
        expect({ config: cfg.name, readBy: users.length }).toEqual({ config: cfg.name, readBy: expect.any(Number) });
        expect(users.length).toBeGreaterThan(0);
        for (const key of Object.keys(cfg.defaults)) {
          const mentioned = users.some((src) => new RegExp(`\\b${key}\\b`).test(src));
          expect({ config: cfg.name, key, mentioned }).toEqual({ config: cfg.name, key, mentioned: true });
        }
      }
    }
  });

  test('generated config modules are valid Luau', async () => {
    for (const s of SYSTEMS) {
      for (const cfg of s.configs) await expectCompiles(configModule(cfg.name, cfg.defaults, cfg.docs, cfg.intro), `config ${cfg.name}`);
    }
    await expectCompiles(`return ${toLuau({ Products: { '123456': { Kind: 'Stat' } }, 'weird key': [1, 'a', true], end: 1 })}`, 'toLuau');
  });

  test('configs are kept unless overridden', () => {
    const plain = systemPlacements(['shop']).placements.filter((p) => p.node.className === 'ModuleScript' && (p.parent as string[]).includes('Config'));
    expect(plain.every((p) => p.mode === 'keep')).toBe(true);
    const overridden = systemPlacements(['shop'], { config: { Shop: { Currency: 'Gems' } } }).placements.find((p) => p.node.name === 'Shop' && (p.parent as string[]).includes('Config'));
    expect(overridden?.mode).toBe('replace');
    expect(overridden?.node.source).toContain('Currency = "Gems"');
  });
});

describe('World generators', () => {
  const collect = (node: InstanceNode, out: InstanceNode[] = []) => {
    out.push(node);
    (node.children ?? []).forEach((c) => collect(c, out));
    return out;
  };

  test('every world and piece builds', () => {
    for (const w of WORLDS) expect(countParts(buildWorld(w, {}))).toBeGreaterThan(0);
    for (const p of PIECES) expect(countParts(buildWorld(p, { position: [0, 5, 0] }))).toBeGreaterThan(0);
    expect(() => buildWorld('nope', {})).toThrow(/Unknown piece/);
  });

  test('obby: consecutive checkpoints, finish line, lava sea, deterministic', () => {
    const course = obbyCourse({ stages: 15, seed: 3 });
    const nodes = collect(course);
    const stages = nodes.filter((n) => n.tags?.includes('Checkpoint')).map((n) => n.attrs?.Stage as number).sort((a, b) => a - b);
    expect(stages).toEqual(Array.from({ length: 15 }, (_, i) => i + 1));
    expect(nodes.some((n) => n.tags?.includes('FinishLine'))).toBe(true);
    expect(nodes.some((n) => n.name === 'LavaSea' && n.tags?.includes('KillPart'))).toBe(true);
    expect(JSON.stringify(obbyCourse({ stages: 15, seed: 3 }))).toEqual(JSON.stringify(course));
    for (const t of OBSTACLES) expect(countParts(obbyCourse({ stages: 3, obstacles: [t] }))).toBeGreaterThan(3);
  });

  test('maze has keys, exit and a monster spawner', () => {
    const nodes = collect(buildWorld('maze', { width: 8, height: 8, keys: 3 }));
    expect(nodes.filter((n) => n.tags?.includes('Key'))).toHaveLength(3);
    expect(nodes.some((n) => n.tags?.includes('ExitDoor'))).toBe(true);
    expect(nodes.some((n) => n.tags?.includes('ExitZone'))).toBe(true);
    expect(nodes.some((n) => n.tags?.includes('EnemySpawner'))).toBe(true);
  });

  test('race track: checkpoints 1..3 in order, a finish line and a grid', () => {
    const nodes = collect(buildWorld('race_track', { grid: 6 }));
    const orders = nodes.filter((n) => n.tags?.includes('RaceCheckpoint')).map((n) => n.attrs?.Order);
    expect(orders).toEqual([1, 2, 3]);
    expect(nodes.filter((n) => n.tags?.includes('RaceFinish'))).toHaveLength(1);
    expect(nodes.filter((n) => n.tags?.includes('RaceGrid'))).toHaveLength(6);
  });

  test('fishing spots and resource nodes use zones/nodes that exist in the configs', () => {
    const configOf = (system: string, name: string) => SYSTEMS.find((s) => s.id === system)!.configs.find((c) => c.name === name)!.defaults as any;
    const zones = Object.keys(configOf('fishing', 'Fishing').Zones);
    const spots = collect(buildWorld('fishing_lake', {})).filter((n) => n.tags?.includes('FishingSpot'));
    expect(spots.length).toBeGreaterThan(4);
    for (const spot of spots) expect(zones).toContain(spot.attrs?.Zone);
    const nodeTypes = Object.keys(configOf('crafting', 'Crafting').Nodes);
    const camp = collect(buildWorld('survival_camp', {}));
    const resources = camp.filter((n) => n.tags?.includes('ResourceNode'));
    expect(new Set(resources.map((n) => n.attrs?.Node))).toEqual(new Set(nodeTypes));
    expect(camp.some((n) => n.tags?.includes('CraftingTable'))).toBe(true);
    expect(camp.filter((n) => n.tags?.includes('EnemySpawner'))).toHaveLength(4);
  });

  test('template quests only use items that exist', () => {
    for (const t of TEMPLATES) {
      const plan = t.plan({});
      const quests = (plan.config.Quests?.List ?? []) as Array<{ Type: string; Item?: string }>;
      const items = new Set<string>(['Wood', 'Stone', 'Berry', 'Planks']);
      const fishing = SYSTEMS.find((s) => s.id === 'fishing')!.configs[0].defaults as any;
      for (const zone of Object.values(fishing.Zones) as any[]) for (const f of zone.Fish) items.add(f.Id);
      for (const q of quests.filter((x) => x.Type === 'Have')) expect({ template: t.id, item: q.Item, known: items.has(q.Item!) }).toEqual({ template: t.id, item: q.Item, known: true });
      for (const q of quests) expect(['Earn', 'Reach', 'Have', 'Touch']).toContain(q.Type);
    }
  });

  test('quest guide arrows point at something that exists in the template world', () => {
    for (const t of TEMPLATES) {
      const plan = t.plan({});
      const nodes = plan.world.flatMap((p) => collect(p.node));
      const quests = (plan.config.Quests?.List ?? []) as Array<{ Id: string; Type: string; Target?: string }>;
      for (const q of quests) {
        const spec = q.Type === 'Touch' ? `quest:${q.Id}` : q.Target;
        if (!spec) continue;
        const m = /^(?:quest:(.+)|tag:([^/]+)(?:\/([^=]+)=(.+))?)$/.exec(spec);
        expect({ template: t.id, quest: q.Id, valid: !!m }).toEqual({ template: t.id, quest: q.Id, valid: true });
        const [, questId, tag, key, value] = m!;
        const found = nodes.some((n) => questId
          ? n.tags?.includes('QuestTarget') && n.attrs?.Quest === questId
          : n.tags?.includes(tag) && (!key || String(n.attrs?.[key]) === value));
        expect({ template: t.id, quest: q.Id, target: spec, found }).toEqual({ template: t.id, quest: q.Id, target: spec, found: true });
      }
    }
  });

  test('tycoon buttons reference existing items', () => {
    const plots = collect(buildWorld('tycoon_plots', { count: 2 })).filter((n) => n.tags?.includes('TycoonPlot'));
    expect(plots).toHaveLength(2);
    for (const plot of plots) {
      const items = new Set(plot.children!.find((c) => c.name === 'Items')!.children!.map((c) => c.name));
      for (const button of plot.children!.find((c) => c.name === 'Buttons')!.children!) {
        expect(items.has(button.attrs!.Item as string)).toBe(true);
        if (button.attrs!.Requires) expect(items.has(button.attrs!.Requires as string)).toBe(true);
      }
    }
  });
});

describe('Installer', () => {
  test('installers for every template compile and embed a payload safely', async () => {
    for (const t of TEMPLATES) {
      const plan = t.plan({});
      const { placements } = systemPlacements(plan.systems, { config: plan.config, resetConfig: true });
      const code = buildInstallerLuau({ label: t.id, items: [...placements, ...plan.world] });
      expect(code).not.toContain('-- @payload');
      await expectCompiles(code, `template ${t.id}`);
    }
    const tricky = buildInstallerLuau({ label: 'x', items: [{ parent: 'Workspace', node: { name: 'S', className: 'Script', source: 'local a = [[x]] local b = [=[y]=] local c = [==[z]==]' } }] });
    await expectCompiles(tricky, 'tricky');
  });

  test('path splitting', () => {
    expect(splitPath('game.ServerScriptService.Foo')).toEqual(['ServerScriptService', 'Foo']);
    expect(splitPath('StarterPlayer/StarterPlayerScripts/X')).toEqual(['StarterPlayer', 'StarterPlayerScripts', 'X']);
  });

  test('long strings never terminate early', () => {
    expect(longString('a]=]b')).toMatch(/^\[==\[/);
    expect(longString('a]]b')).toBe('[=[a]]b]=]');
    expect(longString('plain')).toBe('[=[plain]=]');
  });
});

describe('UI builder, environment, knowledge', () => {
  test('UI example converts with binder attributes', () => {
    const gui = buildScreenGui(UI_EXAMPLE);
    expect(gui.className).toBe('ScreenGui');
    const json = JSON.stringify(gui);
    expect(json).toContain('"GK_Bind":"stat:Coins"');
    expect(json).toContain('"GK_Action":"toggle:MenuWindow"');
    expect(missingActionTargets(UI_EXAMPLE)).toEqual([]);
    expect(missingActionTargets({ name: 'x', children: [{ type: 'button', action: 'open:Nope' }] })).toEqual(['Nope']);
  });

  test('every lighting preset and terrain mode compiles', async () => {
    for (const preset of Object.keys(LIGHTING_PRESETS)) await expectCompiles(buildEnvironmentLuau({ preset }), preset);
    for (const terrain of TERRAIN_MODES) await expectCompiles(buildEnvironmentLuau({ terrain, water: true }), terrain);
    expect(() => buildEnvironmentLuau({ preset: 'nope' })).toThrow(/Unknown lighting preset/);
  });

  test('guides, catalog, prompts and resources', () => {
    for (const topic of Object.keys(GUIDES)) expect(guideText(topic).length).toBeGreaterThan(200);
    for (const s of SYSTEMS) expect(guideText(s.id)).toContain(s.title);
    for (const t of TEMPLATES) expect(guideText(t.id)).toContain(t.title);
    expect(guideText('???')).toMatch(/Unknown topic/);
    expect(catalogText()).toContain('obby');
    expect(PROMPTS.map((p) => p.build({ idea: 'a candy obby', feature: 'shop' })).every((s) => s.includes('test_game'))).toBe(true);
    expect(listResources().every((r) => r.read().length > 50)).toBe(true);
    expect(SERVER_INSTRUCTIONS).toContain('roblox_start_here');
  });

  test('runtime error hints', () => {
    expect(hintForRuntimeError("Workspace.Script:3: attempt to index nil with 'Value'")).toMatch(/\.Value/);
    expect(hintForRuntimeError('Script timeout: exhausted allowed execution time')).toMatch(/task.wait/);
    expect(parseRuntimeError('ServerScriptService.GameKit.Shop:42: boom')).toEqual({ script: 'ServerScriptService.GameKit.Shop', line: 42, message: 'boom' });
  });
});

describe('Tool profiles', () => {
  test('starter hides advanced tools, full shows all', () => {
    expect(getProfile()).toBe('starter');
    expect(baseToolVisible('execute_luau')).toBe(true);
    expect(baseToolVisible('terrain_fill_block')).toBe(false);
    setProfile('builder');
    expect(baseToolVisible('add_tag')).toBe(true);
    setProfile('full');
    expect(baseToolVisible('terrain_fill_block')).toBe(true);
    setProfile('starter');
    expect(() => setProfile('mega')).toThrow(/Unknown profile/);
  });

  test('tool schemas: every array declares items', () => {
    const bad: string[] = [];
    const walk = (schema: any, path: string) => {
      if (!schema || typeof schema !== 'object') return;
      if (schema.type === 'array' && !schema.items) bad.push(path);
      for (const [k, v] of Object.entries(schema.properties ?? {})) walk(v, `${path}.${k}`);
      if (schema.items) walk(schema.items, `${path}[]`);
    };
    for (const t of GAMEKIT_TOOLS) walk(t.inputSchema, t.name);
    expect(bad).toEqual([]);
  });
});

describe('GameKit tools with a fake Studio', () => {
  function fakeHost(connected = true) {
    const calls: string[] = [];
    let running = false;
    const host: GameKitHost & { calls: string[] } = {
      calls,
      isStudioConnected: () => connected,
      runLuau: async (code: string) => {
        calls.push(code);
        if (code.includes('local PAYLOAD')) {
          return { success: true, returnValue: JSON.stringify({ ok: true, created: 10, replaced: 0, kept: 0, merged: 0, deleted: 0, warnings: [], roots: [] }) };
        }
        if (code.includes('GameKit environment')) return { success: true, returnValue: JSON.stringify({ ok: true, applied: ['lighting'] }) };
        return { success: true, returnValue: JSON.stringify({ place: 'Test', gameKit: false, installedSystems: [], worldPieces: [], scripts: 0, parts: 1 }) };
      },
      startPlaytest: async () => {
        running = true;
        setTimeout(() => (running = false), 10);
        return { success: true };
      },
      stopPlaytest: async () => ({ success: true }),
      getPlaytestOutput: async () => ({
        isRunning: running,
        output: [{ message: 'Workspace.Broken:3: attempt to index nil with \'Value\'', messageType: 'MessageError' }],
        testResult: running ? undefined : JSON.stringify({
          serverErrors: [], clientErrors: [], serverWarnings: [],
          facts: { characterSpawned: true, aliveAfter3s: true, fellIntoVoid: false, dataLoaded: true },
          probes: [{ name: 'checkpoints', ok: true, detail: 'ok' }],
          clientFacts: { hudPresent: true },
        }),
      }),
    };
    return host;
  }

  test('start_here without Studio gives setup steps', async () => {
    const result = parse(await new GameKit(fakeHost(false)).call('roblox_start_here'));
    expect(result.studio.connected).toBe(false);
    expect(result.studio.fix.join(' ')).toMatch(/Plugins/);
  });

  test('create_game installs systems + world + lighting in two Studio calls', async () => {
    const host = fakeHost();
    const result = parse(await new GameKit(host).call('create_game', { template: 'obby', options: { stages: 5 }, backup: false }));
    expect(result.ok).toBe(true);
    expect(result.systems).toEqual(expect.arrayContaining(['core', 'checkpoints', 'hud']));
    expect(host.calls).toHaveLength(2);
    expect(host.calls[0]).toContain('ObbyCourse');
  });

  test('create_game saves a backup first when the place has content', async () => {
    const host = fakeHost();
    const runLuau = host.runLuau;
    host.runLuau = async (code: string) => {
      if (code.includes('return tostring(n)')) return { success: true, returnValue: '12' };
      if (code.includes('GameKitBackups')) return { success: true, returnValue: JSON.stringify({ ok: true, backup: { id: 'B42' } }) };
      return runLuau(code);
    };
    const result = parse(await new GameKit(host).call('create_game', { template: 'tycoon' }));
    expect(result.backup.id).toBe('B42');
    expect(result.backup.restore).toContain('B42');
  });

  test('write_script refuses broken code before touching Studio', async () => {
    const host = fakeHost();
    const result = parse(await new GameKit(host).call('write_script', { path: 'ServerScriptService/Bad', source: 'if x then' }));
    expect(result.written).toBe(false);
    expect(host.calls).toHaveLength(0);
    const blocked = parse(await new GameKit(host).call('write_script', { path: 'ServerScriptService/Bad', source: 'local p = game.Players.LocalPlayer\nprint(p)' }));
    expect(blocked.written).toBe(false);
    const ok = parse(await new GameKit(host).call('write_script', { path: 'ServerScriptService/Good', source: 'print("hi")' }));
    expect(ok.written).toBe(true);
    expect(ok.className).toBe('Script');
  });

  test('check_luau works offline', async () => {
    const result = parse(await new GameKit(fakeHost(false)).call('check_luau', { source: 'while true do end', kind: 'server' }));
    expect(result.warnings.map((w: any) => w.rule)).toContain('loop-without-yield');
  });

  test('test_game reports plugin-captured errors with hints and cleans up', async () => {
    const host = fakeHost();
    const result = parse(await new GameKit(host).call('test_game', { seconds: 8 }));
    expect(result.verdict).toBe('FAIL');
    expect(result.errors[0].hint).toMatch(/\.Value/);
    expect(result.passedChecks[0]).toMatch(/checkpoints/);
    expect(host.calls.some((c) => c.includes('__GameKitTestRunner') && c.includes('deletes'))).toBe(true);
  }, 20000);
});
