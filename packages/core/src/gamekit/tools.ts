/**
 * GameKit MCP tools: high-level, low-risk tools that let any AI build a complete Roblox
 * game without writing (much) code. Every Studio change goes through execute_luau, so
 * this layer works with the bundled plugin as-is.
 */

import { SYSTEMS, systemPlacements, getSystem } from './catalog.js';
import { analyseAudit, collectAudit } from './doctor.js';
import { buildEnvironmentLuau, LIGHTING_PRESETS, TERRAIN_MODES, type EnvironmentOptions } from './environment.js';
import { install, runLuauJson, splitPath, type InstallReport, type Placement } from './installer.js';
import { catalogText, guideText, GUIDES } from './knowledge.js';
import { contextFor, lintLuau, type ScriptContext } from './luau-lint.js';
import { checkLuauSyntax } from './luau-syntax.js';
import { runPlaytest, type PlaytestBridge } from './playtest.js';
import { getProfile } from './profiles.js';
import { getTemplate, TEMPLATES } from './templates.js';
import { buildScreenGui, missingActionTargets, type UiSpec } from './ui.js';
import { buildWorld, countParts, OBSTACLES, PIECES, WORLDS, worldPlacement } from './world.js';

export interface GameKitHost extends PlaytestBridge {
  /** True when the Studio plugin polled recently. */
  isStudioConnected(): boolean;
}

export interface ToolDef {
  name: string;
  /** "read" tools are also offered by the read-only inspector edition. */
  category: 'read' | 'write';
  description: string;
  inputSchema: Record<string, unknown>;
}

const obj = (properties: Record<string, unknown>, required: string[] = []) => ({ type: 'object', properties, required });

export const GAMEKIT_TOOLS: ToolDef[] = [
  {
    name: 'roblox_start_here',
    category: 'read',
    description: 'START HERE before anything else. Checks the Studio connection, shows what is already in the game, and gives the step-by-step plan to build a complete game with this MCP (templates, systems, testing).',
    inputSchema: obj({}),
  },
  {
    name: 'roblox_guide',
    category: 'read',
    description: `Read a short guide. Topics: ${Object.keys(GUIDES).join(', ')}, catalog, or any system/template id (e.g. "shop", "obby"). Read "workflow" first, "errors" when something breaks.`,
    inputSchema: obj({ topic: { type: 'string', description: 'Guide topic, e.g. "workflow", "design", "luau", "client-server", "ui", "shop"' } }, ['topic']),
  },
  {
    name: 'gamekit_catalog',
    category: 'read',
    description: 'List everything that can be installed without code: complete game templates, plug-and-play systems, world pieces and lighting presets.',
    inputSchema: obj({}),
  },
  {
    name: 'create_game',
    category: 'write',
    description: `Build a COMPLETE playable game in one call: scripts (server+client), config, world, UI and lighting. Templates: ${TEMPLATES.map((t) => `${t.id} (${t.genre})`).join(', ')}. By default removes previous GameKit content first (Ctrl+Z in Studio undoes everything). Then run test_game.`,
    inputSchema: obj({
      template: { type: 'string', enum: TEMPLATES.map((t) => t.id), description: 'Which game to build' },
      options: {
        type: 'object',
        description: 'Optional: title (text on signs), theme (rainbow|candy|neon|nature|space|lava|ice), difficulty (easy|medium|hard), stages (obby), plots (tycoon), zones (simulator), mazeSize & keys (horror_escape), seed, lighting (preset name), obstacles (obby: list of obstacle types)',
        properties: {
          title: { type: 'string' }, theme: { type: 'string' }, difficulty: { type: 'string', enum: ['easy', 'medium', 'hard'] },
          stages: { type: 'number' }, plots: { type: 'number' }, zones: { type: 'number' }, mazeSize: { type: 'number' },
          keys: { type: 'number' }, seed: { type: 'number' }, lighting: { type: 'string' },
          obstacles: { type: 'array', items: { type: 'string', enum: [...OBSTACLES] } },
        },
      },
      config: { type: 'object', description: 'Optional config overrides per module, e.g. {"Shop": {"Currency": "Gems"}, "Checkpoints": {"FinishRewards": {"Wins": 1, "Coins": 100}}}' },
      fresh: { type: 'boolean', description: 'Remove previous GameKit world/scripts first (default true)' },
    }, ['template']),
  },
  {
    name: 'add_system',
    category: 'write',
    description: `Install one ready-made, tested game system (plus what it needs). Systems: ${SYSTEMS.filter((s) => s.id !== 'core').map((s) => s.id).join(', ')}. Pass "config" to change its settings (existing settings are kept otherwise). Read roblox_guide <system> for its options.`,
    inputSchema: obj({
      system: { type: 'string', enum: SYSTEMS.map((s) => s.id) },
      config: { type: 'object', description: 'Overrides for the system config module(s), e.g. {"Shop": {"Items": [...]}} or directly {"Currency": "Gems"} for single-config systems' },
      resetConfig: { type: 'boolean', description: 'Rewrite config modules with defaults (+ your overrides)' },
    }, ['system']),
  },
  {
    name: 'build_world',
    category: 'write',
    description: `Build gameplay-ready geometry in Workspace/GameKit (anchored, tagged for the systems). Worlds: ${WORLDS.join(', ')}. Pieces: ${PIECES.join(', ')}. Same name = replaced. Positions are [x, y, z] in studs, y is up.`,
    inputSchema: obj({
      kind: { type: 'string', description: `A world (${WORLDS.join(', ')}) or a piece (${PIECES.join(', ')})` },
      name: { type: 'string', description: 'Name of the created model/part (default: kind). Reuse a name to replace it.' },
      options: {
        type: 'object',
        description: 'position [x,y,z]; obby_course: stages, difficulty, theme, coins, obstacles, title, seed; lobby: title, size, shop, leaderboardStat; arena: size, theme, spawns; maze: width, height, keys, ceiling, monster, seed; tycoon_plots: count; simulator_world: zones, basePrice; decor_scatter: radius, count, clear. Pieces: color, size [x,y,z], stage (checkpoint), power (jump_pad), speed, offset [x,y,z] & duration (moving_platform), stat & amount (coin), enemy & maxAlive (enemy_spawner), zone & price (zone_gate), target (teleporter), yaw (degrees), text...',
      },
    }, ['kind']),
  },
  {
    name: 'build_ui',
    category: 'write',
    description: 'Create a screen UI from JSON (no Luau): frames, labels, buttons, images, bars with responsive sizes and nice defaults. Behaviour without code: bind "stat:Coins" (live text), bar "stat:Power/stat:Capacity", showIf, action "toggle:WindowName" | "open:X" | "close:X" | "remote:Event". See roblox_guide ui.',
    inputSchema: obj({
      spec: {
        type: 'object',
        description: '{ name: "MyUI", children: [ { type: "frame"|"label"|"button"|"image"|"imagebutton"|"textbox"|"scroll"|"bar", name, text, position: "center"|"top"|"top-left"|..., size: [w,h] (<=1 = screen fraction, >1 = pixels), color, textColor, corner, stroke, padding, layout: "vertical"|"horizontal"|"grid", gap, bind, format, bar, showIf, action, visible, children: [...] } ] }',
        properties: { name: { type: 'string' }, children: { type: 'array', items: { type: 'object' } } },
        required: ['name', 'children'],
      },
    }, ['spec']),
  },
  {
    name: 'set_environment',
    category: 'write',
    description: `Change the mood: lighting preset (${Object.keys(LIGHTING_PRESETS).join(', ')}), time of day, terrain (${TERRAIN_MODES.join(', ')}), remove the default Baseplate.`,
    inputSchema: obj({
      preset: { type: 'string', enum: Object.keys(LIGHTING_PRESETS) },
      clockTime: { type: 'number', description: '0-24' },
      terrain: { type: 'string', enum: [...TERRAIN_MODES] },
      terrainSize: { type: 'number', description: 'Studs (64-2048, default 512)' },
      terrainCenter: { type: 'array', items: { type: 'number' }, description: '[x, y, z] center of the terrain' },
      hillHeight: { type: 'number' },
      water: { type: 'boolean' },
      removeBaseplate: { type: 'boolean' },
      seed: { type: 'number' },
    }),
  },
  {
    name: 'write_script',
    category: 'write',
    description: 'The SAFE way to create or replace a script. Checks the Luau with the real compiler and a beginner-mistake linter BEFORE writing; refuses broken code and explains how to fix it. kind: server (Script), client (LocalScript) or module (ModuleScript); default from the location.',
    inputSchema: obj({
      path: { type: 'string', description: 'Full path incl. script name, e.g. "ServerScriptService/CoinGiver" or "StarterPlayer/StarterPlayerScripts/Intro"' },
      source: { type: 'string', description: 'Complete Luau source' },
      kind: { type: 'string', enum: ['server', 'client', 'module'] },
      force: { type: 'boolean', description: 'Write even if the linter reports errors (never skips syntax errors)' },
    }, ['path', 'source']),
  },
  {
    name: 'check_luau',
    category: 'read',
    description: 'Check Luau code WITHOUT writing it: real compiler syntax check + beginner-mistake linter (client/server confusion, infinite loops, deprecated APIs, trusting the client...). Works even when Studio is closed.',
    inputSchema: obj({
      source: { type: 'string' },
      kind: { type: 'string', enum: ['server', 'client', 'module'], description: 'Where the code runs (improves the checks)' },
    }, ['source']),
  },
  {
    name: 'check_game',
    category: 'read',
    description: 'Audit the whole place without playing: syntax errors in every script, beginner mistakes, scripts that can never run where they are, missing spawn, loose unanchored parts, GameKit pieces without their system. Returns problems with fixes.',
    inputSchema: obj({ includeGameKit: { type: 'boolean', description: 'Also lint GameKit\'s own scripts (default false)' } }),
  },
  {
    name: 'test_game',
    category: 'write',
    description: 'Automatic playtest: starts Play, plays through the game (checkpoints, coins, kill parts), records server AND client errors with script/line and plain-English fixes, then stops by itself and cleans up. Run it after every change until it says PASS.',
    inputSchema: obj({
      seconds: { type: 'number', description: 'How long to play (8-120, default 20)' },
      autoplay: { type: 'boolean', description: 'Walk through checkpoints/coins automatically (default true)' },
    }),
  },
];

export const GAMEKIT_TOOL_NAMES = new Set(GAMEKIT_TOOLS.map((t) => t.name));

function text(value: unknown) {
  return { content: [{ type: 'text', text: typeof value === 'string' ? value : JSON.stringify(value, null, 2) }] };
}

const NOT_CONNECTED = {
  connected: false,
  problem: 'Roblox Studio is not connected to this MCP server.',
  fix: [
    '1. Open Roblox Studio with a place (File > New > Baseplate works).',
    '2. Install the plugin once: run "npm run install-plugin" in the MCP folder (or copy studio-plugin/MCPPlugin.rbxmx to %LOCALAPPDATA%\\Roblox\\Plugins on Windows, ~/Documents/Roblox/Plugins on macOS), then restart Studio.',
    '3. Game Settings > Security > Allow HTTP Requests = ON.',
    '4. Plugins tab > MCP Server > Connect.',
    'Meanwhile you can use roblox_guide, gamekit_catalog and check_luau (they work offline).',
  ],
};

function kindToClass(kind: string | undefined): string | undefined {
  return kind === 'server' ? 'Script' : kind === 'client' ? 'LocalScript' : kind === 'module' ? 'ModuleScript' : undefined;
}

function inferKind(segments: string[]): 'server' | 'client' | 'module' {
  const joined = segments.join('/');
  if (/StarterPlayerScripts|StarterCharacterScripts|StarterGui|StarterPack|ReplicatedFirst/.test(joined)) return 'client';
  if (/^(ReplicatedStorage|ServerStorage)/.test(joined)) return 'module';
  return 'server';
}

function summarizeInstall(report: InstallReport) {
  return {
    ok: report.ok,
    error: report.error,
    created: report.created,
    replaced: report.replaced,
    keptExisting: report.kept,
    updated: report.merged,
    deleted: report.deleted,
    warnings: report.warnings.slice(0, 15),
  };
}

export class GameKit {
  constructor(private host: GameKitHost) {}

  private requireStudio() {
    if (!this.host.isStudioConnected()) {
      const error = new Error(`${NOT_CONNECTED.problem} ${NOT_CONNECTED.fix.join(' ')}`);
      throw error;
    }
  }

  /** Like call(), but failures come back as an error result the model can read. */
  async run(name: string, args: Record<string, any> = {}) {
    try {
      return await this.call(name, args);
    } catch (error) {
      return { content: [{ type: 'text', text: `Error: ${error instanceof Error ? error.message : String(error)}` }], isError: true };
    }
  }

  async call(name: string, args: Record<string, any> = {}) {
    switch (name) {
      case 'roblox_start_here': return this.startHere();
      case 'roblox_guide': return text(guideText(String(args.topic ?? 'workflow')));
      case 'gamekit_catalog': return text(catalogText());
      case 'create_game': return this.createGame(args);
      case 'add_system': return this.addSystem(args);
      case 'build_world': return this.buildWorld(args);
      case 'build_ui': return this.buildUi(args);
      case 'set_environment': return this.setEnvironment(args as EnvironmentOptions);
      case 'write_script': return this.writeScript(args);
      case 'check_luau': return this.checkLuau(args);
      case 'check_game': return this.checkGame(args);
      case 'test_game': return this.testGame(args);
      default: throw new Error(`Unknown GameKit tool: ${name}`);
    }
  }

  async startHere() {
    const plan = [
      'Pick a template for the idea and call create_game (obby, tycoon, simulator, arena, survival, horror_escape).',
      'Call test_game; fix every error it reports; repeat until PASS.',
      'Customise with add_system {config}, build_world, build_ui, set_environment (no code).',
      'Write custom code only with write_script (it validates Luau first).',
      'Finish with check_game, then polish using roblox_guide design.',
    ];
    const base = { profile: getProfile(), plan, guides: 'roblox_guide workflow | design | luau | client-server | ui | errors | publishing' };
    if (!this.host.isStudioConnected()) return text({ ...base, studio: NOT_CONNECTED });
    try {
      const state = await runLuauJson(this.host, `
local HttpService = game:GetService("HttpService")
local kit = game:GetService("ReplicatedStorage"):FindFirstChild("GameKit")
local serverKit = game:GetService("ServerScriptService"):FindFirstChild("GameKit")
local world = workspace:FindFirstChild("GameKit")
local installed, pieces, scripts, parts = {}, {}, 0, 0
if serverKit then for _, c in serverKit:GetChildren() do table.insert(installed, c.Name) end end
if world then for _, c in world:GetChildren() do table.insert(pieces, c.Name) end end
for _, serviceName in { "Workspace", "ReplicatedStorage", "ReplicatedFirst", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer" } do
  local ok, service = pcall(game.GetService, game, serviceName)
  if ok and service then
    for _, d in service:GetDescendants() do if d:IsA("LuaSourceContainer") then scripts += 1 end end
  end
end
for _, d in workspace:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
return HttpService:JSONEncode({ place = game.Name, placeId = game.PlaceId, gameKit = kit ~= nil,
  installedSystems = installed, worldPieces = pieces, scripts = scripts, parts = parts,
  httpEnabled = HttpService.HttpEnabled })`, 'Studio state');
      const next = state.gameKit
        ? 'GameKit is already installed: run test_game, then keep improving (add_system / build_world / build_ui).'
        : 'Empty or custom place: call create_game with the template closest to the idea.';
      return text({ ...base, studio: { connected: true, ...state }, next });
    } catch (err) {
      return text({ ...base, studio: { connected: true, error: err instanceof Error ? err.message : String(err) } });
    }
  }

  async createGame(args: Record<string, any>) {
    this.requireStudio();
    const template = getTemplate(String(args.template));
    const plan = template.plan(args.options ?? {});
    const config: Record<string, Record<string, unknown>> = { ...plan.config };
    for (const [k, v] of Object.entries(args.config ?? {})) {
      config[k] = { ...(config[k] ?? {}), ...(v as Record<string, unknown>) };
    }
    const { placements, systems } = systemPlacements(plan.systems, { config, resetConfig: true });
    const fresh = args.fresh !== false;
    const report = await install(this.host, {
      label: `GameKit: create ${template.id}`,
      deletes: fresh
        ? ['Workspace/GameKit', 'ServerScriptService/GameKit', 'StarterPlayer/StarterPlayerScripts/GameKit', 'ReplicatedStorage/GameKit']
        : [],
      items: [...placements, ...plan.world],
    });
    let environment: any = null;
    try {
      environment = await runLuauJson(this.host, buildEnvironmentLuau(plan.environment), 'Environment');
    } catch (err) {
      environment = { ok: false, error: err instanceof Error ? err.message : String(err) };
    }
    const parts = plan.world.reduce((n, p) => n + countParts(p.node), 0);
    return text({
      ok: report.ok,
      summary: `${template.title} created: ${systems.length} systems, ${parts} world parts, lighting "${plan.environment.preset ?? 'unchanged'}".`,
      systems,
      install: summarizeInstall(report),
      environment,
      whereThingsAre: {
        scripts: 'ServerScriptService/GameKit (server) and StarterPlayer/StarterPlayerScripts/GameKit (client)',
        settings: 'ReplicatedStorage/GameKit/Config/<System> (edit numbers/texts here)',
        world: 'Workspace/GameKit',
      },
      next: ['Call test_game now.', ...plan.nextSteps],
    });
  }

  async addSystem(args: Record<string, any>) {
    this.requireStudio();
    const system = getSystem(String(args.system));
    let config = args.config as Record<string, any> | undefined;
    // Accept {"Currency": "Gems"} directly for systems with a single config module.
    if (config && system.configs.length === 1 && !(system.configs[0].name in config)) {
      config = { [system.configs[0].name]: config };
    }
    const { placements, systems } = systemPlacements([system.id], { config, resetConfig: !!args.resetConfig });
    const report = await install(this.host, { label: `GameKit: add ${system.id}`, items: placements });
    return text({
      ok: report.ok,
      summary: `Installed ${system.title} (with: ${systems.join(', ')}).`,
      install: summarizeInstall(report),
      tags: system.tags ?? {},
      usage: system.usage,
      configNote: config ? 'Config modules updated with your values.' : 'Existing config modules were kept; pass "config" to change settings.',
      next: system.tags ? `Add its pieces with build_world (${Object.keys(system.tags).join(', ')}), then test_game.` : 'Run test_game.',
    });
  }

  async buildWorld(args: Record<string, any>) {
    this.requireStudio();
    const kind = String(args.kind);
    const node = buildWorld(kind, args.options ?? {});
    const placement = worldPlacement(node, args.name);
    const report = await install(this.host, { label: `GameKit: build ${kind}`, items: [placement] });
    const neededSystems = new Set<string>();
    const tags = new Set<string>();
    const walk = (n: typeof node) => {
      (n.tags ?? []).forEach((t) => tags.add(t));
      (n.children ?? []).forEach(walk);
    };
    walk(node);
    for (const s of SYSTEMS) {
      if (s.tags && Object.keys(s.tags).some((t) => tags.has(t))) neededSystems.add(s.id);
    }
    return text({
      ok: report.ok,
      summary: `Built ${kind} as Workspace/GameKit/${placement.node.name} (${countParts(node)} parts).`,
      install: summarizeInstall(report),
      tagsUsed: [...tags],
      requiredSystems: [...neededSystems],
      next: neededSystems.size ? `Make sure these systems are installed: ${[...neededSystems].join(', ')} (add_system), then test_game.` : 'Run test_game to try it.',
    });
  }

  async buildUi(args: Record<string, any>) {
    this.requireStudio();
    const spec = args.spec as UiSpec;
    if (!spec || !spec.name || !Array.isArray(spec.children)) throw new Error('spec needs { name, children: [...] } (see roblox_guide ui)');
    const gui = buildScreenGui(spec);
    // The binder makes bind/action attributes work; install it quietly if missing.
    const binder: Placement[] = systemPlacements([]).placements.map((p) => ({ ...p, mode: 'keep' as const }));
    const report = await install(this.host, {
      label: `GameKit: UI ${spec.name}`,
      items: [...binder, { parent: ['StarterGui'], mode: 'replace', node: gui }],
    });
    const missing = missingActionTargets(spec);
    return text({
      ok: report.ok,
      summary: `Created StarterGui/${spec.name}. It appears when you press Play.`,
      install: summarizeInstall(report),
      warnings: missing.length ? [`These action targets do not exist in the spec: ${missing.join(', ')}`] : [],
      next: 'Run test_game (client errors are reported) or capture a screenshot in Play mode.',
    });
  }

  async setEnvironment(args: EnvironmentOptions) {
    this.requireStudio();
    const result = await runLuauJson(this.host, buildEnvironmentLuau(args), 'Environment');
    return text({ ...result, next: 'Look at the viewport; try another preset if the mood is not right.' });
  }

  private async validate(source: string, context: ScriptContext) {
    const syntax = await checkLuauSyntax(source, 'script');
    const lint = syntax.ok ? lintLuau(source, context) : [];
    return {
      syntax,
      lint,
      errors: [
        ...syntax.errors.map((e) => ({ line: e.line, problem: `Syntax: ${e.message}`, fix: e.hint })),
        ...lint.filter((l) => l.severity === 'error').map((l) => ({ line: l.line, problem: l.message, fix: l.fix, rule: l.rule })),
      ],
      warnings: lint.filter((l) => l.severity !== 'error').map((l) => ({ line: l.line, problem: l.message, fix: l.fix, rule: l.rule })),
    };
  }

  async checkLuau(args: Record<string, any>) {
    const context: ScriptContext = args.kind === 'server' ? 'server' : args.kind === 'client' ? 'client' : args.kind === 'module' ? 'module' : 'unknown';
    const result = await this.validate(String(args.source ?? ''), context);
    return text({
      ok: result.errors.length === 0,
      syntaxChecker: result.syntax.available ? 'luau compiler (wasm)' : 'unavailable',
      errors: result.errors,
      warnings: result.warnings,
    });
  }

  async writeScript(args: Record<string, any>) {
    const segments = splitPath(String(args.path ?? ''));
    if (segments.length < 2) throw new Error('path must include the container and the script name, e.g. "ServerScriptService/MyScript"');
    const kind = (args.kind as 'server' | 'client' | 'module' | undefined) ?? inferKind(segments);
    const className = kindToClass(kind) ?? 'Script';
    const source = String(args.source ?? '');
    const result = await this.validate(source, contextFor(className, segments.join('.')));
    const syntaxFailed = !result.syntax.ok;
    if (syntaxFailed || (result.errors.length && !args.force)) {
      return text({
        written: false,
        reason: syntaxFailed ? 'The code has syntax errors (it would not run). Fix them and call write_script again.' : 'The linter found mistakes that break the game. Fix them (or pass force: true if you are sure).',
        errors: result.errors,
        warnings: result.warnings,
      });
    }
    this.requireStudio();
    const name = segments[segments.length - 1];
    const report = await install(this.host, {
      label: `GameKit: write ${segments.join('/')}`,
      items: [{ parent: segments.slice(0, -1), mode: 'merge', node: { name, className, source } }],
    });
    return text({
      written: report.ok,
      path: segments.join('/'),
      className,
      install: summarizeInstall(report),
      warnings: result.warnings,
      next: 'Run test_game to see it working.',
    });
  }

  async checkGame(args: Record<string, any>) {
    this.requireStudio();
    const audit = await collectAudit(this.host);
    const { findings, summary } = await analyseAudit(audit, { includeGameKit: !!args.includeGameKit });
    return text({
      ...summary,
      findings: findings.slice(0, 60),
      moreFindings: Math.max(0, findings.length - 60),
      next: summary.errors ? 'Fix the errors (top of the list), then check_game again.' : 'Run test_game for a real playtest.',
    });
  }

  async testGame(args: Record<string, any>) {
    this.requireStudio();
    const result = await runPlaytest(this.host, { seconds: args.seconds, autoplay: args.autoplay });
    return text({
      ...result,
      next: result.verdict === 'PASS'
        ? 'Great. Improve the game (roblox_guide design) and test again after each change.'
        : 'Fix the first error (open the script with get_script_source, fix with write_script or edit_script_lines), then run test_game again.',
    });
  }
}
