/**
 * MCP prompts, resources and server instructions. Instructions are injected by most
 * clients into the model's system prompt, so even a model that never reads the docs
 * learns the golden path.
 */

import { SYSTEMS } from './catalog.js';
import { GUIDES, guideText } from './knowledge.js';
import { TEMPLATES } from './templates.js';
import type { Server } from '@modelcontextprotocol/sdk/server/index.js';
import {
  ErrorCode,
  GetPromptRequestSchema,
  ListPromptsRequestSchema,
  ListResourcesRequestSchema,
  McpError,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { GAMEKIT_TOOLS, GAMEKIT_TOOL_NAMES } from './tools.js';
import { firstSentence, toJson } from './result.js';

export { firstSentence };
import { baseToolVisible, getProfile, PROFILES, setProfile, tierVisible } from './profiles.js';

export const SERVER_INSTRUCTIONS = `This server lets you build complete Roblox games in Roblox Studio.
ALWAYS follow this path:
1. Call roblox_start_here first.
2. Build the game with create_game (templates: ${TEMPLATES.map((t) => t.id).join(', ')}) instead of writing code from scratch.
3. Call test_game after every change and fix every error it reports until it says PASS.
4. Customise with add_system (config), build_world, build_ui and set_environment -- they need no code.
5. Before writing code, try code_recipe (verified scripts). Otherwise write_script for new scripts and edit_script for changes: both auto-fix and refuse broken code. Server logic in ServerScriptService, UI/input in LocalScripts.
6. Look at the result with look_at_game, decorate with populate_world, and run check_game before finishing.
Save with backup_game before risky changes. Slow tools (blender_to_roblox, long test_game) can run through start_job while you keep working.
Custom 3D models: blender_status, then model in Blender and send with blender_to_roblox. Several AIs on one game: team (plan, claim tasks, claim zones).
Read roblox_guide (topics: workflow, coding, design, luau, client-server, ui, errors) when unsure. Understand existing code with code_outline and read_script { path, find }. Never invent Roblox APIs; never trust values sent by the client.
For anything else (terrain, lighting, animations, particles, sounds, assets, profiling, multiplayer tests, screenshots...) many more tools exist: find_tools then call_tool.`;

export interface PromptDef {
  name: string;
  description: string;
  arguments: Array<{ name: string; description: string; required?: boolean }>;
  build: (args: Record<string, string>) => string;
}

export const PROMPTS: PromptDef[] = [
  {
    name: 'make_game',
    description: 'Build a complete Roblox game from an idea, step by step, with automatic testing.',
    arguments: [
      { name: 'idea', description: 'What the game is about, e.g. "a candy obby with 20 levels"', required: true },
      { name: 'template', description: `Optional template: ${TEMPLATES.map((t) => t.id).join(', ')}` },
    ],
    build: (a) => `Build this Roblox game: "${a.idea}".
Follow exactly:
1. Call roblox_start_here.
2. Choose the closest template${a.template ? ` (use "${a.template}")` : ` among: ${TEMPLATES.map((t) => `${t.id} = ${t.summary}`).join(' | ')}`}.
3. Call create_game with fitting options (title, theme, difficulty, sizes).
4. Call test_game. Each error shows its code lines: fix them with edit_script, test again. Repeat until PASS. Custom features: code_recipe first, then write_script.
5. Customise to match the idea: add_system config (rewards, prices, texts), build_world pieces, build_ui screens, set_environment mood, populate_world scenery.
6. look_at_game to check how it looks; fix what looks wrong.
7. test_game again, then check_game. Report what you built and how to play it.`,
  },
  {
    name: 'fix_my_game',
    description: 'Find and fix every error in the current place.',
    arguments: [],
    build: () => `Fix this Roblox game.
1. Call check_game and fix every "error" finding (syntax, scripts in the wrong place, missing systems).
2. Call test_game. Each runtime error shows its code lines and a hint: fix with edit_script (read_script { path, find } for context).
3. Repeat test_game until it reports PASS. Do not stop while errors remain.
4. Summarise what was wrong and what you changed.`,
  },
  {
    name: 'add_feature',
    description: 'Add a feature to the current game, preferring ready-made systems.',
    arguments: [{ name: 'feature', description: 'e.g. "a shop that sells a sword", "double jump", "zombie enemies"', required: true }],
    build: (a) => `Add this feature: "${a.feature}".
1. Call gamekit_catalog. If a system or world piece covers it (${SYSTEMS.filter((s) => s.id !== 'core').map((s) => s.id).join(', ')}), use add_system / build_world with config instead of code.
2. Otherwise write the code with write_script (server logic in ServerScriptService, UI/input in LocalScripts, remotes via GameKit Net). Read roblox_guide gamekit-api first.
3. Call test_game until PASS.`,
  },
  {
    name: 'polish_game',
    description: 'Make the game feel professional: juice, mood, onboarding, retention.',
    arguments: [],
    build: () => `Polish this Roblox game using roblox_guide design as a checklist:
- set_environment with a preset that matches the theme; scenery with populate_world { theme }; look_at_game to check.
- Prices: balance_economy { fromGame: true } and apply the suggested prices.
- Clear goal on join (Config.Core.WelcomeMessage), signs/billboards, status bar text.
- Rewards feel good: HUD pop-ups (hud system), coins along paths, daily reward, leaderboard, cosmetics in the shop (trails, pets).
- Check mobile: big buttons, readable text (build_ui sizes).
Then test_game until PASS.`,
  },
  {
    name: 'team_build',
    description: 'Build one game with several AIs at the same time (shared task board and map zones).',
    arguments: [
      { name: 'agent', description: 'Your short unique name, e.g. "claude-1"', required: true },
      { name: 'idea', description: 'The game idea (only needed by the first AI)' },
    ],
    build: (a) => `You are "${a.agent}", one of several AIs building the same Roblox game. Read roblox_guide team.
1. team { "action": "list" }. If there are no tasks${a.idea ? `, create the plan: team { "action": "plan", "goal": "${a.idea}" }` : ', wait for the lead AI to create the plan (list again in a moment)'}.
2. Loop: team { "action": "claim", "agent": "${a.agent}" } -> if the task has a zone, claim_zone first -> do the task with the GameKit tools -> team { "action": "done", "agent": "${a.agent}", "task": "<id>", "note": "<what you did>" }.
3. Only build inside your zones (build_world / populate_world { zone }). Never delete what another agent built.
4. Do not run test_game while other agents are editing; add bugs you find as tasks (team add) instead.`,
  },
  {
    name: 'blender_prop',
    description: 'Create a custom 3D prop in Blender and place it in the game.',
    arguments: [{ name: 'prop', description: 'e.g. "a wooden treasure chest"', required: true }],
    build: (a) => `Create "${a.prop}" for the Roblox game. Read roblox_guide blender.
1. blender_status (must be connected).
2. Try blender_assets search (polypizza, sketchfab) for a ready-made model; otherwise model it with blender_python in small steps (meters, base at Z = 0, one material per mesh, < 20k triangles).
3. Check it with blender_scene { "screenshot": true }.
4. start_job { "tool": "blender_to_roblox", "arguments": { "name": "<Name>", "position": [x, y, z] } }, keep working, then job_status { "id", "wait": 60 }.
5. look_at_game { "target": "Workspace/GameKit/Props/<Name>" } to check size and placement, then test_game.`,
  },
];

export interface ResourceDef {
  uri: string;
  name: string;
  description: string;
  read: () => string;
}

export function listResources(): ResourceDef[] {
  const resources: ResourceDef[] = Object.entries(GUIDES).map(([topic, g]) => ({
    uri: `gamekit://guide/${topic}`,
    name: g.title,
    description: `Guide: ${g.title}`,
    read: () => guideText(topic),
  }));
  resources.push({ uri: 'gamekit://catalog', name: 'GameKit catalog', description: 'Templates, systems, world pieces, lighting presets', read: () => guideText('catalog') });
  for (const s of SYSTEMS) resources.push({ uri: `gamekit://system/${s.id}`, name: `System: ${s.title}`, description: s.summary, read: () => guideText(s.id) });
  for (const t of TEMPLATES) resources.push({ uri: `gamekit://template/${t.id}`, name: `Template: ${t.title}`, description: t.summary, read: () => guideText(t.id) });
  return resources;
}

// --- Server wiring shared by the stdio server and the streamable HTTP endpoint ---------------


export interface ListedTool {
  name: string;
  description?: string;
  inputSchema?: unknown;
}

export const META_TOOL_NAMES = new Set(['set_tool_profile', 'find_tools', 'call_tool']);

const GAMEKIT_TIERS = new Map(GAMEKIT_TOOLS.map((t) => [t.name, t.tier]));

/** Meta tools and starter GameKit tools are always listed; everything else depends on the profile. */
export function toolVisible(name: string): boolean {
  if (GAMEKIT_TOOL_NAMES.has(name)) return tierVisible(GAMEKIT_TIERS.get(name));
  return META_TOOL_NAMES.has(name) || baseToolVisible(name);
}

export function metaToolDefinitions(totalTools: number): ListedTool[] {
  return [
    {
      name: 'set_tool_profile',
      description: `List more or fewer tools: starter (default), builder, full (all ${totalTools}). Current: ${getProfile()}. Hidden tools always work through find_tools + call_tool.`,
      inputSchema: { type: 'object', properties: { profile: { type: 'string', enum: PROFILES } }, required: ['profile'] },
    },
    {
      name: 'find_tools',
      description: 'Search ALL tools (also hidden ones) by keyword, e.g. "terrain", "animation". An exact tool name returns its full schema. Then call_tool.',
      inputSchema: { type: 'object', properties: { query: { type: 'string' }, detail: { type: 'boolean', description: 'Full schemas for every match' } } },
    },
    {
      name: 'call_tool',
      description: 'Run any tool by name, even one hidden by the current profile (see find_tools).',
      inputSchema: {
        type: 'object',
        properties: { name: { type: 'string' }, arguments: { type: 'object', description: 'The tool arguments' } },
        required: ['name'],
      },
    },
  ];
}

export interface MetaToolContext {
  /** Every callable tool (listed or not). */
  allTools(): ListedTool[];
  /** Runs a tool through the normal dispatch path. */
  dispatch(name: string, args: Record<string, any>): Promise<any>;
  /** Number of tools listed after a profile change (for the reply). */
  listedCount(): number;
}

// --- Token diet for the tool list ---------------------------------------------------------
// Most clients resend the whole tool list with every message, so every word here costs
// tokens on every turn. GameKit descriptions are written short by hand; the 140+ base tools
// get their first sentence only. find_tools { query, detail: true } shows the full text.

function compactEnabled(): boolean {
  return !/^(0|false|no|off)$/i.test(process.env.ROBLOX_MCP_COMPACT ?? '');
}

function shortenSchema(schema: any, max: number): any {
  if (!schema || typeof schema !== 'object') return schema;
  if (Array.isArray(schema)) return schema.map((s) => shortenSchema(s, max));
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(schema)) {
    if (key === 'description' && typeof value === 'string') out[key] = firstSentence(value, max);
    else if (key === 'additionalProperties' && value === false) continue;
    else out[key] = shortenSchema(value, max);
  }
  return out;
}

/** What tools/list sends: name, description, schema only (no internal fields), shortened. */
export function listingView(tool: ListedTool): ListedTool {
  const view: ListedTool = { name: tool.name, description: tool.description, inputSchema: tool.inputSchema };
  if (!compactEnabled() || GAMEKIT_TOOL_NAMES.has(tool.name) || META_TOOL_NAMES.has(tool.name)) return view;
  return { name: tool.name, description: firstSentence(tool.description, 200), inputSchema: shortenSchema(tool.inputSchema, 90) };
}

function paramSummary(schema: any): string {
  const props = Object.keys(schema?.properties ?? {});
  const required = new Set<string>(schema?.required ?? []);
  return props.map((p) => (required.has(p) ? `${p}*` : p)).join(', ');
}

/** Handles set_tool_profile / find_tools / call_tool. Returns null for any other tool. */
export async function handleMetaTool(name: string, args: Record<string, any>, ctx: MetaToolContext): Promise<any | null> {
  const reply = (value: unknown) => ({ content: [{ type: 'text', text: toJson(value) }] });
  if (name === 'set_tool_profile') {
    const profile = setProfile(String(args.profile ?? ''));
    return reply({ profile, listedTools: ctx.listedCount(), note: 'Tool list updated. If new tools do not show up in your client, use find_tools + call_tool.' });
  }
  if (name === 'find_tools') {
    const query = String(args.query ?? '').toLowerCase().trim();
    const all = ctx.allTools();
    const exact = all.find((t) => t.name === query);
    const words = query.split(/\s+/).filter(Boolean);
    const matches = exact ? [exact] : all.filter((t) => {
      const hay = `${t.name} ${t.description ?? ''}`.toLowerCase();
      return words.every((w) => hay.includes(w));
    });
    // Few matches (or an exact name, or detail: true): full schemas. Otherwise a short index.
    const full = !!args.detail || matches.length <= 3;
    const limit = full ? 8 : 30;
    return reply({
      count: matches.length,
      tools: matches.slice(0, limit).map((t) => (full
        ? { name: t.name, listed: toolVisible(t.name), description: t.description, inputSchema: t.inputSchema }
        : { name: t.name, about: firstSentence(t.description, 110), params: paramSummary(t.inputSchema) })),
      more: Math.max(0, matches.length - limit),
      next: full ? 'Run one with call_tool { name, arguments }.' : 'find_tools { query: "<exact tool name>" } shows its full schema; params with * are required.',
    });
  }
  if (name === 'call_tool') {
    const target = String(args.name ?? '');
    if (!target || META_TOOL_NAMES.has(target)) throw new McpError(ErrorCode.InvalidParams, 'call_tool needs the name of another tool (see find_tools)');
    return ctx.dispatch(target, (args.arguments ?? {}) as Record<string, any>);
  }
  return null;
}

export function registerPromptsAndResources(server: Server) {
  server.setRequestHandler(ListPromptsRequestSchema, async () => ({
    prompts: PROMPTS.map((p) => ({ name: p.name, description: p.description, arguments: p.arguments })),
  }));
  server.setRequestHandler(GetPromptRequestSchema, async (request) => {
    const prompt = PROMPTS.find((p) => p.name === request.params.name);
    if (!prompt) throw new McpError(ErrorCode.InvalidParams, `Unknown prompt: ${request.params.name}`);
    const args = (request.params.arguments ?? {}) as Record<string, string>;
    return {
      description: prompt.description,
      messages: [{ role: 'user' as const, content: { type: 'text' as const, text: prompt.build(args) } }],
    };
  });
  server.setRequestHandler(ListResourcesRequestSchema, async () => ({
    resources: listResources().map((r) => ({ uri: r.uri, name: r.name, description: r.description, mimeType: 'text/markdown' })),
  }));
  server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
    const resource = listResources().find((r) => r.uri === request.params.uri);
    if (!resource) throw new McpError(ErrorCode.InvalidParams, `Unknown resource: ${request.params.uri}`);
    return { contents: [{ uri: resource.uri, mimeType: 'text/markdown', text: resource.read() }] };
  });
}
