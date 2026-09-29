/**
 * MCP prompts, resources and server instructions. Instructions are injected by most
 * clients into the model's system prompt, so even a model that never reads the docs
 * learns the golden path.
 */

import { SYSTEMS } from './catalog.js';
import { GUIDES, guideText } from './knowledge.js';
import { TEMPLATES } from './templates.js';

export const SERVER_INSTRUCTIONS = `This server lets you build complete Roblox games in Roblox Studio.
ALWAYS follow this path:
1. Call roblox_start_here first.
2. Build the game with create_game (templates: ${TEMPLATES.map((t) => t.id).join(', ')}) instead of writing code from scratch.
3. Call test_game after every change and fix every error it reports until it says PASS.
4. Customise with add_system (config), build_world, build_ui and set_environment -- they need no code.
5. When you must write code, use write_script (it validates Luau and refuses broken code). Server logic in ServerScriptService, UI/input in LocalScripts.
6. Before finishing, run check_game.
Read roblox_guide (topics: workflow, design, luau, client-server, ui, errors) when unsure. Never invent Roblox APIs; never trust values sent by the client.`;

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
