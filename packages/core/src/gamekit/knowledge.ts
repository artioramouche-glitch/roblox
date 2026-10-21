/**
 * Built-in guides. Written for models that know little about Roblox: short, concrete,
 * with the exact tool calls to make. Served by roblox_guide and as MCP resources.
 */

import { SYSTEMS } from './catalog.js';
import { TEMPLATES } from './templates.js';
import { LIGHTING_PRESETS } from './environment.js';
import { OBSTACLES, PIECES, WORLDS } from './world.js';
import { UI_EXAMPLE } from './ui.js';
import { RECIPES } from './recipes.js';
import { firstSentence } from './result.js';

export const GUIDES: Record<string, { title: string; body: string }> = {
  workflow: {
    title: 'How to build a great Roblox game with this MCP (read first)',
    body: `
## The golden path (follow in order)
1. **roblox_start_here** -- checks Studio is connected and shows what is already installed.
2. **Pick a template** that matches the idea (gamekit_catalog lists them):
   obby, tycoon, simulator, arena (PvP), survival (zombie waves), horror_escape, tower_defense (co-op), farming (idle),
   racing (karts), fishing, craft_survival (gather, craft, survive nights together).
   -> **create_game** { template, options }. This builds a COMPLETE playable game in one call
   (and saves a backup of what was there before: backup_game).
   No template fits? Start from the closest one, or install systems one by one with add_system.
3. **test_game** -- plays the game automatically for ~20 s and reports errors with fixes.
   Fix every error, then test again. Repeat until it says PASS.
4. **Customise without code**:
   - numbers & texts: add_system { system, config } or edit ReplicatedStorage.GameKit.Config.<X>
   - level design: build_world (whole courses/maps or single pieces like jump_pad, coin, spinner)
   - screens: build_ui (JSON -> real UI, live stat text, buttons that open windows)
   - mood: set_environment (lighting preset + terrain)
   - scenery: populate_world { theme: "forest" | "desert" | "snow" | "beach" | "fantasy" | "city" | "farm" | "spooky" | "garden" }
   - retention: add_system inventory | levels | quests | pets (eggs) | codes | social -- quests teach the game
     step by step (Target = guide arrow), codes reward returning players, social boosts playing with friends
   - custom 3D models: Blender (guide "blender") -> blender_to_roblox (characters: + blender_animation)
   - **look_at_game** to SEE the result from several angles; fix what looks wrong.
   - advanced (find_tools + call_tool): terrain_fill_*, lighting_*, particle_create, sound_*, animation_*,
     insert_asset (Creator Store models), capture_device_matrix (phone/tablet screenshots).
5. **Only then write code** (guide "coding"): first try code_recipe (ready-made verified scripts), else write_script
   for a new script and edit_script for changes (both auto-fix and refuse broken Luau).
6. **check_game** before finishing: finds scripts in wrong places, syntax errors, loose parts, missing spawns.
7. Polish (see guide "design"), balance prices (balance_economy), then before publishing: test_game { players: 2 },
   test_game { device: "phone" }, check_assets, optimize_game, publish_checklist (guide "publishing").

## Working faster
- game_notes is the project's memory (idea, decisions, todo, done): read it first in a new conversation, update it as you go.
- backup_game { action: "save" } before a risky change; { action: "restore" } if it breaks.
- Slow tools (blender_to_roblox, long test_game, big populate_world) can run with start_job; get the result with job_status { id, wait: 30 }.
- Several AIs on the same game: guide "team".

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
- Long-term goals: levels (XP bar), quests (chain mode = tutorial, guide arrow), eggs & pets (collection), inventory items to sell.
- Growth: codes system (announce a new code with each update), social system (+10% per friend in the server,
  invite button, group bonus with Config.Social.GroupId).
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
## build_world options (options: {...})
- All: position [x, y, z]. zone: "<team zone>" builds at the zone center.
- obby_course: stages, difficulty (easy|medium|hard), theme, coins, obstacles [list], title, seed
- lobby: title, size, shop, leaderboardStat | arena: size, theme, spawns | maze: width, height, keys, ceiling, monster, seed
- tycoon_plots: count | simulator_world: zones, basePrice | decor_scatter: radius, count, clear | td_map | farm: plots, crops
- Pieces: color, size [x,y,z], yaw (degrees), stage (checkpoint), power (jump_pad), speed (speed_pad, conveyor, spinner),
  offset [x,y,z] + duration (moving_platform), stat + amount (coin), enemy + maxAlive (enemy_spawner), zone + price (zone_gate),
  target (teleporter), tower (tower_pad: Archer|Cannon|Frost), crop (seed_stand), length (fence), snow (pine_tree), flicker (lamp).
## populate_world options
theme + count, items [{kind | assetId | from, count, size: [min, max]}], center [x,y,z], radius (150), clear (empty
radius in the middle, 40), size [w, d] (rectangle instead of a circle), zone (a team zone), spacing (8), name (Decor),
seed, snap (true: stand on terrain/big floors), avoidGameplay (true: drop props on roads/pads or overlapping parts).
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
   automatic play-through (checkpoints, coins, kill parts, shop, quests, eggs...), stats after spawn. Ends by itself.
   - test_game { players: 2 }: server + 2 clients (rounds, PvP, co-op, trading only break with several players).
   - test_game { device: "phone" }: phone screen; fails on buttons too small, UI off screen, unreadable text.
   - check_assets: every sound/animation/image really loads (private assets are silent in live games).
   - optimize_game: parts, physics, shadows, lights, particles for low-end phones; optimize_game { apply: [...] } fixes.
3. For each error: its code lines are shown; fix them with edit_script (read_script { path, find } for more context),
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
  coding: {
    title: 'Writing code that works the first time (read first if you must code)',
    body: `
## Order of preference
1. No code: create_game / add_system / build_world / build_ui (config instead of scripts).
2. code_recipe: verified scripts from params (touch_reward, prompt_action, door, timed_spawner, playtime_reward,
   ui_button_remote, npc_dialog, badge_award, character_stats, chat_command, area_music, tween_loop).
   code_recipe {} lists them with their params. Then tweak the SETTINGS table with edit_script.
3. write_script for a NEW script; edit_script to CHANGE one (find/replace, cheaper and safer than rewriting).
## Before changing existing code
- code_outline: what each script does (one line each). read_script { path, find: "word" }: only the lines you need.
- edit_script { path, find: "<exact old lines>", replace: "<new lines>" }. Indentation may differ; the result is
  checked before writing, so a broken edit changes nothing.
## What the checks catch for you (fix what they report, do not use force)
- JavaScript/Python habits are fixed automatically: != && || ! null // comments let/const i++ "a" + b, backtick $-braces.
- Invented Roblox APIs: wrong service/class/enum names, Vector3.New, humanoid.Walkspeed, deprecated methods
  (they suggest the right name).
- Beginner mistakes: LocalPlayer on the server, DataStore without pcall, loops without task.wait, trusting the client.
## Patterns to copy
- Stats: PlayerData.defineStat({ Name = "Gems", Default = 0, Leaderstat = true }); PlayerData.reward(player, "Gems", 5);
  if PlayerData.spend(player, "Gems", 10) then ... end. Clients read player:GetAttribute("Gems").
- Client -> server: client Net.send("Buy", itemId); server Net.on("Buy", function(player, itemId) --[[check everything]] end).
- Tagged parts: Util.onTag("Lava", function(part) ... end) handles parts added later too.
- Touch: local player = Util.playerFromHit(hit) (nil for non-players); Util.cooldown(2) per player.
- Always test_game after writing code; read the error hint, fix with edit_script, test again.
`,
  },
  blender: {
    title: 'Custom 3D models with Blender (blender_* tools)',
    body: `
## Setup (once)
1. Install Blender (3.0+, 4.x recommended). In the MCP folder: npm run install-blender-addon
   (or Blender > Edit > Preferences > Add-ons > Install from disk > integrations/blender-mcp/addon.py, tick "MCP for Blender").
2. In Blender's 3D view press N > tab "MCP for Blender" > "Connect to MCP server".
3. blender_status -> connected: true. The other blender_* tools appear.
## Make a prop
- Ready-made: blender_assets { action: "search", source: "polypizza" | "sketchfab" | "polyhaven", query } then
  { action: "download", source, id }. AI generation: { action: "generate", source: "hyper3d" | "hunyuan3d", query } then poll/import.
- From a picture (e.g. a concept image made by an image AI): add images: ["C:/abs/path/front.png", ...] (png/jpg/webp,
  plain white background, one object). hyper3d takes several views of the same object (local paths with Rodin Mode
  "hyper3d.ai", URLs with "fal.ai"); hunyuan3d takes exactly one image and ignores query.
- By code: blender_python with bpy, in small steps. Model in METERS (door 2 m, character 1.8 m), base at Z = 0,
  one material per mesh, < 20k triangles per mesh, textures <= 1024 px.
- Check it: blender_scene { screenshot: true }.
## Send it to the game
- blender_to_roblox { name, objects: ["MyProp"], position: [x, y, z] }: exports (auto-reduces heavy meshes),
  uploads (needs ROBLOX_OPEN_CLOUD_API_KEY + ROBLOX_CREATOR_USER_ID), inserts at real size (1 m = 3.57 studs) on the ground.
- It takes 30 s - 2 min: use start_job { tool: "blender_to_roblox", arguments: {...} } and keep working.
- More options: parent (default Workspace/GameKit/Props), format (fbx | glb), maxTriangles (20000), decimate (true),
  anchored (true), collide (true), description (asset description on Roblox).
- No API key: it exports the file; import it in Studio (Home > Import 3D) then blender_to_roblox { name, existing: "Workspace/<model>" }.
- Many copies around the map: populate_world { items: [{ from: "Workspace/GameKit/Props/<name>", count: 10, size: [6, 10] }] }.
## Characters and animations
- Rig in Blender (armature + weights, max 4 bones per vertex, < 100 bones). blender_to_roblox exports mesh + armature
  and gives the model an Animator.
- Each Blender action -> blender_animation { rig: "<model path>", action: "Walk", priority: "Movement" }:
  a KeyframeSequence in ServerStorage/GameKit/Animations with a temporary id to test in Studio, plus an animated FBX.
- Publish it (right-click the KeyframeSequence > Save to Roblox), use the new id, then check_assets { ids: [id] }.
`,
  },
  team: {
    title: 'Several AIs building one game at the same time (team)',
    body: `
Every AI connects its own MCP client to the same Studio (the first MCP server owns the port, the others join it).
The board lives inside the place (ServerStorage/GameKitTeam), so everyone sees the same tasks.
1. ONE lead AI: team { action: "plan", template, goal } (default plan: core game, main area, scenery, 3D props,
   UI & shop, economy, QA, publish). Then create_game.
2. Every AI picks a short unique name (claude-1, gemini-1, local-1) and loops:
   team { action: "claim", agent, role? } -> do the task -> team { action: "done", agent, task, note }.
3. Before building, reserve space: team { action: "claim_zone", agent, zone, center: [x, y, z], size: [w, h, d] }.
   Overlapping another agent's zone is refused. Build inside it: build_world { zone }, populate_world { zone }.
4. Blocked? team { action: "block", agent, task, note }. Found a bug? team { action: "add", title, details, role: "qa" }.
   More options: plan { template, replace: true }, claim_zone { purpose }, list { full: true } (details + notes),
   release/release_zone { force: true } (only when the owner AI is gone).
5. Studio does one thing at a time: do not run test_game while others edit; the QA agent tests between tasks.
   Blender work runs in parallel (different app): artists can model while builders build.
`,
  },
  localization: {
    title: 'Reaching players in their language',
    body: `
- GameKit UI (HUD, shop, toasts, windows) is translated automatically into French, Spanish, Portuguese and German
  (module ReplicatedStorage.GameKit.Lang, used by UIKit).
- Your own texts: Config.Lang.Translations = { fr = { ["Buy sword"] = "Acheter l'épée", ["Level {1}"] = "Niveau {1}" } }.
  In your scripts: local Lang = require(ReplicatedStorage.GameKit.Lang); label.Text = Lang.t("Buy sword").
- Everything else: Creator Dashboard > Localization > turn on automatic text capture + automatic translation.
- Keep texts short and avoid building sentences from pieces ("You have " .. n .. " coins"): use one text with a number instead.
`,
  },
  publishing: {
    title: 'Publishing checklist',
    body: `
0. Run publish_checklist: it verifies what Studio can check and lists the manual steps.
1. test_game passes with no errors; check_game shows no errors.
2. File > Publish to Roblox. Then Game Settings > Security: enable Studio Access to API Services (to test saving).
3. Create an icon (512x512) and thumbnails (1920x1080) on create.roblox.com.
4. Fill the description (what to do, controls) and the maturity questionnaire.
5. Monetization: create game passes/developer products, paste IDs in Config.Monetization.
6. test_game { device: "phone" } and test_game { players: 2 } pass; check_assets finds nothing broken; optimize_game is green.
7. Make the experience Public. Update often; use the daily reward and events to bring players back.
8. Watch Creator Dashboard > Analytics: GameKit already reports the economy (earned/spent per item), obby stage
   funnel and progression (tower defense waves, farming unlocks). Fix the step where most players quit.
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
  const short = (t: string) => firstSentence(t, 140) ?? t;
  const lines: string[] = ['# GameKit catalog (details: roblox_guide <id>)', '', '## Templates (create_game)'];
  for (const t of TEMPLATES) lines.push(`- ${t.id}: ${short(t.summary)}`);
  lines.push('', '## Systems (add_system)');
  for (const s of SYSTEMS) if (s.id !== 'core') lines.push(`- ${s.id}: ${short(s.summary)}`);
  lines.push('', '## World (build_world, populate_world)', `- worlds: ${WORLDS.join(', ')}`, `- pieces: ${PIECES.join(', ')}`, `- obby obstacles: ${OBSTACLES.join(', ')}`);
  lines.push('', `## Lighting presets (set_environment): ${Object.keys(LIGHTING_PRESETS).join(', ')}`);
  lines.push('', `## Code recipes (code_recipe): ${RECIPES.map((r) => r.id).join(', ')}`);
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
  const tpl = templateDoc(key);
  // A template and a system can share an id (farming): show both.
  if (sys && tpl) return `${tpl}\n\n${sys}`;
  if (sys) return sys;
  if (tpl) return tpl;
  return `Unknown topic "${topic}". Topics: ${[...Object.keys(GUIDES), 'catalog', ...SYSTEMS.map((s) => s.id), ...TEMPLATES.map((t) => t.id)].join(', ')}`;
}
