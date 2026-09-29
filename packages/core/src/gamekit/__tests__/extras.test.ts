import net from 'net';
import { checkLuauSyntax } from '../luau-syntax.js';
import { animationPython, animatorLuau, BlenderClient, BlenderTools, exportPython, keyframeLuau, safeModeViolation, STUDS_PER_METER } from '../blender.js';
import { spawnSync } from 'child_process';
import { analyse, farmingReport, nicePrice, simulate, suggestPrices, towerDefenseReport } from '../economy.js';
import { JobRegistry, handleJobTool } from '../jobs.js';
import { scatter, placeModelLuau, POPULATE_THEMES } from '../props.js';
import { defaultPlan } from '../team.js';
import { viewEye, VIEWS } from '../visual.js';
import { backupLuau } from '../backup.js';
import { toolVisible } from '../mcp-extras.js';
import { revealGroup, setProfile } from '../profiles.js';
import { getSystem } from '../catalog.js';
import { farm, tdMap, DECOR_PIECES, piece } from '../world.js';
import { GameKit, GAMEKIT_TOOLS, type GameKitHost } from '../tools.js';
import { assetsLuau, assetVerdict, optimizeFindings, optimizeLuau } from '../quality.js';
import { pickDevice, runPlaytest } from '../playtest.js';
import { checkRobloxApi } from '../api-check.js';
import type { InstanceNode } from '../installer.js';

const parse = (result: any) => JSON.parse(result.content[0].text);

async function expectCompiles(code: string, label: string) {
  const r = await checkLuauSyntax(code, label);
  if (!r.ok) throw new Error(`${label}: ${JSON.stringify(r.errors)}\n${code.slice(0, 400)}`);
}

/** A fake Studio that records every Luau snippet and answers with plausible JSON. */
function recordingHost(extra: Partial<GameKitHost> = {}) {
  const calls: string[] = [];
  const host: GameKitHost & { calls: string[] } = {
    calls,
    isStudioConnected: () => true,
    runLuau: async (code: string) => {
      calls.push(code);
      if (code.includes('local PAYLOAD')) {
        return { success: true, returnValue: JSON.stringify({ ok: true, created: 1, replaced: 0, kept: 0, merged: 0, deleted: 0, warnings: [], roots: [] }) };
      }
      if (code.includes('truncatedScripts')) return { success: true, returnValue: JSON.stringify({ scripts: [], facts: { parts: 1, unanchored: 0, spawns: 1 }, tags: {}, loose: [], checkpointStages: [], truncatedScripts: 0 }) };
      if (code.includes('placeId = game.PlaceId')) return { success: true, returnValue: JSON.stringify({ placeId: 0, spawns: 1, guis: 3, wideOffsetGuis: 0, backups: 0, maxPlayers: 12, lighting: true }) };
      if (code.includes('GameKitTeam')) return { success: true, returnValue: JSON.stringify({ ok: true, tasks: [{ id: 'T1', title: 'Core game', status: 'doing', owner: 'a' }], zones: [{ name: 'main', owner: 'a', center: [0, 20, 0], size: [100, 40, 100] }] }) };
      if (code.includes('GameKitBackups')) return { success: true, returnValue: JSON.stringify({ ok: true, backups: [], backup: { id: 'B1' } }) };
      if (code.includes('camera = {')) return { success: true, returnValue: JSON.stringify({ ok: true, parts: 3, min: [-10, 0, -10], max: [10, 10, 10], camera: [0, 10, 20, 1, 0, 0, 0, 1, 0, 0, 0, 1], focus: [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1], fov: 70 }) };
      if (code.includes('tycoon = nil')) return { success: true, returnValue: JSON.stringify({ tycoon: { items: [{ name: 'Dropper1', price: 0, addIncome: 2.5 }, { name: 'Dropper2', price: 50, requires: 'Dropper1', addIncome: 5 }], passive: 0, currency: 'Cash' } }) };
      if (code.includes('cam.CFrame = CFrame.lookAt') || code.includes('cam.Focus = CFrame.new(')) return { success: true, returnValue: 'ok' };
      return { success: true, returnValue: JSON.stringify({ ok: true, placed: 4, removed: 1, snapped: 4, errors: [] }) };
    },
    startPlaytest: async () => ({ success: true }),
    stopPlaytest: async () => ({ success: true }),
    getPlaytestOutput: async () => ({ isRunning: false, output: [] }),
    ...extra,
  };
  return host;
}

describe('Blender bridge', () => {
  /** A fake "MCP for Blender" addon: JSON in, JSON out (sent in two chunks). */
  function fakeAddon(handler: (cmd: any) => any): Promise<{ port: number; close: () => void; seen: any[] }> {
    const seen: any[] = [];
    const server = net.createServer((socket) => {
      let buffer = '';
      socket.on('data', (d) => {
        buffer += d.toString('utf8');
        let cmd: any;
        try {
          cmd = JSON.parse(buffer);
        } catch {
          return;
        }
        buffer = '';
        seen.push(cmd);
        const reply = JSON.stringify(handler(cmd));
        const half = Math.floor(reply.length / 2);
        socket.write(reply.slice(0, half));
        setTimeout(() => socket.write(reply.slice(half)), 5);
      });
    });
    return new Promise((resolve) => server.listen(0, '127.0.0.1', () => {
      const port = (server.address() as net.AddressInfo).port;
      resolve({ port, seen, close: () => server.close() });
    }));
  }

  test('speaks the addon protocol, reassembles chunked replies and surfaces errors', async () => {
    const addon = await fakeAddon((cmd) => cmd.type === 'boom'
      ? { status: 'error', message: 'kaboom' }
      : { status: 'success', result: { echo: cmd.params } });
    const client = new BlenderClient('127.0.0.1', addon.port);
    await expect(client.command('get_scene_info', { a: 1 })).resolves.toEqual({ echo: { a: 1 } });
    await expect(client.command('boom')).rejects.toThrow('kaboom');
    // Queued: sent in order, one at a time.
    const results = await Promise.all([1, 2, 3].map((n) => client.command('n', { n })));
    expect(results.map((r: any) => r.echo.n)).toEqual([1, 2, 3]);
    expect(addon.seen.map((c) => c.type)).toEqual(['get_scene_info', 'boom', 'n', 'n', 'n']);
    addon.close();
  });

  test('offline Blender gives install steps', async () => {
    const client = new BlenderClient('127.0.0.1', 1);
    await expect(client.command('ping', {}, 2000)).rejects.toThrow(/addon/);
    const tools = new BlenderTools(recordingHost(), client);
    const status = parse(await tools.call('blender_status', {}));
    expect(status.connected).toBe(false);
    expect(status.fix.join(' ')).toMatch(/addon\.py/);
  });

  test('blender_to_roblox exports, and without an API key explains the manual import', async () => {
    const addon = await fakeAddon((cmd) => ({
      status: 'success',
      result: { executed: true, result: `log\n@@GAMEKIT@@${JSON.stringify({ path: '/nonexistent/x.fbx', bytes: 0, sizeMeters: [2, 3, 1], triangles: 1200, warnings: [], objects: [] })}\n` },
    }));
    let connected = 0;
    const tools = new BlenderTools(recordingHost({ hasOpenCloudKey: () => false }), new BlenderClient('127.0.0.1', addon.port), { onConnected: () => connected++ });
    const result = parse(await tools.call('blender_to_roblox', { name: 'Statue' }));
    expect(result.uploaded).toBe(false);
    expect(result.manualImport.join(' ')).toMatch(/Import 3D/);
    expect(result.steps.export.sizeMeters).toEqual([2, 3, 1]);
    expect(connected).toBeGreaterThan(0);
    addon.close();
  });

  test('export script keeps the scene intact and converts units', async () => {
    const py = exportPython({ format: 'fbx', path: '/tmp/a.fbx', maxTriangles: 20000, decimate: true, textureMax: 1024 });
    expect(py).toContain('GameKitDecimate');
    expect(py).toContain('modifiers.remove');
    expect(py).toContain('export_scene.fbx');
    expect(STUDS_PER_METER).toBeCloseTo(3.57, 2);
  });

  test('rig and animation scripts are valid Python and Luau', async () => {
    const scripts = {
      export: exportPython({ format: 'fbx', path: '/tmp/a.fbx', maxTriangles: 20000, decimate: true, textureMax: 1024 }),
      animation: animationPython({ fps: 30, maxFrames: 400, scale: STUDS_PER_METER, fbxPath: '/tmp/anim.fbx', action: "Walk'\"" }),
    };
    expect(scripts.export).toContain("'ARMATURE'");
    expect(scripts.export).toContain('add_leaf_bones=False');
    for (const [label, py] of Object.entries(scripts)) {
      const check = spawnSync('python3', ['-c', 'import ast,sys; ast.parse(sys.stdin.read())'], { input: py, encoding: 'utf8' });
      if (check.error) continue; // no Python on this machine
      expect({ label, status: check.status, err: check.stderr }).toEqual({ label, status: 0, err: '' });
    }
    const kfs = keyframeLuau({
      name: 'Walk', loop: true, priority: 'Movement', rig: 'Workspace/GameKit/Props/Knight',
      bones: [{ name: 'Hips', parent: null }, { name: 'Leg', parent: 'Hips' }],
      samples: [{ t: 0, p: { Leg: [0, 0, 0, 0, 0, 0.38, 0.92] } }, { t: 0.5, p: {} }],
    });
    for (const [label, code] of [['keyframes', kfs], ['animator', animatorLuau('Workspace/GameKit/Props/Knight')]] as const) {
      await expectCompiles(code, label);
      expect({ label, issues: checkRobloxApi(code) }).toEqual({ label, issues: [] });
    }
  });

  test('blender_animation samples the action and builds the KeyframeSequence in Studio', async () => {
    const sampled = { action: 'Walk', actions: ['Walk', 'Idle'], fps: 24, length: 1, frames: 2, warnings: [],
      bones: [{ name: 'Hips', parent: null }], samples: [{ t: 0, p: {} }, { t: 1, p: { Hips: [0, 1, 0, 0, 0, 0, 1] } }] };
    const addon = await fakeAddon(() => ({ status: 'success', result: { executed: true, result: `@@GAMEKIT@@${JSON.stringify(sampled)}\n` } }));
    const host = recordingHost({
      runLuau: async (code: string) => {
        host.calls.push(code);
        return { success: true, returnValue: JSON.stringify({ ok: true, path: 'ServerStorage.GameKit.Animations.Walk', rootPose: 'Body', tempId: 'rbxtemp://1', warnings: [] }) };
      },
    });
    const tools = new BlenderTools(host, new BlenderClient('127.0.0.1', addon.port));
    const result = parse(await tools.call('blender_animation', { rig: 'Workspace/Knight', fbx: false }));
    expect(result.ok).toBe(true);
    expect(result.testId).toBe('rbxtemp://1');
    expect(result.otherActions).toEqual(['Idle']);
    expect(host.calls[0]).toContain('KeyframeSequenceProvider');
    expect(addon.seen[0].params.code).toContain('matrix_basis');
    addon.close();
  });

  test('safe mode reuses the vendored validator', () => {
    process.env.BLENDER_MCP_SAFE_MODE = '1';
    try {
      const verdict = safeModeViolation('import os\nos.system("rm -rf /")');
      // Either python rejected it, or no python/validator was found: never allowed.
      expect(verdict).not.toBeNull();
      const fine = safeModeViolation('import bpy\nbpy.ops.mesh.primitive_cube_add(size=2)');
      if (!/no Python|not found/.test(String(fine))) expect(fine).toBeNull();
    } finally {
      delete process.env.BLENDER_MCP_SAFE_MODE;
    }
    expect(safeModeViolation('import os')).toBeNull();
  });

  test('blender tools are listed once Blender is connected (or in builder)', () => {
    setProfile('starter');
    expect(toolVisible('blender_to_roblox')).toBe(true);
    expect(toolVisible('blender_status')).toBe(true);
    expect(toolVisible('blender_python')).toBe(false);
    expect(toolVisible('balance_economy')).toBe(false);
    setProfile('builder');
    expect(toolVisible('blender_python')).toBe(true);
    setProfile('starter');
    revealGroup('blender');
    expect(toolVisible('blender_python')).toBe(true);
    expect(toolVisible('blender_command')).toBe(false);
  });
});

describe('Background jobs', () => {
  test('start, wait, result, failures, listing', async () => {
    const jobs = new JobRegistry();
    const run = async (tool: string) => {
      if (tool === 'slow') {
        await new Promise((r) => setTimeout(r, 50));
        return { content: [{ type: 'text', text: '{"done":true}' }] };
      }
      throw new Error('nope');
    };
    const started = parse(await handleJobTool(jobs, 'start_job', { tool: 'slow' }, run));
    expect(started.status).toBe('running');
    const finished = await handleJobTool(jobs, 'job_status', { id: started.jobId, wait: 5 }, run);
    expect(JSON.parse(finished.content[0].text!).status).toBe('done');
    expect(finished.content[1].text).toBe('{"done":true}');
    const bad = parse(await handleJobTool(jobs, 'start_job', { tool: 'broken' }, run));
    const failed = await handleJobTool(jobs, 'job_status', { id: bad.jobId, wait: 5 }, run);
    expect(JSON.parse(failed.content[0].text!).error).toMatch(/nope/);
    const list = parse(await handleJobTool(jobs, 'job_status', {}, run));
    expect(list.jobs).toHaveLength(2);
    await expect(handleJobTool(jobs, 'start_job', { tool: 'start_job' }, run)).rejects.toThrow(/background/);
  });

  test('GameKit runs its own tools as jobs', async () => {
    const kit = new GameKit(recordingHost());
    const started = parse(await kit.call('start_job', { tool: 'check_luau', arguments: { source: 'print(1)' } }));
    const result = await kit.call('job_status', { id: started.jobId, wait: 10 });
    expect(JSON.parse(result.content[0].text!).status).toBe('done');
    expect(JSON.parse(result.content[1].text!).ok).toBe(true);
  });
});

describe('Economy balancer', () => {
  test('nice prices', () => {
    expect(nicePrice(97)).toBe(100);
    expect(nicePrice(1234)).toBe(1200);
    expect(nicePrice(2600)).toBe(2500);
    expect(nicePrice(4)).toBe(4);
  });

  test('simulation follows requires and flags walls and unreachable items', () => {
    const { timeline } = simulate({ incomePerSecond: 1, items: [{ name: 'A', price: 10, addIncome: 1 }, { name: 'B', price: 100, requires: 'A' }] });
    expect(timeline.map((r) => r.item)).toEqual(['A', 'B']);
    expect(timeline[0].waitSeconds).toBe(10);
    expect(timeline[1].waitSeconds).toBe(50);
    const stuck = analyse({ items: [{ name: 'X', price: 10 }] });
    expect(stuck.verdict).toBe('broken');
    const wall = analyse({ incomePerSecond: 1, items: [{ name: 'A', price: 30 }, { name: 'B', price: 5000 }] });
    expect(wall.warnings.join(' ')).toMatch(/Wall/);
  });

  test('suggested prices give growing waits that reach the target', () => {
    const input = { incomePerSecond: 2, items: Array.from({ length: 8 }, (_, i) => ({ name: `I${i}`, price: 10, addIncome: 2 + i })), targetMinutes: 30 };
    const suggested = suggestPrices(input);
    const waits = suggested.map((s) => s.waitSeconds);
    for (let i = 1; i < waits.length; i++) expect(waits[i]).toBeGreaterThanOrEqual(waits[i - 1]);
    const replay = analyse({ ...input, items: input.items.map((it, i) => ({ ...it, price: suggested[i].price })) });
    expect(replay.totalMinutes).toBeGreaterThan(15);
    expect(replay.totalMinutes).toBeLessThan(60);
  });

  test('default farming and tower defense configs are balanced', () => {
    const farming = farmingReport(getSystem('farming').configs[0].defaults);
    expect(farming.warnings).toEqual([]);
    const td = towerDefenseReport(getSystem('towerdefense').configs[0].defaults);
    expect(td.warnings).toEqual([]);
  });

  test('fromGame reads the tycoon in Studio', async () => {
    const result = parse(await new GameKit(recordingHost()).call('balance_economy', { fromGame: true }));
    expect(result.tycoon.timeline.map((r: any) => r.item)).toEqual(['Dropper1', 'Dropper2']);
  });
});

describe('Props, team, visuals, backups', () => {
  test('scatter keeps spacing and the clear center', () => {
    const points = scatter({ center: [0, 0, 0], radius: 100, clear: 30 }, 40, 8, 3);
    expect(points.length).toBeGreaterThan(30);
    for (const [x, z] of points) expect(Math.hypot(x, z)).toBeGreaterThanOrEqual(29.9);
    for (let i = 0; i < points.length; i++) {
      for (let j = i + 1; j < points.length; j++) {
        expect(Math.hypot(points[i][0] - points[j][0], points[i][1] - points[j][1])).toBeGreaterThanOrEqual(8);
      }
    }
  });

  test('every populate theme uses real decoration pieces', () => {
    for (const [theme, entries] of Object.entries(POPULATE_THEMES)) {
      for (const [kind] of entries) {
        expect(DECOR_PIECES as readonly string[]).toContain(kind);
        expect(() => piece(kind, [0, 0, 0], {})).not.toThrow();
      }
      expect(theme).toBeTruthy();
    }
  });

  test('default team plan covers every role', () => {
    const plan = defaultPlan('obby', 'a neon obby');
    expect(new Set(plan.map((t) => t.role))).toEqual(new Set(['lead', 'builder', 'artist', 'ui', 'designer', 'qa']));
    expect(plan[0].details).toMatch(/neon obby/);
  });

  test('camera views look at the target', () => {
    for (const view of VIEWS) {
      const { eye, at } = viewEye(view, [0, 10, 0], [100, 20, 100], 150, [0, 5, 40]);
      expect(Math.hypot(eye[0] - at[0], eye[1] - at[1], eye[2] - at[2])).toBeGreaterThan(5);
    }
  });

  test('every generated Luau snippet compiles', async () => {
    const host = recordingHost({ callTool: async () => ({ content: [{ type: 'image', data: 'AAAA', mimeType: 'image/png' }] }) });
    const kit = new GameKit(host);
    await kit.call('populate_world', { theme: 'forest', count: 20, items: [{ assetId: 123, count: 2, size: [6, 10] }, { from: 'Workspace/GameKit/Props/Statue', count: 2 }] });
    await kit.call('populate_world', { zone: 'main', items: [{ kind: 'tree', count: 3 }] });
    for (const action of ['plan', 'list', 'claim', 'done', 'release', 'block', 'note', 'claim_zone', 'release_zone', 'zones']) {
      await kit.call('team', { action, agent: 'claude-1', task: 'T1', zone: 'main', center: [0, 20, 0], size: [50, 40, 50], title: 'x' });
    }
    await kit.call('team', { action: 'add', title: 'Fix bug', details: 'line 3' });
    for (const action of ['save', 'list', 'restore', 'delete']) await kit.call('backup_game', { action, label: 'test', id: 'B1' });
    const look = await kit.call('look_at_game', { views: ['iso', 'top', 'player'] });
    expect(look.content.filter((c: any) => c.type === 'image')).toHaveLength(3);
    await kit.call('balance_economy', { fromGame: true });
    await kit.call('publish_checklist', {});
    await kit.call('build_world', { kind: 'tower_pad', zone: 'main' });
    for (const code of host.calls) await expectCompiles(code, code.slice(0, 60));
    await expectCompiles(placeModelLuau({ name: 'M', assetId: 1, parent: 'Workspace/GameKit/Props', position: [0, 0, 0], size: 10, yaw: 90 }), 'placeModel');
    await expectCompiles(placeModelLuau({ name: 'M', existing: 'Workspace/Imported', parent: 'Workspace/GameKit/Props', position: [1, 2, 3] }), 'placeExisting');
    await expectCompiles(backupLuau({ action: 'save', label: ']]==]' }), 'backup with tricky label');
    expect(host.calls.length).toBeGreaterThan(20);
  }, 60000);

  test('team actions that need an agent refuse without one', async () => {
    await expect(new GameKit(recordingHost()).call('team', { action: 'claim' })).rejects.toThrow(/agent/);
  });
});

describe('Tower defense and farming worlds', () => {
  const all = (node: InstanceNode): InstanceNode[] => [node, ...(node.children ?? []).flatMap(all)];

  test('td_map: ordered waypoints, pads off the road, a base', () => {
    const nodes = all(tdMap());
    const path = nodes.find((n) => n.tags?.includes('TDPath'))!;
    const orders = path.children!.map((c) => c.attrs!.Order as number);
    expect(orders).toEqual([...orders].sort((a, b) => a - b));
    expect(nodes.filter((n) => n.tags?.includes('TowerPad')).length).toBeGreaterThanOrEqual(12);
    expect(nodes.some((n) => n.tags?.includes('TDBase'))).toBe(true);
    const roads = nodes.filter((n) => n.name.startsWith('Road'));
    for (const pad of nodes.filter((n) => n.tags?.includes('TowerPad'))) {
      const [px, , pz] = (pad.props!.CFrame as any).$cf;
      for (const road of roads) {
        const [rx, , rz] = (road.props!.CFrame as any).$cf;
        const [sx, , sz] = (road.props!.Size as any).$v3;
        const overlapX = Math.abs(px - rx) < sx / 2 + 4;
        const overlapZ = Math.abs(pz - rz) < sz / 2 + 4;
        expect(overlapX && overlapZ).toBe(false);
      }
    }
  });

  test('farm: plots, one seed stand per crop, a market', () => {
    const nodes = all(farm({ plots: 16 }));
    expect(nodes.filter((n) => n.tags?.includes('FarmPlot'))).toHaveLength(16);
    const crops = Object.keys((getSystem('farming').configs[0].defaults as any).Crops);
    const stands = nodes.filter((n) => n.tags?.includes('SeedStand')).map((n) => n.attrs!.Crop);
    expect(stands.sort()).toEqual([...crops].sort());
    expect(nodes.some((n) => n.tags?.includes('CropSell'))).toBe(true);
  });

  test('new tools declare a tier and array items', () => {
    const names = GAMEKIT_TOOLS.map((t) => t.name);
    for (const n of ['populate_world', 'look_at_game', 'backup_game', 'team', 'start_job', 'job_status', 'blender_to_roblox', 'balance_economy', 'publish_checklist']) {
      expect(names).toContain(n);
    }
  });
});

describe('Quality: assets, performance, multiplayer and phone tests', () => {
  test('generated Luau compiles and only uses real Roblox APIs', async () => {
    for (const [label, code] of [['assets', assetsLuau({ ids: [123], scan: true, max: 5 })], ['optimize', optimizeLuau(['all'])]] as const) {
      await expectCompiles(code, label);
      expect({ label, issues: checkRobloxApi(code) }).toEqual({ label, issues: [] });
    }
  });

  test('asset verdicts', () => {
    expect(assetVerdict({ id: 1, kind: 'Audio', status: 'Failure' }).verdict).toBe('broken');
    expect(assetVerdict({ id: 1, kind: 'Audio', status: 'Success', seconds: 0 }).verdict).toBe('broken');
    expect(assetVerdict({ id: 1, kind: 'Audio', status: 'Success', seconds: 12, byRoblox: false, byOwner: false }).verdict).toBe('ok');
    expect(assetVerdict({ id: 1, kind: 'Animation', status: 'Success', byRoblox: false, byOwner: false, creator: 'Someone' }).verdict).toBe('risky');
    expect(assetVerdict({ id: 1, kind: 'Animation', status: 'Success', byRoblox: true }).verdict).toBe('ok');
    expect(assetVerdict({ id: 1, kind: 'Animation', status: 'Success', byOwner: true }).verdict).toBe('ok');
    expect(assetVerdict({ id: 1, infoError: 'HTTP 400', status: 'Failure' }).why).toMatch(/Unknown asset/);
  });

  test('performance findings follow the phone budget', () => {
    const light = optimizeFindings({ stats: { parts: 2000 }, lighting: { technology: 'ShadowMap', globalShadows: true }, streaming: false });
    expect(light).toEqual([]);
    const heavy = optimizeFindings({
      stats: { parts: 30000, unanchored: 2000, smallShadowCasters: 900, shadowLights: 30, particles: 80, particleRate: 4000, humanoids: 10 },
      lighting: { technology: 'Future', globalShadows: true }, streaming: false, perFrame: ['ServerScriptService.Loop'],
    });
    const topics = heavy.map((f) => f.topic);
    for (const t of ['parts', 'streaming', 'physics', 'shadows', 'lights', 'particles', 'technology', 'scripts']) expect(topics).toContain(t);
    expect(heavy.filter((f) => f.level === 'red').length).toBeGreaterThan(0);
  });

  test('check_assets and optimize_game classify what Studio returns', async () => {
    const host = recordingHost({
      runLuau: async (code: string) => {
        if (code.includes('ContentProvider:PreloadAsync')) {
          return { success: true, returnValue: JSON.stringify({ owner: { id: 5, type: 'User' }, checked: 3, results: [
            { id: 11, kind: 'Audio', name: 'Music', status: 'Success', seconds: 90, byOwner: true, uses: ['Workspace.Music'] },
            { id: 12, kind: 'Audio', name: 'Gone', status: 'Failure', uses: ['SoundService.Boom'] },
            { id: 13, kind: 'Animation', name: 'Dance', status: 'Success', creator: 'Other', byOwner: false, byRoblox: false },
          ] }) };
        }
        return { success: true, returnValue: JSON.stringify({ stats: { parts: 12000, shadowLights: 12 }, lighting: { technology: 'Future', globalShadows: true }, streaming: false, fixed: {} }) };
      },
    });
    const kit = new GameKit(host);
    const assets = parse(await kit.call('check_assets', {}));
    expect(assets.verdict).toBe('FIX');
    expect(assets.broken[0].usedIn).toEqual(['SoundService.Boom']);
    expect(assets.risky).toHaveLength(1);
    const perf = parse(await kit.call('optimize_game', {}));
    expect(perf.phone).toMatch(/ORANGE/);
    expect(perf.next).toMatch(/apply/);
  });

  test('phone device picking prefers small phones', () => {
    const devices = [{ DeviceId: 'iPad Pro' }, { DeviceId: 'iPhone 14 Pro Max' }, { DeviceId: 'iPhone SE' }, { DeviceId: 'Samsung Galaxy S9' }];
    expect(pickDevice(devices, 'phone')).toBe('iPhone SE');
    expect(pickDevice(devices, 'tablet')).toBe('iPad Pro');
    expect(pickDevice(devices, 'Samsung Galaxy S9')).toBe('Samsung Galaxy S9');
    expect(pickDevice([{ DeviceId: 'Laptop' }], 'phone')).toBeUndefined();
  });

  test('multiplayer test: start, poll, read the runner report, check each client', async () => {
    const report = {
      serverErrors: [], clientErrors: [], serverWarnings: [], probes: [{ name: 'players joined', ok: true, detail: '2/2' }],
      facts: { characterSpawned: true, dataLoaded: true, aliveAfter3s: true },
      clientFacts: { hudPresent: true, ui: { tooSmall: [], offscreen: [] } },
      clients: { Player1: { playersSeen: 2, ui: { tooSmall: ['GameKitHUD.Close (20x20)'] } }, Player2: { playersSeen: 2 } },
    };
    let polls = 0;
    const started: number[] = [];
    const host = recordingHost({
      getPlaytestOutput: async () => ({ isRunning: false, output: [] }),
      startMultiplayerTest: async (n: number) => { started.push(n); return { success: true }; },
      multiplayerTestState: async () => ({ session: polls++ < 1 ? { phase: 'running' } : { phase: 'completed', result: JSON.stringify(report) } }),
    });
    const result = await runPlaytest(host, { seconds: 8, players: 2 });
    expect(started).toEqual([2]);
    expect(result.verdict).toBe('PASS');
    expect(result.summary).toMatch(/2 players/);
    expect(result.warnings.join(' ')).toMatch(/too small/);
    const installed = host.calls.find((c) => c.includes('__GameKitTestRunner'))!;
    expect(installed).toMatch(/Players/);
  }, 30000);

  test('phone test: switches the simulator, fails on UI problems, restores it', async () => {
    const simulator: string[] = [];
    const host = recordingHost({
      runLuau: async (code: string) => {
        if (code.includes('StudioDeviceSimulatorService')) {
          const payload = code.replace(/\\/g, '');
          const op = /"operation":"(\w+)"/.exec(payload)?.[1] ?? '?';
          simulator.push(op + (payload.includes('"stopSimulation":true') ? ':stop' : ''));
          return { success: true, returnValue: JSON.stringify(op === 'get' ? { isSimulating: false, activeDeviceId: 'default', devices: [{ DeviceId: 'iPhone SE' }] } : { success: true }) };
        }
        return { success: true, returnValue: JSON.stringify({ ok: true, created: 1, replaced: 0, kept: 0, merged: 0, deleted: 0, warnings: [], roots: [] }) };
      },
      getPlaytestOutput: (() => {
        let n = 0;
        return async () => (n++ === 0 ? { isRunning: false } : { isRunning: false, output: [], testResult: JSON.stringify({ probes: [], facts: { characterSpawned: true }, clientFacts: { hudPresent: true, ui: { offscreen: ['Shop.Window'] } } }) });
      })(),
    });
    const result = await runPlaytest(host, { seconds: 8, device: 'phone' });
    expect(result.verdict).toBe('FAIL');
    expect(result.issues.join(' ')).toMatch(/off the screen/);
    expect(result.summary).toMatch(/iPhone SE/);
    expect(simulator[0]).toBe('get');
    expect(simulator[simulator.length - 1]).toBe('set:stop');
  }, 30000);
});
