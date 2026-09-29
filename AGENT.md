# AGENT.md — Roblox Ultimate MCP

> Instructions for AI agents (Claude, GPT/Codex, Gemini, Copilot, local models...).
> Humans: see [README.md](README.md) (French) — give this file to your AI after installing.

## 1. Install for the user (once)

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

1. `roblox_start_here` — connection check + what is already installed.
2. `create_game { template, options }` — templates: `obby`, `tycoon`, `simulator`, `arena`, `survival`, `horror_escape`,
   `tower_defense`, `farming`. Builds scripts, config, world, HUD and lighting in one call (and backs up the previous place).
3. `test_game` — automatic playtest. Fix **every** error it reports (script + line + hint), then run it again until `PASS`.
4. Customise **without code**:
   - `add_system { system, config }` — settings live in `ReplicatedStorage/GameKit/Config/<System>`.
   - `build_world { kind, options }` — whole worlds (`obby_course`, `maze`, `arena`...) or pieces (`jump_pad`, `coin`, `spinner`...).
   - `build_ui { spec }` — JSON UI with `bind` / `bar` / `showIf` / `action` (no Luau).
   - `set_environment { preset, terrain }` — lighting mood and terrain.
   - `populate_world { theme | items, zone }` — scenery snapped to the ground, never blocking gameplay.
   - `look_at_game` — screenshots from several angles: LOOK at what you built and fix what looks wrong.
   - `balance_economy { fromGame: true }` — progression simulation + suggested prices.
5. Custom code: **only** with `write_script` (validates Luau with the real compiler + a beginner linter).
   Check snippets with `check_luau` first. Read `roblox_guide gamekit-api` to reuse PlayerData / Net / UIKit.
6. Finish with `check_game` (static audit) and a last `test_game`; `publish_checklist` before publishing.

Safety and speed: `backup_game { action: "save" }` before risky changes (`restore` to undo). Slow tools run in the
background with `start_job { tool, arguments }` + `job_status { id, wait: 30 }`.

## 2b. Blender (custom 3D models)

`blender_status` → model with `blender_python` (meters, base at Z = 0, < 20k triangles, 1 material per mesh) or get a
model with `blender_assets` (Poly Pizza, Sketchfab, Poly Haven, Hyper3D/Hunyuan3D generation) → `blender_scene
{ screenshot: true }` → `blender_to_roblox { name, position }` (needs ROBLOX_OPEN_CLOUD_API_KEY + ROBLOX_CREATOR_USER_ID;
without them it exports the file for a manual Import 3D, then `blender_to_roblox { name, existing }`). Read
`roblox_guide blender`.

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

Default profile `starter` lists 35 of the 174 tools (`builder` 94). Everything else is still callable:
`find_tools { query }` then `call_tool { name, arguments }`, or `set_tool_profile { profile: "builder" | "full" }`.
Useful families: terrain_*, lighting_*, animation_*, particle_*, sound_*, material_*, insert_asset / search_assets
(needs an Open Cloud key), capture_screenshot, simulate_*_input, character_navigation, eval_server_runtime /
eval_client_runtime (live game VM), get_runtime_logs, multiplayer_playtest, set_device_simulator, profilers,
breakpoints, export_rbxm / import_rbxm, source_pull / source_push, get_roblox_docs.

## 5. Guides available through the server

`roblox_guide` topics: workflow, design, luau, client-server, data, ui, building, testing, errors, blender, team,
localization, publishing, performance, gamekit-api, catalog, and every system/template id. Also exposed as MCP
resources `gamekit://...` and prompts `make_game`, `fix_my_game`, `add_feature`, `polish_game`, `team_build`,
`blender_prop`.

Full reference: [docs/GAMEKIT.md](docs/GAMEKIT.md).
