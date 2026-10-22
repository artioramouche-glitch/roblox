/**
 * GameKit MCP tools: high-level, low-risk tools that let any AI build a complete Roblox
 * game without writing (much) code. Every Studio change goes through execute_luau, so
 * this layer works with the bundled plugin as-is.
 */

import { SYSTEMS, systemPlacements, getSystem } from './catalog.js';
import { analyseAudit, codeAt, collectAudit } from './doctor.js';
import { buildEnvironmentLuau, FEATURE_TYPES, LIGHTING_PRESETS, TERRAIN_MODES, type EnvironmentOptions } from './environment.js';
import { install, runLuauJson, splitPath, type InstallReport, type Placement } from './installer.js';
import { catalogText, guideText, GUIDES } from './knowledge.js';
import { contextFor, type ScriptContext } from './luau-lint.js';
import { runPlaytest, type PlaytestBridge } from './playtest.js';
import { getProfile } from './profiles.js';
import { getTemplate, TEMPLATES } from './templates.js';
import { buildScreenGui, missingActionTargets, type UiSpec } from './ui.js';
import { buildWorld, countParts, PIECES, WORLDS, worldPlacement } from './world.js';
import { BACKUP_TOOLS, handleBackup, placeHasContent, saveBackup } from './backup.js';
import { BLENDER_TOOLS, BlenderTools } from './blender.js';
import { SOUND_TOOLS, SoundTools } from './sound.js';
import { ECONOMY_TOOLS, handleEconomy } from './economy.js';
import { handleJobTool, JOB_TOOLS, JobRegistry } from './jobs.js';
import { POPULATE_TOOLS, populateWorld } from './props.js';
import { PUBLISH_TOOLS, publishChecklist, type TestRecord } from './publish.js';
import { errorMessage, toJson, type ToolResult } from './result.js';
import { findZone, handleTeam, TEAM_TOOLS } from './team.js';
import { lookAtGame, VISUAL_TOOLS } from './visual.js';
import { CODE_TOOLS, handleCodeOutline, handleEditScript, handleReadScript, prepareLuau, readScript } from './code.js';
import { handleRecipe, RECIPE_TOOLS } from './recipes.js';
import { activityContext, activityLabel } from './activity.js';
import { checkAssets, optimizeGame, QUALITY_TOOLS } from './quality.js';
import { formatNotes, handleNotes, NOTES_TOOLS, readNotes, recordHistory } from './notes.js';

export interface GameKitHost extends PlaytestBridge {
  /** True when the Studio plugin polled recently. */
  isStudioConnected(): boolean;
  /** Runs any other tool of this server (upload_asset, capture_screenshot...). */
  callTool?(name: string, args: Record<string, any>): Promise<any>;
  /** Whether an Open Cloud API key is configured (uploads, Creator Store search). */
  hasOpenCloudKey?(): boolean;
}

export interface ToolDef {
  name: string;
  /** "read" tools are also offered by the read-only inspector edition. */
  category: 'read' | 'write';
  /**
   * When the tool is listed: starter (default, always), builder (builder/full profiles),
   * blender (builder/full, or as soon as Blender is connected). Always callable anyway.
   */
  tier?: 'starter' | 'builder' | 'blender';
  description: string;
  inputSchema: Record<string, unknown>;
}

const obj = (properties: Record<string, unknown>, required: string[] = []) => ({ type: 'object', properties, required });

export const GAMEKIT_TOOLS: ToolDef[] = [
  {
    name: 'roblox_start_here',
    category: 'read',
    description: 'START HERE: checks the Studio connection, shows what the game contains and the step-by-step plan.',
    inputSchema: obj({}),
  },
  {
    name: 'roblox_guide',
    category: 'read',
    description: `Short guides. Topics: ${Object.keys(GUIDES).join(', ')}, catalog, or a system/template id. Read "workflow" first, "errors" when stuck.`,
    inputSchema: obj({ topic: { type: 'string' } }, ['topic']),
  },
  {
    name: 'gamekit_catalog',
    category: 'read',
    description: 'Everything installable without code: templates, systems, world pieces, lighting presets, code recipes.',
    inputSchema: obj({}),
  },
  {
    name: 'create_game',
    category: 'write',
    description: 'Build a COMPLETE playable game in one call (scripts, config, world, UI, lighting; backs up the old place). Then test_game.',
    inputSchema: obj({
      template: { type: 'string', enum: TEMPLATES.map((t) => t.id) },
      options: { type: 'object', description: 'title, theme, difficulty (easy|medium|hard), stages, plots, zones, mazeSize, keys, waves, seed, lighting: see roblox_guide <template>' },
      config: { type: 'object', description: 'Per-module overrides, e.g. {"Shop": {"Currency": "Gems"}}' },
      fresh: { type: 'boolean', description: 'Remove old GameKit content first (default true)' },
      backup: { type: 'boolean', description: 'Snapshot a non-empty place first (default true)' },
    }, ['template']),
  },
  {
    name: 'add_system',
    category: 'write',
    description: 'Install a tested game system (+ what it needs). Its settings: roblox_guide <system>.',
    inputSchema: obj({
      system: { type: 'string', enum: SYSTEMS.map((s) => s.id) },
      config: { type: 'object', description: 'Config overrides, e.g. {"Currency": "Gems"}' },
      resetConfig: { type: 'boolean' },
    }, ['system']),
  },
  {
    name: 'build_world',
    category: 'write',
    description: `Build anchored, tagged geometry in Workspace/GameKit: worlds (${WORLDS.join(', ')}) or one of ${PIECES.length} pieces (jump_pad, coin, checkpoint, spinner, tower_pad...: roblox_guide building). Same name = replaced. [x,y,z] studs, y up.`,
    inputSchema: obj({
      kind: { type: 'string' },
      name: { type: 'string' },
      zone: { type: 'string', description: 'Build at the center of a team zone' },
      options: { type: 'object', description: 'position [x,y,z] + kind options (roblox_guide building)' },
    }, ['kind']),
  },
  {
    name: 'build_ui',
    category: 'write',
    description: 'Screen UI from JSON, no Luau: frame/label/button/image/textbox/scroll/bar; bind "stat:Coins", bar, showIf, action "toggle:Window". See roblox_guide ui.',
    inputSchema: obj({
      spec: {
        type: 'object',
        description: '{ name, children: [{ type, name, text, position, size [w,h], color, bind, action, children }] }',
        properties: { name: { type: 'string' }, children: { type: 'array', items: { type: 'object' } } },
        required: ['name', 'children'],
      },
    }, ['spec']),
  },
  {
    name: 'set_environment',
    category: 'write',
    description: 'Mood and map: lighting preset, time of day, base terrain, remove the Baseplate, and terrain features placed where the plan says (mountain, hill, lake, river, road, path, plateau, paint). See roblox_guide map.',
    inputSchema: obj({
      features: {
        type: 'array',
        description: 'Applied after the base terrain, at ground level (terrainCenter y). [{type: "mountain", at: [x, z], radius, height}, {type: "lake", at, radius, depth}, {type: "river"|"road"|"path", points: [[x, z], ...], width}, {type: "plateau", at, size: [w, d], height (0 = flatten a building spot)}, {type: "paint", at, size, material}]. material: any terrain material name.',
        items: {
          type: 'object',
          properties: {
            type: { type: 'string', enum: [...FEATURE_TYPES] },
            at: { type: 'array', items: { type: 'number' } },
            points: { type: 'array', items: { type: 'array', items: { type: 'number' } } },
            radius: { type: 'number' },
            size: { type: 'array', items: { type: 'number' } },
            height: { type: 'number' },
            depth: { type: 'number' },
            width: { type: 'number' },
            material: { type: 'string' },
          },
          required: ['type'],
        },
      },
      preset: { type: 'string', enum: Object.keys(LIGHTING_PRESETS) },
      clockTime: { type: 'number' },
      terrain: { type: 'string', enum: [...TERRAIN_MODES] },
      terrainSize: { type: 'number' },
      terrainCenter: { type: 'array', items: { type: 'number' } },
      hillHeight: { type: 'number' },
      water: { type: 'boolean' },
      removeBaseplate: { type: 'boolean' },
      seed: { type: 'number' },
    }),
  },
  {
    name: 'write_script',
    category: 'write',
    description: 'The SAFE way to create/replace a whole script: auto-fixes JS-style mistakes, then checks with the Luau compiler, a beginner linter and the Roblox API list; refuses broken code. For small changes use edit_script.',
    inputSchema: obj({
      path: { type: 'string', description: 'e.g. "ServerScriptService/CoinGiver"' },
      source: { type: 'string' },
      kind: { type: 'string', enum: ['server', 'client', 'module'] },
      force: { type: 'boolean', description: 'Write despite linter errors (never despite syntax errors)' },
    }, ['path', 'source']),
  },
  {
    name: 'check_luau',
    category: 'read',
    description: 'Check Luau without writing it (compiler, beginner linter, Roblox API names) and get an auto-fixed version. Works offline.',
    inputSchema: obj({
      source: { type: 'string' },
      kind: { type: 'string', enum: ['server', 'client', 'module'] },
    }, ['source']),
  },
  {
    name: 'check_game',
    category: 'read',
    description: 'Audit the place without playing: script errors, wrong script locations, bad API names, missing spawn, loose parts, pieces without their system.',
    inputSchema: obj({ includeGameKit: { type: 'boolean' } }),
  },
  {
    name: 'test_game',
    category: 'write',
    description: 'Automatic playtest: plays the game, reports server+client errors with script, line and fix, then stops. Repeat after every change until PASS. players: 2 = multiplayer test; device: "phone" = mobile screen + UI checks.',
    inputSchema: obj({
      seconds: { type: 'number', description: '8-120, default 20' },
      autoplay: { type: 'boolean' },
      players: { type: 'number', description: '1-4 (2+ = server + clients)' },
      device: { type: 'string', description: 'phone | tablet | Studio device id' },
    }),
  },
  ...NOTES_TOOLS,
  ...QUALITY_TOOLS,
  ...CODE_TOOLS,
  ...RECIPE_TOOLS,
  ...POPULATE_TOOLS,
  ...VISUAL_TOOLS,
  ...BACKUP_TOOLS,
  ...TEAM_TOOLS,
  ...JOB_TOOLS,
  ...BLENDER_TOOLS,
  ...SOUND_TOOLS,
  ...ECONOMY_TOOLS,
  ...PUBLISH_TOOLS,
];

export const GAMEKIT_TOOL_NAMES = new Set(GAMEKIT_TOOLS.map((t) => t.name));

const BLENDER_NAMES = new Set(BLENDER_TOOLS.map((t) => t.name));

function text(value: unknown) {
  return { content: [{ type: 'text', text: typeof value === 'string' ? value : toJson(value) }] };
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

export interface GameKitOptions {
  /** Called when Blender answers for the first time (to list the blender_* tools). */
  onBlenderConnected?: () => void;
}

export class GameKit {
  readonly jobs = new JobRegistry();
  readonly blender: BlenderTools;
  readonly sound: SoundTools;
  private tests: TestRecord[] = [];

  constructor(private host: GameKitHost, options: GameKitOptions = {}) {
    this.blender = new BlenderTools(host, undefined, { onConnected: options.onBlenderConnected });
    this.sound = new SoundTools(host);
  }

  private requireStudio() {
    if (!this.host.isStudioConnected()) {
      const error = new Error(`${NOT_CONNECTED.problem} ${NOT_CONNECTED.fix.join(' ')}`);
      throw error;
    }
  }

  /** Like call(), but failures come back as an error result the model can read. */
  async run(name: string, args: Record<string, any> = {}) {
    try {
      const result = await this.call(name, args);
      await this.remember(name, args, result);
      return result;
    } catch (error) {
      return { content: [{ type: 'text', text: `Error: ${error instanceof Error ? error.message : String(error)}` }], isError: true };
    }
  }

  /** Writes a line to the project history (game_notes) after a successful change. */
  private async remember(name: string, args: Record<string, any>, result: any) {
    const describe: Record<string, () => string> = {
      create_game: () => `create_game ${args.template}`,
      add_system: () => `add_system ${args.system}${args.config ? ' (config changed)' : ''}`,
      write_script: () => `write_script ${args.path}`,
      edit_script: () => `edit_script ${args.path}`,
      code_recipe: () => `code_recipe ${args.recipe}${args.params?.target ? ` on ${args.params.target}` : ''}`,
      blender_to_roblox: () => `blender_to_roblox ${args.name}`,
      build_ui: () => `build_ui ${args.spec?.name ?? ''}`,
      make_sound: () => `make_sound ${args.action ?? 'generate'} "${String(args.prompt ?? args.name ?? '').slice(0, 60)}"`,
    };
    if (!describe[name] || args.preview || (name === 'code_recipe' && !args.recipe)) return;
    if (!this.host.isStudioConnected()) return;
    let body: any;
    try {
      body = JSON.parse(result?.content?.[0]?.text ?? '{}');
    } catch {
      return;
    }
    if (result?.isError || body?.ok === false || body?.written === false) return;
    await recordHistory(this.host, describe[name]());
  }

  async call(name: string, args: Record<string, any> = {}) {
    const def = GAMEKIT_TOOLS.find((t) => t.name === name);
    const write = def?.category === 'write' && !args.preview && !(name === 'game_notes' && (args.action ?? 'read') === 'read');
    return activityContext.run({ label: activityLabel(name, args), write }, () => this.dispatch(name, args));
  }

  private async dispatch(name: string, args: Record<string, any>) {
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
      case 'game_notes': this.requireStudio(); return handleNotes(this.host, args);
      case 'check_assets': this.requireStudio(); return checkAssets(this.host, args);
      case 'optimize_game': this.requireStudio(); return optimizeGame(this.host, args);
      case 'read_script': this.requireStudio(); return handleReadScript(this.host, args);
      case 'edit_script': this.requireStudio(); return handleEditScript(this.host, args);
      case 'code_outline': this.requireStudio(); return handleCodeOutline(this.host, args);
      case 'code_recipe': return handleRecipe(this.host, args, () => this.requireStudio());
      case 'populate_world': this.requireStudio(); return populateWorld(this.host, args);
      case 'look_at_game': this.requireStudio(); return lookAtGame(this.host, args);
      case 'backup_game': this.requireStudio(); return handleBackup(this.host, args);
      case 'team': this.requireStudio(); return handleTeam(this.host, args);
      case 'start_job':
      case 'job_status':
        return handleJobTool(this.jobs, name, args, (tool, toolArgs) => this.runAny(tool, toolArgs));
      case 'balance_economy':
        if (args.fromGame) this.requireStudio();
        return handleEconomy(this.host, args);
      case 'make_sound': return this.sound.call(args);
      case 'publish_checklist': this.requireStudio(); return publishChecklist(this.host, this.tests);
      default:
        if (BLENDER_NAMES.has(name)) return this.blender.call(name, args);
        throw new Error(`Unknown GameKit tool: ${name}`);
    }
  }

  /** Runs any tool (GameKit or not) for background jobs; errors become error results. */
  private async runAny(tool: string, args: Record<string, any>): Promise<ToolResult> {
    if (GAMEKIT_TOOL_NAMES.has(tool)) return (await this.run(tool, args)) as ToolResult;
    if (!this.host.callTool) throw new Error(`Cannot run "${tool}" in the background here`);
    try {
      return (await this.host.callTool(tool, args)) as ToolResult;
    } catch (error) {
      return { content: [{ type: 'text', text: `Error: ${errorMessage(error)}` }], isError: true };
    }
  }

  async startHere() {
    const plan = [
      'Pick a template for the idea and call create_game (catalog: gamekit_catalog). Write the idea and a TODO list with game_notes.',
      'Call test_game; fix every error it reports; repeat until PASS.',
      'Customise with add_system {config}, build_world, build_ui, set_environment (no code).',
      'Code: code_recipe first, then write_script / edit_script (they check the Luau). Read roblox_guide coding.',
      'Look at it with look_at_game, decorate with populate_world (themes), save with backup_game before big changes.',
      'Finish with check_game and polish (roblox_guide design). Before publishing: test_game {players: 2}, test_game {device: "phone"}, check_assets, optimize_game, publish_checklist.',
      'A picture to copy: roblox_guide reference (whole scene in Blender, compare there, export, gameplay in Roblox).',
      'Statues, characters, eggs, portals, trees: Blender (blender_status, then blender_to_roblox; rigged characters: then blender_animation), never stacked parts. Several AIs at once: team {action: "plan"}, then each one claims tasks and zones.',
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
    for _, d in service:GetDescendants() do if d:IsA("LuaSourceContainer") and not d:FindFirstAncestor("GameKitBackups") then scripts += 1 end end
  end
end
for _, d in workspace:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
return HttpService:JSONEncode({ place = game.Name, placeId = game.PlaceId, gameKit = kit ~= nil,
  installedSystems = installed, worldPieces = pieces, scripts = scripts, parts = parts,
  httpEnabled = HttpService.HttpEnabled })`, 'Studio state');
      // The project memory: a new session resumes from it instead of re-reading everything.
      let memory: string | undefined;
      try {
        const notes = await readNotes(this.host);
        if (Object.values(notes).some((list) => list.length)) memory = formatNotes(notes);
      } catch {
        memory = undefined;
      }
      const next = memory
        ? 'Continue from the project memory above (TODO first). Keep it updated with game_notes.'
        : state.gameKit
          ? 'GameKit is already installed: run test_game, then keep improving (add_system / build_world / build_ui). Write the idea and a TODO list with game_notes.'
          : 'Empty or custom place: call create_game with the template closest to the idea, then write the idea and TODO with game_notes.';
      return text({ ...base, studio: { connected: true, ...state }, memory, next });
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
    let backup: any;
    if (args.backup !== false) {
      try {
        if (await placeHasContent(this.host)) {
          const saved = await saveBackup(this.host, `before create_game ${template.id}`);
          backup = saved?.ok ? { id: saved.backup?.id, restore: `backup_game {"action": "restore", "id": "${saved.backup?.id}"}` } : { error: saved?.error };
        }
      } catch (err) {
        backup = { error: err instanceof Error ? err.message : String(err) };
      }
    }
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
      backup,
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
    const options = { ...(args.options ?? {}) };
    if (args.zone && !options.position) {
      const zone = await findZone(this.host, String(args.zone));
      if (!zone) throw new Error(`Zone "${args.zone}" does not exist (team {"action": "zones"}).`);
      options.position = [zone.center[0], zone.center[1] - zone.size[1] / 2, zone.center[2]];
    }
    const node = buildWorld(kind, options);
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

  async checkLuau(args: Record<string, any>) {
    const context: ScriptContext = args.kind === 'server' ? 'server' : args.kind === 'client' ? 'client' : args.kind === 'module' ? 'module' : 'unknown';
    const source = String(args.source ?? '');
    const prepared = await prepareLuau(source, context);
    const changed = prepared.fixes.length > 0;
    return text({
      ok: prepared.validation.errors.length === 0,
      checker: prepared.validation.available ? undefined : 'compiler unavailable: linter only',
      autofixed: prepared.fixes,
      errors: prepared.validation.errors,
      warnings: prepared.validation.warnings,
      // The fixed code, so the model can reuse it (write_script applies the same fixes itself).
      fixedSource: changed && source.length <= 6000 ? prepared.source : undefined,
      next: changed ? 'write_script applies these fixes automatically: just send your code.' : undefined,
    });
  }

  async writeScript(args: Record<string, any>) {
    const segments = splitPath(String(args.path ?? ''));
    if (segments.length < 2) throw new Error('path must include the container and the script name, e.g. "ServerScriptService/MyScript"');
    const kind = (args.kind as 'server' | 'client' | 'module' | undefined) ?? inferKind(segments);
    const className = kindToClass(kind) ?? 'Script';
    const prepared = await prepareLuau(String(args.source ?? ''), contextFor(className, segments.join('.')));
    const { validation } = prepared;
    if (!validation.syntaxOk || (validation.errors.length && !args.force)) {
      return text({
        written: false,
        reason: !validation.syntaxOk ? 'The code has syntax errors (it would not run). Fix them and call write_script again.' : 'The checks found mistakes that break the game. Fix them (or force: true if you are sure).',
        errors: validation.errors,
        warnings: validation.warnings.slice(0, 8),
        autofixed: prepared.fixes,
      });
    }
    this.requireStudio();
    const name = segments[segments.length - 1];
    const report = await install(this.host, {
      label: `GameKit: write ${segments.join('/')}`,
      items: [{ parent: segments.slice(0, -1), mode: 'merge', node: { name, className, source: prepared.source } }],
    });
    return text({
      written: report.ok,
      error: report.error,
      path: segments.join('/'),
      className,
      autofixed: prepared.fixes,
      warnings: validation.warnings.slice(0, 8),
      next: 'Run test_game. For later changes use edit_script (find/replace) instead of rewriting the whole script.',
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
    const result = await runPlaytest(this.host, { seconds: args.seconds, autoplay: args.autoplay, players: args.players, device: args.device });
    this.tests = [...this.tests.slice(-9), { verdict: String(result.verdict), at: Date.now(), players: Number(args.players) || 1, device: args.device ? String(args.device) : undefined }];
    // Show the failing lines of the first errors: the fix can be made straight away.
    const withCode = (Array.isArray(result.errors) ? result.errors : []).filter((e: any) => e.script && e.line).slice(0, 3);
    for (const error of withCode) {
      try {
        const info = await readScript(this.host, String(error.script).replace(/^game\./, ''));
        if (info.ok) error.code = codeAt(info.source, Number(error.line));
      } catch {
        // the script may be gone (e.g. a runtime-created one): the message is still there
      }
    }
    return text({
      ...result,
      next: result.verdict === 'PASS'
        ? (args.players > 1 || args.device
          ? 'Great. Improve the game (roblox_guide design) and test again after each change.'
          : 'Great. Before publishing also run test_game {players: 2} and test_game {device: "phone"}, then optimize_game.')
        : 'Fix the first error with edit_script (its code is shown; read_script { path, find } for more), then run test_game again.',
    });
  }
}
