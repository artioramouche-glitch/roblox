/**
 * Built-in guides. Written for models that know little about Roblox: short, concrete,
 * with the exact tool calls to make. Served by roblox_guide and as MCP resources.
 */

import { SYSTEMS } from './catalog.js';
import { TEMPLATES } from './templates.js';
import { LIGHTING_PRESETS } from './environment.js';
import { OBSTACLES, PIECES, WORLDS } from './world.js';
import { UI_EXAMPLE } from './ui.js';

export const GUIDES: Record<string, { title: string; body: string }> = {
  workflow: {
    title: 'How to build a great Roblox game with this MCP (read first)',
    body: `
## The golden path (follow in order)
1. **roblox_start_here** -- checks Studio is connected and shows what is already installed.
2. **Pick a template** that matches the idea (gamekit_catalog lists them):
   obby, tycoon, simulator, arena (PvP), survival (zombie waves), horror_escape.
   -> **create_game** { template, options }. This builds a COMPLETE playable game in one call.
   No template fits? Start from the closest one, or install systems one by one with add_system.
3. **test_game** -- plays the game automatically for ~20 s and reports errors with fixes.
   Fix every error, then test again. Repeat until it says PASS.
4. **Customise without code**:
   - numbers & texts: add_system { system, config } or edit ReplicatedStorage.GameKit.Config.<X>
   - level design: build_world (whole courses/maps or single pieces like jump_pad, coin, spinner)
   - screens: build_ui (JSON -> real UI, live stat text, buttons that open windows)
   - mood: set_environment (lighting preset + terrain)
   - advanced (find_tools + call_tool): terrain_fill_*, lighting_*, particle_create, sound_*, animation_*,
     insert_asset (Creator Store models), capture_screenshot to look at the result.
5. **Only then write code**, with write_script (it refuses broken Luau and explains fixes).
6. **check_game** before finishing: finds scripts in wrong places, syntax errors, loose parts, missing spawns.
7. Polish (see guide "design"), then publish (guide "publishing").

## Rules that prevent 90% of bugs
- Server logic (money, damage, saving) goes in **Scripts** in ServerScriptService.
  Input, camera and UI go in **LocalScripts** (StarterPlayerScripts / StarterGui).
- Never trust the client: the client asks ("buy Sword"), the server checks and decides.
- Use **task.wait()** (never wait()), and put a task.wait() in every while-true loop.
- Parts that should not fall must be **Anchored**.
- Use GameKit's PlayerData for stats/saving instead of writing DataStore code.
- After every change: test_game. Read the errors, fix, re-test.
`,
  },
  design: {
    title: 'What makes a Roblox game fun (checklist)',
    body: `
## Core loop (players must understand it in 10 seconds)
Action -> reward -> upgrade -> bigger action. Examples:
- Obby: jump -> checkpoint -> coins -> trails/boosts -> harder stages.
- Simulator: train -> sell -> upgrades/pets -> new zone -> rebirth.
- Tycoon: collect -> buy dropper -> more money -> bigger base.
## Progression
- First reward in < 30 seconds. First upgrade in < 2 minutes.
- Prices grow ~1.5x per level; rewards grow too. Always show the next goal (status bar, locked zone with price).
- Rebirth/prestige gives long-term goals (simulator template has it).
## Juice (feedback) -- makes cheap games feel premium
- Every reward shows a toast or "+N" pop-up (GameKit HUD does this automatically).
- Sounds on actions, particles on pickups, tweens on buttons (UIKit buttons animate).
- Lighting preset + color theme: set_environment { preset: "day" | "sunset" | "neon" | ... }.
## Social & retention
- Global leaderboard (leaderboard system), daily reward with streak (daily system),
  visible cosmetics (trails, pets) so players show off.
## Onboarding
- Welcome toast explaining the goal (Config.Core.WelcomeMessage). Signs/billboards in the world.
- The first 2 minutes must be easy. Difficulty ramps slowly (obby_course does this).
## Mobile first (60%+ of players)
- Big buttons, no tiny text; GameKit UI is responsive. Test in Studio's device emulator.
`,
  },
  luau: {
    title: 'Luau basics for Roblox (cheat sheet)',
    body: `
\`\`\`lua
local Players = game:GetService("Players")          -- always get services like this
local count = 0                                       -- local variable
count += 1                                            -- compound assignment (no ++)
local name = "Coins: " .. count                       -- string concatenation
local text = \`Coins: {count}\`                        -- interpolation needs BACKTICKS
if count > 5 and name ~= "" then                      -- ~= means "not equal"; and/or/not
  print("big")
elseif count == 0 then
  print("zero")
end
for i = 1, 10 do end                                  -- numeric loop
for _, player in Players:GetPlayers() do end          -- loop over a list
local t = { Coins = 10, Items = { "Sword" } }         -- table (dictionary + list)
local function add(a: number, b: number): number      -- function (types optional)
  return a + b
end
Players.PlayerAdded:Connect(function(player)          -- events: :Connect(function ... end)
  print(player.Name .. " joined")
end)
task.wait(1)          task.spawn(fn)      task.delay(2, fn)   -- NOT wait/spawn/delay
local part = Instance.new("Part")                     -- create, set props, parent LAST
part.Anchored = true
part.Size = Vector3.new(4, 1, 4)
part.Color = Color3.fromRGB(255, 0, 0)                -- 0-255 with fromRGB
part.Parent = workspace
local ok, err = pcall(function() end)                 -- catch errors (DataStores, HTTP)
\`\`\`
Common mistakes: != (use ~=), // comments (use --), null (use nil), missing \`end\`,
"text {x}" in double quotes (not interpolated), forgetting :Connect, using . instead of :
for methods (part:Destroy(), not part.Destroy()).
`,
  },
  'client-server': {
    title: 'Client vs server: where each script goes',
    body: `
| Script type | Put it in | Runs on | Use for |
|---|---|---|---|
| Script | ServerScriptService | Server | game rules, money, damage, saving, spawning |
| LocalScript | StarterPlayer > StarterPlayerScripts, StarterGui, StarterCharacterScripts | Each player's device | input, camera, UI, local effects |
| ModuleScript | ReplicatedStorage (shared) or ServerScriptService (server only) | Wherever required | reusable code/config |

- ServerStorage/ServerScriptService are invisible to clients. ReplicatedStorage is seen by both.
- A LocalScript in Workspace or ServerScriptService does NOT run. A Script in StarterPlayerScripts does NOT run.
- Communication: RemoteEvent. With GameKit:
  server: \`Net.on("Buy", function(player, itemId) ... end)\`  client: \`Net.send("Buy", "Sword")\`
  server -> client: \`Net.fire(player, "Name", data)\` / \`Net.notify(player, "text", "success")\`
- SECURITY: the server re-checks everything (price, distance, cooldown). Never accept amounts from the client.
- Players.LocalPlayer only exists in LocalScripts. On the server, get players from events.
- Characters are simulated by their owner: launching the local player (jump pads) is done client-side.
`,
  },
  data: {
    title: 'Saving player data (PlayerData)',
    body: `
Use GameKit PlayerData (installed with every system) -- it handles DataStores, retries, session locking,
autosave, shutdown saves and the leaderboard.
\`\`\`lua
local PlayerData = require(game:GetService("ServerScriptService").GameKit.PlayerData)
PlayerData.defineStat({ Name = "Gems", Default = 0, Leaderstat = true })
PlayerData.onLoaded(function(player) print(player.Name, PlayerData.get(player, "Gems")) end)
PlayerData.add(player, "Gems", 5)            -- exact
PlayerData.reward(player, "Coins", 10)       -- x multipliers (passes, pets, rebirths)
if PlayerData.spend(player, "Coins", 100) then ... end
PlayerData.grant(player, "RedHat"); PlayerData.owns(player, "RedHat")
local mine = PlayerData.section(player, "Quests")  -- your own saved table
mine.Completed = (mine.Completed or 0) + 1
\`\`\`
Client: \`player:GetAttribute("Gems")\` (every stat is mirrored as a Player attribute).
Studio: saving needs the place PUBLISHED and Game Settings > Security > "Enable Studio Access to API Services".
Without it GameKit runs in memory mode (a warning explains it) -- that is not a bug.
`,
  },
  ui: {
    title: 'Making UI without code (build_ui)',
    body: `
build_ui takes JSON. Types: frame, label, button, image, imagebutton, textbox, scroll, bar.
- position: "center" | "top" | "bottom" | "left" | "right" | "top-left" | "top-right" | "bottom-left" | "bottom-right"
- size: [w, h] -- numbers <= 1 are screen fractions, bigger numbers are pixels ([200, 50]).
- layout: "vertical" | "horizontal" | "grid" (children are arranged automatically); gap, padding.
- style: color, textColor ("#RRGGBB"), transparency, corner, stroke, gradient ["#top","#bottom"], font.
- behaviour (no code needed):
  bind: "stat:Coins" + format: "💰 {value}"   -> text follows a stat live
  bind: "state:Status"                        -> follows the round/objective status
  bar: "stat:Power/stat:Capacity"             -> progress bar (type "bar")
  showIf: "state:RoundActive" / "!state:RoundActive" / "stat:Stage>5"
  action: "toggle:WindowName" | "open:X" | "close:X" | "remote:EventName[:arg]"
Example:
\`\`\`json
${JSON.stringify(UI_EXAMPLE, null, 1)}
\`\`\`
Tips: keep buttons >= 48 px tall (mobile), use at most 2-3 colors, put important info top-center.
`,
  },
  building: {
    title: 'Building worlds (build_world) and Roblox space',
    body: `
- Units are studs. Y is up. A character is ~5 studs tall, walks 16 studs/s, jumps ~7 studs high
  and ~12 studs far. Keep obby gaps between 3 and 9 studs.
- Every part that should not fall: Anchored = true (GameKit pieces are anchored).
- position is the CENTER of a part: a platform of height 1 at y=10 has its top at y=10.5.
- Whole worlds: ${WORLDS.join(', ')}.
- Obstacles for obby_course: ${OBSTACLES.join(', ')}.
- Single pieces: ${PIECES.join(', ')}.
- Everything goes to Workspace/GameKit/<name>; building again with the same name replaces it.
- Need something else? find_tools "terrain" / "lighting" / "asset" / "build" lists the low-level world tools
  (terrain_fill_block, lighting_set_preset, insert_asset, generate_build...).
- Each gameplay piece carries the tag + attributes its system reads, e.g. a jump_pad has tag "JumpPad"
  and attribute Power. Change attributes in Studio's Properties panel to tune it.
`,
  },
  testing: {
    title: 'Testing and fixing (test_game, check_game)',
    body: `
1. check_game -- static audit: Luau syntax, beginner mistakes, scripts in the wrong place,
   missing SpawnLocation, unanchored parts. Fast, no playtest.
2. test_game -- real playtest (~20 s): server + client errors with the script and line,
   automatic play-through (checkpoints, coins, kill parts), stats after spawn. Ends by itself.
3. For each error: open the script (get_script_source), fix it with write_script or edit_script_lines,
   re-run test_game. Do not stop while test_game reports errors.
Reading errors: "ServerScriptService.Shop:42: attempt to index nil with 'Value'"
= script Shop, line 42, something before ".Value" is nil (wrong name or not loaded yet -> WaitForChild).
`,
  },
  errors: {
    title: 'Common Roblox errors and their fix',
    body: `
- attempt to index nil with 'X' -> the thing before .X does not exist. Check the name/path, use :WaitForChild("Name") on the client.
- X is not a valid member of Y -> typo, wrong case, or not loaded yet (WaitForChild).
- Infinite yield possible on 'A:WaitForChild("B")' -> B never appears: wrong name or the server never creates it.
- attempt to call a nil value -> calling a function that does not exist (typo, or used . instead of :).
- attempt to perform arithmetic on nil -> a number variable is nil (stat not loaded / attribute missing).
- Script timeout: exhausted allowed execution time -> a loop without task.wait().
- Requested module experienced an error while loading -> the real error is in that ModuleScript (look above).
- FireServer can only be called from the client -> RemoteEvent used on the wrong side.
- DataStore / StudioAccessToApisNotAllowed -> publish + enable Studio API access (or ignore in Studio).
- HTTP 403 / Sound failed to load -> the asset is private; use public or your own assets.
- Unable to cast value to Object/Color3... -> wrong value type (Color3.fromRGB for colors, Vector3.new for sizes).
`,
  },
  publishing: {
    title: 'Publishing checklist',
    body: `
1. test_game passes with no errors; check_game shows no errors.
2. File > Publish to Roblox. Then Game Settings > Security: enable Studio Access to API Services (to test saving).
3. Create an icon (512x512) and thumbnails (1920x1080) on create.roblox.com.
4. Fill the description (what to do, controls) and the maturity questionnaire.
5. Monetization: create game passes/developer products, paste IDs in Config.Monetization.
6. Test on mobile (Studio device emulator) and with 2+ players (Test > Clients and Servers).
7. Make the experience Public. Update often; use the daily reward and events to bring players back.
`,
  },
  performance: {
    title: 'Performance tips',
    body: `
- Keep part count reasonable (< 10k for mobile). Use Models, avoid thousands of tiny parts.
- Anchor static parts. Unanchored parts cost physics every frame.
- Every while-true loop needs task.wait(); prefer events (Touched, Changed) over polling.
- Disconnect connections you no longer need; destroy temporary parts (Debris:AddItem(part, 5)).
- Do visual effects (spinning coins, tweens) on the client, game rules on the server.
- Consider Workspace.StreamingEnabled for big maps (then use WaitForChild on the client).
`,
  },
  'gamekit-api': {
    title: 'GameKit module API (for custom scripts)',
    body: `
Shared (ReplicatedStorage.GameKit):
- Util: formatNumber(n), formatTime(s), config(name, defaults), color(v), playerFromHit(hit) -> (player, character, humanoid),
  onTag(tag, onAdded, onRemoved), onPlayer(fn), onCharacter(fn(character, player)), cooldown(seconds) -> fn(key)->bool,
  teleportOnto(character, part), respawn(player), state() (Folder whose attributes are shared state).
- Net: on(name, handler, perSecond) [server], fire(player, name, ...), fireAll(name, ...), notify(player|nil, text, kind),
  send(name, ...) [client], listen(name, handler) [client], event(name).
- UIKit [client]: hud(), hudButton(name, icon, onClick), window(title, size) -> (window, body), button(parent, text, size, onClick),
  label(parent, text, size, props), toast(text, kind), popText(anchor, text), color(name), corner/stroke/padding(gui).
Server (ServerScriptService.GameKit):
- PlayerData: defineStat, get, set, add, reward, spend, canAfford, onChanged(stat, fn), onLoaded(fn), owns, grant, revoke,
  getOwned, section(player, name), addMultiplier(fn(player, stat)->number), getMultiplier, save, isLoaded, waitForLoad.
Shared state attributes on ReplicatedStorage.GameKit: Status, Timer, RoundActive, RoundNumber, MaxStage, Wave.
`,
  },
};

export function catalogText(): string {
  const lines: string[] = ['# GameKit catalog', '', '## Templates (create_game)'];
  for (const t of TEMPLATES) {
    lines.push(`- **${t.id}** -- ${t.title}: ${t.summary}`);
    lines.push(`  options: ${Object.entries(t.options).map(([k, v]) => `${k} (${v})`).join('; ')}`);
  }
  lines.push('', '## Systems (add_system)');
  for (const s of SYSTEMS) {
    lines.push(`- **${s.id}** [${s.category}] -- ${s.summary}${s.requires.length ? ` (needs: ${s.requires.join(', ')})` : ''}`);
  }
  lines.push('', `## World (build_world)`, `- worlds: ${WORLDS.join(', ')}`, `- pieces: ${PIECES.join(', ')}`, `- obby obstacles: ${OBSTACLES.join(', ')}`);
  lines.push('', '## Lighting presets (set_environment)');
  for (const [k, v] of Object.entries(LIGHTING_PRESETS)) lines.push(`- **${k}**: ${v.description}`);
  return lines.join('\n');
}

export function systemDoc(id: string): string | null {
  const s = SYSTEMS.find((x) => x.id === id);
  if (!s) return null;
  const lines = [`# System: ${s.title} (${s.id})`, '', s.summary, '', `Requires: ${s.requires.join(', ') || 'nothing'}`, `Scripts: ${s.files.join(', ')}`];
  if (s.tags) {
    lines.push('', '## Tags it reacts to');
    for (const [tag, what] of Object.entries(s.tags)) lines.push(`- "${tag}": ${what}`);
  }
  for (const c of s.configs) {
    lines.push('', `## Config.${c.name}`, '```json', JSON.stringify(c.defaults, null, 2), '```');
    for (const [k, d] of Object.entries(c.docs)) lines.push(`- ${k}: ${d}`);
  }
  lines.push('', '## How to use', s.usage);
  return lines.join('\n');
}

export function templateDoc(id: string): string | null {
  const t = TEMPLATES.find((x) => x.id === id);
  if (!t) return null;
  const plan = t.plan({});
  return [
    `# Template: ${t.title} (${t.id})`, '', t.summary, '',
    `Systems: ${plan.systems.join(', ')}`,
    `Lighting: ${plan.environment.preset ?? 'unchanged'}`,
    `Options: ${Object.entries(t.options).map(([k, v]) => `${k} = ${v}`).join('; ')}`,
    '', '## After creating it', ...plan.nextSteps.map((s) => `- ${s}`),
  ].join('\n');
}

export function guideText(topic: string): string {
  const key = topic.toLowerCase().trim();
  if (GUIDES[key]) return `# ${GUIDES[key].title}\n${GUIDES[key].body}`;
  if (key === 'catalog') return catalogText();
  const sys = systemDoc(key);
  if (sys) return sys;
  const tpl = templateDoc(key);
  if (tpl) return tpl;
  return `Unknown topic "${topic}". Topics: ${[...Object.keys(GUIDES), 'catalog', ...SYSTEMS.map((s) => s.id), ...TEMPLATES.map((t) => t.id)].join(', ')}`;
}
