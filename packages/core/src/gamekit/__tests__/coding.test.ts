import { autofixLuau } from '../autofix.js';
import { checkRobloxApi, suggest } from '../api-check.js';
import { applyEdit, outlineScript, prepareLuau } from '../code.js';
import { RECIPES } from '../recipes.js';
import { LUAU_SOURCES } from '../generated/luau-sources.js';
import { checkLuauSyntax } from '../luau-syntax.js';
import { listingView } from '../mcp-extras.js';
import { handleMetaTool } from '../mcp-extras.js';
import { prune, toJson } from '../result.js';
import { downscaleRgba } from '../../png-encoder.js';
import { GameKit, type GameKitHost } from '../tools.js';
import { analyseAudit } from '../doctor.js';

const parse = (result: any) => JSON.parse(result.content[0].text);

describe('Autofix', () => {
  test('turns JavaScript/Python habits into Luau that compiles', async () => {
    const js = [
      'let coins = 0',
      '// give coins',
      'if (coins != 5 && !done || x === null) {',
      '}',
    ].join('\n');
    const lua = [
      'let coins = 0',
      '// add coins',
      'local done = false',
      'local items = {}',
      'if coins != 5 && !done then',
      '\tconsole.log("Coins: " + coins, items.length)',
      '\twait(1)',
      'end',
      'local s = `total ${coins}`',
      'i = 0',
      'i++',
      'x = Math.floor(2.5) + None',
    ].join('\n');
    const fixed = await autofixLuau(lua);
    expect(fixed.source).toContain('local coins = 0');
    expect(fixed.source).toContain('-- add coins');
    expect(fixed.source).toContain('if coins ~= 5 and not done then');
    expect(fixed.source).toContain('print("Coins: " .. coins, #items)');
    expect(fixed.source).toContain('task.wait(1)');
    expect(fixed.source).toContain('`total {coins}`');
    expect(fixed.source).toContain('i += 1');
    expect(fixed.source).toContain('math.floor(2.5) + nil');
    expect(fixed.fixes.length).toBeGreaterThan(5);
    expect((await checkLuauSyntax(fixed.source)).ok).toBe(true);
    expect(js).toBeTruthy();
  });

  test('never touches strings, comments, floor division or user functions', async () => {
    const src = [
      'local text = "a != b && c // d"',
      '-- wait(1) in a comment',
      'local half = 10 // 3',
      'local function wait(n) return n end',
      'print(text, half, wait(2))',
    ].join('\n');
    const fixed = await autofixLuau(src);
    expect(fixed.source).toBe(src);
    expect(fixed.fixes).toEqual([]);
  });

  test('"else if" becomes elseif only when the code does not compile', async () => {
    const broken = 'local a = 1\nif a == 1 then\n\tprint(1)\nelse if a == 2 then\n\tprint(2)\nend';
    const fixed = await autofixLuau(broken);
    expect(fixed.source).toContain('elseif a == 2');
    expect((await checkLuauSyntax(fixed.source)).ok).toBe(true);
    const valid = 'local a = 1\nif a == 1 then\n\tprint(1)\nelse if a == 2 then\n\tprint(2)\nend\nend';
    expect((await autofixLuau(valid)).source).toBe(valid);
  });
});

describe('Roblox API check', () => {
  const rules = (src: string) => checkRobloxApi(src).map((i) => `${i.rule}:${i.message}`);

  test('catches invented names with suggestions', () => {
    const found = rules([
      'local Players = game:GetService("Player")',
      'local p = Instance.new("Brick")',
      'local q = Instance.new("Part")',
      'q.Colour = Color3.fromRgb(1, 2, 3)',
      'q.Material = Enum.Material.Wooden',
      'local h = workspace:FindFirstChildOfClass("Humanoid")',
      'h.Walkspeed = 30',
      'h:TakeDmg(5)',
      'local v = Vector3.New(1, 2, 3)',
      'q:remove()',
    ].join('\n')).join('\n');
    expect(found).toMatch(/"Player" is not a Roblox service. Did you mean "Players"/);
    expect(found).toMatch(/"Brick" is not a Roblox class. Did you mean "Part"/);
    expect(found).toMatch(/Color3.fromRgb does not exist. Did you mean "Color3.fromRGB"/);
    expect(found).toMatch(/Enum.Material.Wooden does not exist. Did you mean "Enum.Material.Wood"/);
    expect(found).toMatch(/no property "Colour".*"Color"/);
    expect(found).toMatch(/no property "Walkspeed".*"WalkSpeed"/);
    expect(found).toMatch(/no method "TakeDmg".*"TakeDamage"/);
    expect(found).toMatch(/Vector3.New does not exist/);
    expect(found).toMatch(/api-deprecated/);
  });

  test('no false alarms on valid code, children, loops and strings', () => {
    const ok = checkRobloxApi([
      'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
      'local remotes = ReplicatedStorage.Remotes',
      'local part = Instance.new("Part")',
      'part.Size = Vector3.new(4, 1, 4)',
      'part.Anchored = true',
      'part:SetAttribute("Coins", 5)',
      'for _, part in workspace:GetChildren() do print(part.Name) end',
      'print("Instance.new(\'Nope\')", Enum.KeyCode.E, task.wait(), CFrame.lookAt(Vector3.zero, Vector3.one), remotes)',
    ].join('\n'));
    expect(ok).toEqual([]);
  });

  test('the whole GameKit library is clean', () => {
    for (const [file, source] of Object.entries(LUAU_SOURCES)) {
      expect({ file, issues: checkRobloxApi(source) }).toEqual({ file, issues: [] });
    }
  });

  test('suggestions', () => {
    expect(suggest('Workpsace', ['Workspace', 'Players'])).toBe('Workspace');
    expect(suggest('Zzzz', ['Workspace'])).toBeUndefined();
  });
});

describe('Code recipes', () => {
  test('every recipe (example + variants) compiles and passes the linter and API check', async () => {
    for (const recipe of RECIPES) {
      for (const params of [recipe.example, ...(recipe.variants ?? [])]) {
        for (const file of recipe.build(params as any).files) {
          const prepared = await prepareLuau(file.source, file.side === 'server' ? 'server' : 'client', false);
          expect({ recipe: recipe.id, params, problems: [...prepared.validation.errors, ...prepared.validation.warnings] })
            .toEqual({ recipe: recipe.id, params, problems: [] });
        }
      }
    }
  }, 60000);

  test('missing required params are explained', () => {
    expect(() => RECIPES.find((r) => r.id === 'touch_reward')!.build({})).toThrow(/target/);
    expect(() => RECIPES.find((r) => r.id === 'badge_award')!.build({})).toThrow(/badgeId/);
  });
});

describe('edit_script / read_script / code_outline', () => {
  const script = [
    'local Players = game:GetService("Players")',
    '',
    'local function giveCoins(player)',
    '\tplayer:SetAttribute("Coins", 10)',
    'end',
    '',
    'Players.PlayerAdded:Connect(giveCoins)',
  ].join('\n');

  test('applyEdit: exact, indentation-tolerant, ambiguous, not found', () => {
    const exact = applyEdit(script, { find: '"Coins", 10', replace: '"Coins", 50' });
    expect('source' in exact && exact.source).toContain('"Coins", 50');
    const loose = applyEdit(script, { find: 'player:SetAttribute("Coins", 10)', replace: 'player:SetAttribute("Coins", 20)\nprint("given")' });
    expect('source' in loose && loose.source).toContain('\tprint("given")');
    const twice = applyEdit('a = 1\na = 1', { find: 'a = 1', replace: 'a = 2' });
    expect('error' in twice && twice.error).toMatch(/2 times/);
    const missing = applyEdit(script, { find: 'player:SetAttribute("Gems", 10)', replace: '' });
    expect('error' in missing && missing.error).toMatch(/Closest lines: 4\|/);
  });

  function scriptHost(source: string) {
    const calls: string[] = [];
    const host: GameKitHost & { calls: string[] } = {
      calls,
      isStudioConnected: () => true,
      runLuau: async (code: string) => {
        calls.push(code);
        if (code.includes('local PAYLOAD')) return { success: true, returnValue: JSON.stringify({ ok: true, created: 0, replaced: 0, kept: 0, merged: 1, deleted: 0, warnings: [], roots: [] }) };
        if (code.includes('truncatedScripts')) return { success: true, returnValue: JSON.stringify({ scripts: [{ path: 'ServerScriptService.Coins', className: 'Script', source }], facts: {}, tags: {}, loose: [], checkpointStages: [], truncatedScripts: 0 }) };
        if (code.includes('LuaSourceContainer') && code.includes('runContext')) return { success: true, returnValue: JSON.stringify({ ok: true, className: 'Script', source, path: 'ServerScriptService.Coins' }) };
        return { success: true, returnValue: JSON.stringify({ scripts: [{ path: 'ServerScriptService.Coins', className: 'Script', source }], facts: {}, tags: {}, loose: [], checkpointStages: [], truncatedScripts: 0 }) };
      },
      startPlaytest: async () => ({}),
      stopPlaytest: async () => ({}),
      getPlaytestOutput: async () => ({}),
    };
    return host;
  }

  test('edit_script validates before writing and only sends the change', async () => {
    const host = scriptHost(script);
    const kit = new GameKit(host);
    const ok = parse(await kit.call('edit_script', { path: 'ServerScriptService/Coins', find: '"Coins", 10', replace: '"Coins", 25' }));
    expect(ok.written).toBe(true);
    expect(ok.preview).toContain('25');
    const broken = parse(await kit.call('edit_script', { path: 'ServerScriptService/Coins', find: 'end', replace: '', all: true }));
    expect(broken.written).toBe(false);
    const hallucinated = parse(await kit.call('edit_script', { path: 'ServerScriptService/Coins', find: 'Players.PlayerAdded', replace: 'Players:OnPlayerJoin' }));
    expect(hallucinated.written).toBe(false);
    const autofixed = parse(await kit.call('edit_script', { path: 'ServerScriptService/Coins', find: 'end\n\nPlayers', replace: 'end\n// hook\nPlayers' }));
    expect(autofixed.written).toBe(true);
    expect(autofixed.autofixed.join(' ')).toMatch(/comments/);
  });

  test('read_script numbers lines and can show only matches', async () => {
    const kit = new GameKit(scriptHost(script));
    const all = (await kit.call('read_script', { path: 'ServerScriptService/Coins' })).content[0].text as string;
    expect(all).toContain('4| \tplayer:SetAttribute("Coins", 10)');
    const found = (await kit.call('read_script', { path: 'ServerScriptService/Coins', find: 'playeradded' })).content[0].text as string;
    expect(found).toContain('7| Players.PlayerAdded');
    expect(found).not.toContain('1| local Players');
  });

  test('code_outline summarises scripts in one line', async () => {
    const line = outlineScript('ServerScriptService/Shop', 'Script', '-- Sells swords\nlocal Net = require(x.Net)\nNet.on("Buy", function() end)\nlocal function price() end\nUtil.onTag("ShopStand", print)');
    expect(line).toMatch(/"Sells swords".*fn: price.*remotes: Buy.*tags: ShopStand.*requires: Net/);
    const text = (await new GameKit(scriptHost(script)).call('code_outline', {})).content[0].text as string;
    expect(text).toContain('ServerScriptService/Coins (Script, 7 lines)');
  });
});

describe('Errors come with their code', () => {
  test('check_game findings show the offending lines', async () => {
    const source = 'local Players = game:GetService("Players")\nlocal h = workspace:FindFirstChildOfClass("Humanoid")\nh.Walkspeed = 30';
    const { findings } = await analyseAudit({
      scripts: [{ path: 'ServerScriptService.Speed', className: 'Script', enabled: true, length: source.length, source }],
      facts: { spawnLocations: 1 }, tags: {}, loose: [], checkpointStages: [], truncatedScripts: 0,
    } as any);
    const error = findings.find((f) => f.problem.includes('Walkspeed'))!;
    expect(error.code).toContain('3| h.Walkspeed = 30');
    expect(error.fix).toBe('h.WalkSpeed');
  });
});

describe('Token savings', () => {
  test('replies are compact and drop empty fields', () => {
    expect(prune({ a: 1, b: undefined, c: null, d: [], e: {}, f: { g: [] }, h: 0, i: false })).toEqual({ a: 1, h: 0, i: false });
    expect(toJson({ a: [1, 2], b: 'x' })).toBe('{"a":[1,2],"b":"x"}');
  });

  test('tool list: base tools get one sentence, internal fields are dropped', () => {
    const view = listingView({
      name: 'terrain_fill_block',
      description: 'Fill a block with terrain. It supports many materials and a lot of options that are explained at length here.',
      inputSchema: { type: 'object', properties: { material: { type: 'string', description: 'Material name. Long explanation follows here.' } }, additionalProperties: false },
      category: 'write',
    } as any);
    expect(view.description).toBe('Fill a block with terrain.');
    expect((view.inputSchema as any).properties.material.description).toBe('Material name.');
    expect((view as any).category).toBeUndefined();
    expect((view.inputSchema as any).additionalProperties).toBeUndefined();
  });

  test('find_tools returns an index for many matches, full schemas for an exact name', async () => {
    const tools = Array.from({ length: 12 }, (_, i) => ({ name: `terrain_tool_${i}`, description: `Terrain tool ${i}. Details.`, inputSchema: { type: 'object', properties: { a: { type: 'number' } }, required: ['a'] } }));
    const ctx = { allTools: () => tools, dispatch: async () => ({}), listedCount: () => 0 };
    const index = parse(await handleMetaTool('find_tools', { query: 'terrain' }, ctx));
    expect(index.tools[0]).toEqual({ name: 'terrain_tool_0', about: 'Terrain tool 0.', params: 'a*' });
    const exact = parse(await handleMetaTool('find_tools', { query: 'terrain_tool_3' }, ctx));
    expect(exact.tools[0].inputSchema).toBeDefined();
  });

  test('screenshots are downscaled (fewer image tokens)', () => {
    const rgba = Buffer.alloc(1920 * 1080 * 4, 128);
    const small = downscaleRgba(rgba, 1920, 1080, 640);
    expect([small.width, small.height]).toEqual([640, 360]);
    expect(small.data.length).toBe(640 * 360 * 4);
    expect(small.data[0]).toBe(128);
    expect(downscaleRgba(rgba, 1920, 1080, 0).width).toBe(1920);
  });
});
