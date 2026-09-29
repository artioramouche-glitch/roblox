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
import { GAMEKIT_TOOL_NAMES } from './tools.js';
import { baseToolVisible, getProfile, PROFILES, setProfile } from './profiles.js';

export const SERVER_INSTRUCTIONS = `This server lets you build complete Roblox games in Roblox Studio.
ALWAYS follow this path:
1. Call roblox_start_here first.
2. Build the game with create_game (templates: ${TEMPLATES.map((t) => t.id).join(', ')}) instead of writing code from scratch.
3. Call test_game after every change and fix every error it reports until it says PASS.
4. Customise with add_system (config), build_world, build_ui and set_environment -- they need no code.
5. When you must write code, use write_script (it validates Luau and refuses broken code). Server logic in ServerScriptService, UI/input in LocalScripts.
6. Before finishing, run check_game.
Read roblox_guide (topics: workflow, design, luau, client-server, ui, errors) when unsure. Never invent Roblox APIs; never trust values sent by the client.
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
4. Call test_game. For each error: read the script (get_script_source), fix it with write_script or edit_script_lines, test again. Repeat until PASS.
5. Customise to match the idea: add_system config (rewards, prices, texts), build_world pieces, build_ui screens, set_environment mood.
6. test_game again, then check_game. Report what you built and how to play it.`,
  },
  {
    name: 'fix_my_game',
    description: 'Find and fix every error in the current place.',
    arguments: [],
    build: () => `Fix this Roblox game.
1. Call check_game and fix every "error" finding (syntax, scripts in the wrong place, missing systems).
2. Call test_game. For each runtime error: open the script, understand the hint, fix it with write_script/edit_script_lines.
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
- set_environment with a preset that matches the theme; decor with build_world decor_scatter.
- Clear goal on join (Config.Core.WelcomeMessage), signs/billboards, status bar text.
- Rewards feel good: HUD pop-ups (hud system), coins along paths, daily reward, leaderboard, cosmetics in the shop (trails, pets).
- Check mobile: big buttons, readable text (build_ui sizes).
Then test_game until PASS.`,
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

/** GameKit and meta tools are always listed; everything else depends on the profile. */
export function toolVisible(name: string): boolean {
  return GAMEKIT_TOOL_NAMES.has(name) || META_TOOL_NAMES.has(name) || baseToolVisible(name);
}

export function metaToolDefinitions(totalTools: number): ListedTool[] {
  return [
    {
      name: 'set_tool_profile',
      description: `Show more or fewer tools. starter = GameKit + essentials (default, best for most AIs), builder = + common editing, world, asset and testing tools, full = all ${totalTools} tools. Current: ${getProfile()}. If your client does not refresh its tool list, use find_tools + call_tool instead.`,
      inputSchema: { type: 'object', properties: { profile: { type: 'string', enum: PROFILES } }, required: ['profile'] },
    },
    {
      name: 'find_tools',
      description: 'Search ALL tools (including the ones hidden by the current profile) by keyword and get their input schema. Then run one with call_tool.',
      inputSchema: { type: 'object', properties: { query: { type: 'string', description: 'Keyword, e.g. "terrain", "attribute", "animation", "profiler"' } } },
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

/** Handles set_tool_profile / find_tools / call_tool. Returns null for any other tool. */
export async function handleMetaTool(name: string, args: Record<string, any>, ctx: MetaToolContext): Promise<any | null> {
  const reply = (value: unknown) => ({ content: [{ type: 'text', text: JSON.stringify(value, null, 2) }] });
  if (name === 'set_tool_profile') {
    const profile = setProfile(String(args.profile ?? ''));
    return reply({ profile, listedTools: ctx.listedCount(), note: 'Tool list updated. If new tools do not show up in your client, use find_tools + call_tool.' });
  }
  if (name === 'find_tools') {
    const query = String(args.query ?? '').toLowerCase().trim();
    const words = query.split(/\s+/).filter(Boolean);
    const matches = ctx.allTools().filter((t) => {
      const hay = `${t.name} ${t.description ?? ''}`.toLowerCase();
      return words.every((w) => hay.includes(w));
    });
    return reply({
      count: matches.length,
      tools: matches.slice(0, 25).map((t) => ({ name: t.name, listed: toolVisible(t.name), description: t.description, inputSchema: t.inputSchema })),
      more: Math.max(0, matches.length - 25),
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
