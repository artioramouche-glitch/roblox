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
import { VFX_PRESETS } from './vfx.js';

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
   - screens: build_ui (JSON -> real UI, live stat text, buttons that open windows), designed in Figma (guide "figma")
   - references before any design: design_refs { query } (UI styles, VFX, thumbnails by genre)
   - effects on hits, pickups, level ups: make_vfx (guide "vfx")
   - mood: set_environment (lighting preset + terrain)
   - scenery: populate_world { theme: "forest" | "desert" | "snow" | "beach" | "fantasy" | "city" | "farm" | "spooky" | "garden" }
   - retention: add_system inventory | levels | quests | pets (eggs) | codes | social -- quests teach the game
     step by step (Target = guide arrow), codes reward returning players, social boosts playing with friends
   - custom 3D models: Blender (guide "blender"; from pictures, measured: guide "image3d") -> blender_to_roblox (characters: + blender_animation)
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
- Sounds on actions (make_sound: roblox_guide sound), particles on pickups, tweens on buttons (UIKit buttons animate).
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
## Visual design: references and prompts first, then build from the images
The user already gave a picture? It is the target: follow guide "reference".
Start from real references: design_refs { query: "<genre> <thing>" } (UI styles, VFX, thumbnails by genre) and pick 1-3 with the user.
- UI screens (HUD, shop, menus): design them in Figma (guide "figma"): figma draw -> the user adjusts -> figma import.
- Effects (hits, pickups, level up, portals): make_vfx (guide "vfx"), VFX Studio for polished ones.
Plain parts look cheap. For anything else visual (map, backdrop/sky, building, prop, egg, character, icon, thumbnail),
BEFORE building, give the user two ready-to-paste prompts:
- Claude Design (claude.ai/design): a board or mockup -- views or screen states, colors, sizes, Roblox limits (touch targets, low-poly).
- Gemini: the reference image -- a 4-view sheet (front, side, back, 3/4) on a plain white background for a 3D object,
  a seamless 2:1 panorama with the horizon in the middle for a sky, an aerial or eye-level view for a map.
Say where to save the images, then build from them: blender_assets generate (image to 3D) or Blender modelling,
then blender_to_roblox; skybox faces from the panorama. Ask before every generation or upload.
`,
  },
  figma: {
    title: 'Game UI designed in Figma (any AI, free Figma plan)',
    body: `
## Setup (once)
Close Figma, then in the MCP folder: npm run install-figma-plugin (adds the plugin to the Figma DESKTOP app; npm run
setup does it too). Then in a design file: Plugins > Development > "Roblox MCP Bridge" (keep its small window open).
Run it by hand once per file. After that, on Windows, this server clicks its relaunch button by itself as soon as the
file is open (about 30 s after Figma starts). Elsewhere: the "Roblox MCP Bridge" button in the file's right panel.
figma { action: "status" } must say connected: true. No Figma key, no Figma MCP server needed.
## Design a screen
1. design_refs { query: "<game style> hud" } and agree on a style with the user.
2. Write the screen as a build_ui spec (guide "ui"), then figma { action: "draw", spec } (phone: canvas: [844, 390]).
3. The user adjusts it in Figma: colors, sizes, texts, icons, pictures. They can also design from scratch.
4. They select the frame -> figma { action: "import" } builds it in StarterGui. Then test_game { device: "phone" }.
   figma { action: "read" } returns the spec without building (to add bind/action first).
## How layers become Roblox UI
- The selected frame is the whole screen (>= 800x450: positions in screen fractions) or one panel (smaller: centered).
- Frames/rectangles -> Frame (fill, opacity, corner radius, stroke, linear gradient). Ellipses -> round frames.
- Texts -> TextLabel (color, max size, closest Roblox font: Gotham, BuilderSans, FredokaOne, LuckiestGuy, Bangers, Roboto...).
- A layer named "... Button" (or with an action) -> TextButton; its one text layer becomes the button text.
- Pictures, icons and vectors -> ImageLabel + a PNG file. Ask the user, then in Studio: select it > Properties > Image > Add Image...
- Auto layout -> UIListLayout (gap, padding). Hidden layers start hidden (windows opened by buttons).
- Behaviour in layer names: "Shop [toggle:ShopWindow]", [open:X], [close:X], [remote:EventName], [showIf:state:RoundActive],
  [bar:stat:XP/stat:XPNextLevel]. Live text: write "💰 {stat:Coins}" in the text layer.
## The official Figma MCP
Claude Code, Claude Desktop, Cursor, VS Code and Codex can also add Figma's own server (https://mcp.figma.com/mcp):
it can create designs in Figma. Figma refuses other apps (OpenCode, Qoder...), and on the free plan its read tools
are limited to a few calls a month: the plugin above works everywhere, without limit.
`,
  },
  vfx: {
    title: 'Visual effects (make_vfx, VFX Studio, Util.vfx)',
    body: `
Every hit, pickup, purchase, level up and teleport deserves an effect (and a sound: make_sound).
## 1. Ready-made, no upload: make_vfx { preset, name, color }
Presets: ${Object.keys(VFX_PRESETS).map((id) => `${id} (${VFX_PRESETS[id].about.replace(/\.$/, '')})`).join('; ')}.
Looping ones can run on a part straight away: make_vfx { preset: "fire", name: "TorchFire", parent: "Workspace/GameKit/Torch" }.
## 2. Polished custom effect: VFX Studio (free Studio plugin: texture and mesh library, emitter tools)
design_refs { query: "fireball" } -> show the references -> make_vfx { action: "plugin", parent: "<part>" } -> the user
builds and inserts the effect, then selects it -> make_vfx { action: "collect", name: "Fireball" }.
## 3. Play it from any script
\`\`\`lua
local Util = require(game:GetService("ReplicatedStorage").GameKit.Util)
Util.vfx("SwordHit", hitPart)        -- a part, a model, an attachment or a Vector3
Util.vfx("Shield", character, 5)     -- a looping effect for 5 seconds
\`\`\`
Personal feedback (UI click, own pickup): call it in a LocalScript. Everyone must see it: call it on the server.
Burst emitters use the attributes EmitCount (particles) and EmitDelay (seconds): tune them in the Properties panel.
Fine tuning: find_tools "particle" (particle_tune). Hits under 1 s; few looping effects on phones (optimize_game checks).
`,
  },
  reference: {
    title: 'Copy a picture (concept art, a game screenshot) into Roblox: everything in Blender first',
    body: `
The picture IS the target: no template look, no populate_world themes, nothing the picture does not show.
Order: picture -> plan -> the whole scene in Blender -> compare in Blender -> export -> gameplay in Roblox -> compare.
## 1. The picture first
The user sends it before anything else. Tools need it on disk: ask for its absolute path, or ask the user to
save it (e.g. <project>/png/ref.png).
## 2. Plan (game_notes decisions)
- Camera of the picture (aerial, eye level, side). Picture center = origin, top of the picture = north.
- EVERY visible element: name, position, size, color + material, and DECOR (only looks) or GAMEPLAY (players use
  it: spawn, eggs to hatch, portals, shops, gates, leaderboards).
- Sizes: studs x 0.28 = meters. Character 5 studs, road 20-30 studs (6-8 m), house ~20 x 25 x 20 studs.
## 3. Build the WHOLE scene in Blender
blender_status first. Not connected: ask the user to open Blender and click Connect (N > MCP for Blender); never
fall back to plain Roblox parts.
- blender_python in small steps, in meters: ground at Z = 0, picture center at the origin, north = +Y.
- Two collections: "Decor" (ground, plaza, roads, buildings, trees, lamps, statues...) and "Gameplay" (one object per
  thing players use, clearly named: Egg_Pink, Portal_Cyan, Shop_1, Spawn).
- Real shapes, not boxes: bevels, cylinders, spheres, lathe profiles (bmesh.ops.spin), smooth shading. One material
  per object, the colors of the picture.
- Hero objects (statue, characters, eggs, portals): model them, or blender_assets search, or generate from a Gemini
  4-view sheet of the object ("Isolate the <object> from this image as a 3D game asset sheet: front, side, back and
  3/4 views, plain white background, even lighting, same colors and style"; ask before generating: it uploads).
  With that sheet, blender_image_to_3d builds the object measured against its views (guide "image3d").
- Stays in Roblox: big natural relief and water (mountains, lakes, rivers: set_environment features, guide "map"),
  sky and lighting (set_environment). Roblox water and huge ground work better as Terrain than as meshes.
## 4. Compare in Blender, before any export
blender_scene { screenshot: true, reference: "<picture path>", view: "aerial" } renders the scene next to the picture.
List the differences (missing, wrong place, size, shape, color), fix the biggest, look again. Export only when it matches.
## 5. Export to Roblox (ask the user first: it uploads meshes to their account)
- start_job { tool: "blender_to_roblox", arguments: { name: "Map", objects: ["Decor"], merge: true, keepLayout: true } }:
  one mesh per material, placed exactly where it is in Blender.
- start_job { tool: "blender_to_roblox", arguments: { name: "GameplayModels", objects: ["Gameplay"], keepLayout: true } }:
  one part per object, names kept.
## 6. Gameplay in Roblox (what Blender cannot do)
- For each Gameplay object, build_world the matching piece at the same place (spawn, egg_stand, teleporter,
  shop_stand, zone_gate, leaderboard) and set its parts to Transparency 1, so the Blender model stays the look.
- set_environment for sky, time of day and terrain features. test_game until PASS.
## 7. Compare in Roblox
look_at_game { reference: "<picture path>" }: fix what still differs (often lighting), then test_game.
## Teach it your own good builds
export_build { instancePath } saves a model you like (yours, a Creator Store model, an uncopylocked place) to the
build library; list_library and import_scene reuse it in later games (find_tools "build"). Never copy another
creator's game.
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
textAlign: "left" | "right" for labels. Designing a real screen? Draw this spec in Figma and import it back (guide "figma").
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
- From pictures, modelled and measured against them (best quality, no AI service): blender_image_to_3d, guide "image3d".
- By code: blender_python with bpy, in small steps. Model in METERS (door 2 m, character 1.8 m), base at Z = 0,
  one material per mesh, < 20k triangles per mesh, textures <= 1024 px.
- Check it: blender_scene { screenshot: true, view: "front" } (a render; add reference: "<picture path>" to compare).
## Send it to the game
- blender_to_roblox { name, objects: ["MyProp"], position: [x, y, z] }: exports (auto-reduces heavy meshes),
  uploads (needs ROBLOX_OPEN_CLOUD_API_KEY + ROBLOX_CREATOR_USER_ID), inserts at real size (1 m = 3.57 studs) on the ground.
- It takes 30 s - 2 min: use start_job { tool: "blender_to_roblox", arguments: {...} } and keep working.
- More options: parent (default Workspace/GameKit/Props), format (fbx | glb), maxTriangles (20000), decimate (true),
  anchored (true), collide (true), description (asset description on Roblox).
- No API key: Studio rebuilds the meshes from Blender (base colors, no textures) and saves them as Roblox meshes with the
  signed-in Studio account; upload: false = live preview, lost when the place closes. Ask the user before uploading.
  Rigged models still need the file: Home > Import 3D, then blender_to_roblox { name, existing: "Workspace/<model>" }.
- Many copies around the map: populate_world { items: [{ from: "Workspace/GameKit/Props/<name>", count: 10, size: [6, 10] }] }.
## Characters and animations
- Rig in Blender (armature + weights, max 4 bones per vertex, < 100 bones). blender_to_roblox exports mesh + armature
  and gives the model an Animator.
- Each Blender action -> blender_animation { rig: "<model path>", action: "Walk", priority: "Movement" }:
  a KeyframeSequence in ServerStorage/GameKit/Animations with a temporary id to test in Studio, plus an animated FBX.
- Publish it (right-click the KeyframeSequence > Save to Roblox), use the new id, then check_assets { ids: [id] }.
`,
  },
  image3d: {
    title: 'From reference images to a game-ready model, measured (blender_image_to_3d)',
    body: `
For anything copied from pictures: statues, characters, creatures, eggs, buildings, vehicles, props, map pieces.
Instead of modelling by eye, every phase ends with renders compared to the picture with numbers (silhouette IoU,
widths at 10 heights) and is fixed until it is inside the tolerance. No detail before the silhouette passes.
It runs in a background Blender: the scene open in the user's Blender is only touched by "load".
All paths absolute. Each script lists its options with args: ["--help"].
## 0. Pictures and brief
- Best input: a 4-view sheet on white (front, side, back, 3/4) from Gemini (guide "design", ask first), or separate
  orthographic views. Measure only from orthographic views; a perspective concept or a photo gives silhouette and
  detail, not proportions. Only one perspective picture? Ask the user for the 4-view sheet BEFORE the blockout.
- Picture not on plain white or transparent (a viewport screenshot, a photo, a grid, labels, a dark background)?
  run { script: "make_matte", args: ["--ref", "<asset>/ref/concept.png", "--out", "<asset>/ref/concept_matte.png"] }
  and use the matte everywhere (compose_review --ref, world_gate and fit_camera --matte). Without it the numbers mean
  nothing: a correct chest, dark brown on a dark grey background, scored IoU 0.27 instead of 0.90.
- Asset folder, e.g. <project>/Assets/PR_Egg/ with ref/: crop each view of a sheet into ref/front.png, ref/side.png,
  ref/back.png (same scale, same ground line). Prefixes: CH_ character, CR_ creature, AR_ architecture, VH_ vehicle,
  PR_ prop, WP_ weapon, EN_ environment.
- Write <asset>/asset-brief.md (format: blender_image_to_3d { action: "guide", topic: "skill" }, Phase 0): views and
  camera angles, real size in METERS (studs x 0.28: character 1.8 m, door 2 m), 8-15 proportions to check, parts,
  materials, what the pictures do not show (inferred), the triangle budget. Category advice: topic "categories".
  build warns while the brief is missing.
## 1. Master file
run { script: "init_master", args: ["--out", "<asset>/PR_Egg_master.blend", "--name", "PR_Egg", "--height", "1.2",
  "--ref-front", "<asset>/ref/front.png", "--ref-right", "<asset>/ref/side.png", "--subject-frac", "0.9", "--ground-frac", "0.05"] }
subject-frac: share of the image height the object fills; ground-frac: height of its base above the image bottom.
## 2. Blockout, then the gate
build { master, phase: "02_blockout", code: "def build(scene, args):\\n    body = own(sphere(\\"PR_Egg_Body_LOD0\\", 0.4, location=(0, 0, 0.6), scale=(1, 1, 1.5)))" }
Primary masses only, meters, base at Z = 0, facing -Y, in collection LOW, every object wrapped in own(...) so a rebuild
replaces it. A comment on each constant: the view it was measured in, or # inferred. Helpers: topic "template".
Gate:
- run { script: "review_render", args: ["--blend", master, "--out", "<asset>/review/02", "--views", "front,side,threequarter",
  "--mode", "clay", "--gameplay-px", "128"] } (front and side are orthographic; for a concept or photo add
  "--ref-cam", AZ, EL, LENS of its camera: it renders clay_ref.png). Do not guess that camera: once the blockout is
  roughly right, run { script: "fit_camera", args: ["--blend", master, "--matte", <matte>, "--out", "<asset>/review/camera"] }
  (~30 s) and use its ref_cam. A Blender viewport screenshot is about 24 mm, not 50.
- run { script: "compose_review", args: ["--ref", "<asset>/ref/front.png", "--render", "<asset>/review/02/clay_front.png",
  "--out", "<asset>/review/02/compare_front.png", "--measure", "--gameplay-px", "128"] } for every view. The sheet
  shows REF | RENDER | OVERLAY | GAMEPLAY size.
- Pass: IoU >= 0.85, every band width within 0.05, the brief's proportions within 5%. Otherwise write the misses as
  numbers ("top 12% too narrow", "0.1 m too short"), fix the constants, build again, render again.
- compose_review aligns the two outlines, so it cannot see a model that is too small or off-center: on orthographic
  sheets also run world_gate (topic "skill", gate protocol). Show the sheet to the user before the next phase.
## 3. Forms, 4. topology
- 03_forms: secondary then fine forms, parts in their real overlap order. Gate: IoU >= 0.90, bands within 0.03,
  proportions within 2%, plus "--turntable", "8". List every part of the picture first (plates, rivets, handles,
  lock...) and compare the material render side by side, not only the numbers: the silhouette misses inner details.
- Hard-surface details come from the detail kit, already in every build script (topic "template", detailKit):
  hex_bolt / bolt_grid / bolt_row, metal_plate (with bolts), corner_cap (feet, corner plates), plank_stack (boards
  with real gaps), arch_points + prism (lids) + strap (bands), tube (pipes, rings), padlock, ring_handle, then
  merge(name, parts, material) and tri_count(objects) for the log. Faces: "-Y" front, "+Y" back, "+X"/"-X", "+Z".
- Detail gate: render "--mode", "material" from the reference camera (fit_camera's ref_cam, never blender_scene's iso
  view: another camera exaggerates every difference) and run compose_review with "--detail". It cuts both images into
  a grid (r1 c1 = top left) and flags the cells where the reference has more detail (red: missing bolts, grooves,
  plates) or another colour (blue: a part missing or in the wrong place). Fix the flagged cells, render, check again.
  Many red or blue cells down one side usually mean wrong proportions (the chest was too wide), not missing parts.
- Budget by detail level, set in the brief: plain blocky props 1-1.5k triangles, props with metalwork (bolts,
  chamfers) 2.5-3.5k. Run validate with "--budget-tris" at the end of 03_forms: bolts and chamfers add up fast.
  Chamfer what catches the light (boards, big plates, the lock); leave faces nobody sees without bolts.
- Roblox makes one MeshPart per mesh: merge the parts into one mesh per material and per moving part, keep what
  opens (lid, door) separate with set_origin on its hinge.
- 04_topology: the LOW meshes that go to Roblox, then run { script: "validate", args: ["--blend", master,
  "--out", "<asset>/review/04_validate.json", "--budget-tris", "5000"] } (exit 1 = a FAIL to fix). Roblox: < 20k
  triangles per mesh (props 1-5k, characters 5-15k). Skip LOD1/LOD2: Roblox makes its own.
## 5. Materials and textures
Cartoon or stylised pictures: metallic 0 (blender_to_roblox turns metallic > 0.5 into Roblox Metal, which darkens a
bright gold), colors as in the picture.
One material per mesh where possible (Roblox splits a mesh per material). LOW meshes need UVs first (smart_uv in the
build code); a normal map needs a HIGH sculpt to bake from. Bake at 1024 px (Roblox's limit), slow: start_job.
run { script: "bake_maps", args: ["--blend", master, "--res", "1024", "--maps", "normal,basecolor,roughness,metallic",
  "--out", "<asset>/textures", "--match-by-name", "--rebuild-material", "--save", "<asset>/PR_Egg_baked.blend"] }
Gate: review_render "--mode", "material", "--turntable", "12" on the baked file. Textures reach Roblox only with an
Open Cloud key (FBX upload); without one Studio keeps the base colors.
## 6-8. Rig and animation (characters, creatures)
Topic "rigging". Roblox: at most 4 bone weights per vertex, under 100 bones. Animations: blender_animation after the import.
## 9. Into the game
load { master: "<asset>/PR_Egg_baked.blend" (or the _master) } puts LOW (+ RIG_DEF) into the open Blender, in a
collection named after the asset (a reload replaces it and keeps where you moved it). The scene may already hold a
map: move the new collection to a free spot with blender_python. blender_scene { object: "PR_Egg", screenshot: true,
reference: "<asset>/ref/front.png" }, then, with the user's OK (it uploads):
start_job { tool: "blender_to_roblox", arguments: { name: "PR_Egg", objects: ["PR_Egg"] } }.
## Maps
Each landmark and kit piece (AR_ / EN_: wall, arch, tower, bridge, rock set...) goes through the gates on its own,
kit pieces on one grid cell (init_master "--cell"). Then load each one, place them with blender_python (meters,
north = +Y), compare the whole map with the aerial picture (blender_scene { screenshot: true, reference, view: "aerial" })
and send it with blender_to_roblox { keepLayout: true, merge: true } (guide "reference").
## Rules
Measure, then model. Renders are the evidence, not the viewport. Never present a guessed back or underside as fact:
list it as inferred.
`,
  },
  map: {
    title: 'Making a map: layout first, then terrain, gameplay, decoration',
    body: `
## 1. Plan on paper (game_notes)
Draw the map as a top view in studs: spawn/lobby in the middle or at one edge, 3-5 areas around it, the routes
between them, landmarks visible from far (a mountain, a tower, a lake). Players walk ~16 studs/s: 200 studs = 12 s.
Keep gameplay areas flat; put relief at the edges and between areas so they read as separate places.
## 2. Terrain in ONE call
set_environment { removeBaseplate: true, terrain: "flat", terrainSize: 1024, preset: "day", features: [
  { type: "mountain", at: [-300, -250], radius: 140, height: 120 },
  { type: "hill", at: [220, 180], radius: 80, height: 20 },
  { type: "lake", at: [150, -120], radius: 50, depth: 10 },
  { type: "river", points: [[-400, 0], [-100, 40], [150, -120]], width: 16 },
  { type: "plateau", at: [0, 0], size: [140, 140], height: 0 },
  { type: "road", points: [[0, 0], [220, 180]], width: 12 },
  { type: "path", points: [[0, 0], [-250, -200]], material: "Cobblestone" },
  { type: "paint", at: [150, -60], size: [60, 30], material: "Sand" } ] }
Mountains get snow above 60 studs, lakes a sand shore, roads follow the ground, plateau height 0 flattens a spot.
Order matters: relief first, then lakes/rivers, then plateaus, then roads and paint on top.
Terrain only from the base: "island" is a whole map in the sea, "hills" is random rolling ground.
## 3. Gameplay on top
create_game / build_world pieces at the planned spots (y = ground level, + height of a plateau).
## 4. Decorate and check
populate_world by theme around (not on) the routes, Blender/Creator Store models for landmarks.
look_at_game { views: ["aerial"] } must match the plan; test_game { device: "phone" } for frame rate on big maps.
Zone ambience: make_sound { loop: true } + code_recipe area_music.
`,
  },
  sound: {
    title: 'Custom sound effects with Mirelo AI (make_sound)',
    body: `
Every action deserves a sound: pickups, buys, jumps, hits, doors, UI clicks, plus ambience per zone.
## Prompts that work
Source + material + action + space + length/feel: "wooden crate breaking on stone floor, short punchy",
"soft bright coin pickup chime, cartoon", "wind through pine forest with distant birds, calm loop".
One sound per prompt, no music words in an effect. Ambience and music beds: loop: true, 10-30 seconds.
## Automatic (MIRELO_API_KEY)
make_sound { prompt, name: "CoinPickup", seconds: 1, parent: "Workspace/GameKit/Coin" }
-> generates (Mirelo credits, about 10 per second of audio), uploads to Roblox (ROBLOX_OPEN_CLOUD_API_KEY +
ROBLOX_CREATOR_USER_ID, ID-verified account, 100 audio uploads per month), puts the Sound on the part (3D, heard
within 80 studs) or in SoundService (global/UI). Ask the user before uploading. upload: false = file only.
New audio may need a few minutes of moderation: check_assets { ids: [id] } before relying on it.
## Free, no key: the Mirelo Studio plugin
1. make_sound { action: "plugin", prompt, parent: "<part the sound belongs to>" }: selects that part (the plugin
   reads its material, size and physics) and returns the steps for the user.
2. The user clicks Generate in Plugins > Mirelo AI SFX Generation (signs in once). The sound lands in SoundService.
3. make_sound { action: "collect", parent, name } moves the new Sound onto the part.
## Play it
- Server event (door, explosion, coin): the Sound on the part, sound:Play() in the server script.
- UI click or personal feedback: Sound in SoundService, SoundService:PlayLocalSound(sound) in a LocalScript.
- Zone ambience: code_recipe area_music with the new id.
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
