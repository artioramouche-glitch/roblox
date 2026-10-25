# AGENT.md — Roblox Ultimate MCP

> Instructions for AI agents (Claude, GPT/Codex, Gemini, Copilot, local models...).
> Humans: see [README.md](README.md) (French) — give this file to your AI after installing.

## 1. Install for the user (once)

Fastest (once the package is published on npm): `npx roblox-ultimate-mcp setup` installs the Studio plugin and
registers the server in Claude Desktop, Cursor, Windsurf, OpenCode, Qoder, Gemini CLI, Antigravity, VS Code, Cline,
Roo Code, Kiro, LM Studio and Codex (`--blender` also installs the Blender addon). It prints the line for other clients. Otherwise, from the repository:

```bash
git clone https://github.com/artioramouche-glitch/roblox.git
cd roblox
npm install            # also builds dist/ (prepare script)
```

Install the Studio plugin (copies `studio-plugin/MCPPlugin.rbxmx` into the Roblox plugins folder):

```bash
npm run install-plugin
```

Then ask the human to:
1. Restart Studio and open a place.
2. In Studio: Game Settings > Security > **Allow HTTP Requests** = ON.
3. Plugins tab > **MCP Server** > **Connect**.

Optional, for custom 3D models: `npm run install-blender-addon`, then ask the human to open Blender, press N >
"MCP for Blender" > "Connect to MCP server". Check with `blender_status`.

Register the server in your client (replace PATH with the clone folder). The plugin talks to `localhost:58741`.

```bash
claude mcp add roblox -- node PATH/packages/roblox-ultimate-mcp/dist/index.js          # Claude Code
gemini mcp add roblox node PATH/packages/roblox-ultimate-mcp/dist/index.js             # Gemini CLI
```
```json
{ "mcpServers": { "roblox": { "command": "node", "args": ["PATH/packages/roblox-ultimate-mcp/dist/index.js"] } } }
```

## 2. How to build a game (the golden path)

1. `roblox_start_here` — connection check, what is already installed, and the project memory (`game_notes`).
   Keep `game_notes` up to date (idea, decisions, todo, done): the next conversation resumes from it.
2. `create_game { template, options }` — templates: `obby`, `tycoon`, `simulator`, `arena`, `survival`, `horror_escape`,
   `tower_defense`, `farming`, `racing`, `fishing`, `craft_survival`. Builds scripts, config, world, HUD and lighting in one call (and backs up the previous place).
3. `test_game` — automatic playtest. Fix **every** error it reports (script + line + code + hint, fix with
   `edit_script`), then run it again until `PASS`.
4. Customise **without code**:
   - `add_system { system, config }` — settings live in `ReplicatedStorage/GameKit/Config/<System>`.
     Retention systems: `inventory`, `levels`, `quests` (chain = tutorial; `Target` = guide arrow), `pets` (eggs).
     Growth systems: `codes` (redeem codes), `social` (friend boost, invite button, group bonus).
   - `build_world { kind, options }` — whole worlds (`obby_course`, `maze`, `arena`...) or pieces (`jump_pad`, `coin`, `spinner`...).
   - `build_ui { spec }` — JSON UI with `bind` / `bar` / `showIf` / `action` (no Luau).
   - `set_environment { preset, terrain }` — lighting mood and terrain.
   - `populate_world { theme | items, zone }` — scenery snapped to the ground, never blocking gameplay.
   - `look_at_game` — screenshots from several angles: LOOK at what you built and fix what looks wrong.
   - `balance_economy { fromGame: true }` — progression simulation + suggested prices.
5. Custom code (read `roblox_guide coding`):
   - First `code_recipe` (verified scripts from params: touch_reward, prompt_action, door, timed_spawner, npc_dialog,
     ui_button_remote, badge_award, chat_command...). `code_recipe {}` lists them.
   - New script: `write_script`. Change: `edit_script { path, find, replace }` (never rewrite a whole script).
     Both auto-fix JS/Python habits and refuse broken code or invented Roblox APIs (they suggest the right name).
   - Understand existing code: `code_outline`, then `read_script { path, find }` (only the lines you need).
   - Reuse PlayerData / Net / Util / UIKit (`roblox_guide gamekit-api`).
6. Finish with `check_game` (static audit) and a last `test_game`. Before publishing: `test_game { players: 2 }`
   (multiplayer), `test_game { device: "phone" }` (phone screen + UI checks), `check_assets` (sounds/animations really
   load), `optimize_game` (low-end phones; `apply` for safe fixes), then `publish_checklist`.

Every GameKit change is one undo step named "MCP: AI <tool>": the human can revert your last action from the
plugin's AI panel.

Safety and speed: `backup_game { action: "save" }` before risky changes (`restore` to undo). Slow tools run in the
background with `start_job { tool, arguments }` + `job_status { id, wait: 30 }`.

## 2b. Blender (custom 3D models)

`blender_status` → model with `blender_python` (meters, base at Z = 0, < 20k triangles, 1 material per mesh) or get a
model with `blender_assets` (Poly Pizza, Sketchfab, Poly Haven, Hyper3D/Hunyuan3D generation from text or from
reference `images`: absolute image paths or URLs; hunyuan3d takes exactly one) → `blender_scene
{ screenshot: true }` → `blender_to_roblox { name, position }` (needs ROBLOX_OPEN_CLOUD_API_KEY + ROBLOX_CREATOR_USER_ID;
without them it exports the file for a manual Import 3D, then `blender_to_roblox { name, existing }`). Read
`roblox_guide blender`.

Maps: lay out the map in studs first, then ONE `set_environment { terrain, features: [mountain, hill, lake, river,
road, path, plateau, paint] }` call shapes the terrain where the plan says (`roblox_guide map`). Sounds: `make_sound
{ prompt, name, parent }` (Mirelo API, needs MIRELO_API_KEY + Open Cloud key) or `make_sound { action: "plugin" }`
then `{ action: "collect" }` with the free Mirelo Studio plugin (`roblox_guide sound`). Ask before uploading.

Rigged characters: `blender_to_roblox` exports the armature with the mesh (max 4 weights per vertex, < 100 bones) and
adds an Animator. Then `blender_animation { rig: "<model path>", action: "Walk", priority: "Movement" }` for each
Blender action: KeyframeSequence in `ServerStorage/GameKit/Animations`, temporary id to test in Studio, animated FBX
as a fallback (Animation Editor > Import > From FBX Animation).

## 2b'. Design: references, Figma UI, effects

- Before any visual design: `design_refs { query }` searches the local "roblox-ai" picture library (UI styles, VFX,
  thumbnails by genre; `ROBLOX_REFS_DIR` if it is not in Downloads). `show: true` attaches the first pictures.
- UI screens: `figma { action: "draw", spec }` (a build_ui spec) puts a mockup in Figma, the human adjusts it, then
  `figma { action: "import" }` builds the selected frame in StarterGui. Needs the "Roblox MCP Bridge" development
  plugin running in the Figma desktop app (import `figma-plugin/manifest.json` once). Works from any MCP client and on
  the free Figma plan. Read `roblox_guide figma`.
- Effects: `make_vfx { preset }` (hit_spark, sparkle, explosion, fire, smoke_puff, heal_aura, level_up, magic, portal,
  dust, celebration) saves a template in `ReplicatedStorage/GameKit/Effects`; scripts play it with
  `Util.vfx("Name", part)`. Polished effects: `make_vfx { action: "plugin" }` (free VFX Studio plugin), then
  `{ action: "collect", name }`. Read `roblox_guide vfx`.

## 2c. Several AIs on one game

Read `roblox_guide team`. Lead: `team { action: "plan", goal }`. Everyone: pick a unique `agent` name, then
`team claim` → work → `team done`. Reserve map space with `team claim_zone` and build inside it
(`build_world { zone }`, `populate_world { zone }`). Don't run `test_game` while others edit.

## 3. Rules

- Server logic (money, damage, saving) → Script in ServerScriptService. Input/UI/camera → LocalScript in StarterPlayerScripts/StarterGui.
- Never trust the client: it sends *what* it wants (`Net.send("Buy", "Sword")`), the server decides and checks the price.
- `task.wait()` not `wait()`. Every `while true do` loop needs a `task.wait()`.
- Stats and saving: `PlayerData` (never raw DataStore code). Clients read stats with `player:GetAttribute("Coins")`.
- Anchor static parts. Positions are part centers, in studs, Y up.
- Don't invent APIs; read `roblox_guide luau`, `client-server`, `errors` when unsure.

## 4. Tool profiles and the 140+ Studio tools

Default profile `starter` lists 46 of the 186 tools (`builder` 106). Everything else is still callable:
`find_tools { query }` then `call_tool { name, arguments }`, or `set_tool_profile { profile: "builder" | "full" }`.
Useful families: terrain_*, lighting_*, animation_*, particle_*, sound_*, material_*, insert_asset / search_assets
(needs an Open Cloud key), capture_screenshot, simulate_*_input, character_navigation, eval_server_runtime /
eval_client_runtime (live game VM), get_runtime_logs, multiplayer_playtest, set_device_simulator, profilers,
breakpoints, export_rbxm / import_rbxm, source_pull / source_push, get_roblox_docs.

## 5. Guides available through the server

`roblox_guide` topics: workflow, coding, design, figma, vfx, reference, luau, client-server, data, ui, building, testing, errors, blender, team,
localization, publishing, performance, gamekit-api, catalog, and every system/template id. Also exposed as MCP
resources `gamekit://...` and prompts `make_game`, `fix_my_game`, `add_feature`, `polish_game`, `team_build`,
`blender_prop`, `copy_image`.

Full reference: [docs/GAMEKIT.md](docs/GAMEKIT.md).
