# AGENT.md — Roblox Ultimate MCP

> Instructions for AI agents (Claude, GPT/Codex, Gemini, Copilot, local models...).
> Humans: see [README.md](README.md) (French) — give this file to your AI after installing.

## 1. Install for the user (once)

```bash
git clone https://github.com/artioramouche-glitch/roblox.git
cd roblox
npm install            # also builds dist/ (prepare script)
```

Then ask the human to:
1. Copy `studio-plugin/MCPPlugin.rbxmx` to the Studio plugins folder
   (Windows `%LOCALAPPDATA%\Roblox\Plugins\`, macOS `~/Documents/Roblox/Plugins/`) and restart Studio.
2. In Studio: Game Settings > Security > **Allow HTTP Requests** = ON.
3. Plugins tab > **MCP Server** > **Connect**.

Register the server in your client (replace PATH with the clone folder):

```bash
claude mcp add roblox -- node PATH/dist/index.js          # Claude Code
gemini mcp add roblox node PATH/dist/index.js             # Gemini CLI
```
```json
{ "mcpServers": { "roblox": { "command": "node", "args": ["PATH/dist/index.js"] } } }
```

## 2. How to build a game (the golden path)

1. `roblox_start_here` — connection check + what is already installed.
2. `create_game { template, options }` — templates: `obby`, `tycoon`, `simulator`, `arena`, `survival`, `horror_escape`.
   Builds scripts, config, world, HUD and lighting in one call.
3. `test_game` — automatic playtest. Fix **every** error it reports (script + line + hint), then run it again until `PASS`.
4. Customise **without code**:
   - `add_system { system, config }` — settings live in `ReplicatedStorage/GameKit/Config/<System>`.
   - `build_world { kind, options }` — whole worlds (`obby_course`, `maze`, `arena`...) or pieces (`jump_pad`, `coin`, `spinner`...).
   - `build_ui { spec }` — JSON UI with `bind` / `bar` / `showIf` / `action` (no Luau).
   - `set_environment { preset, terrain }` — lighting mood and terrain.
5. Custom code: **only** with `write_script` (validates Luau with the real compiler + a beginner linter).
   Check snippets with `check_luau` first. Read `roblox_guide gamekit-api` to reuse PlayerData / Net / UIKit.
6. Finish with `check_game` (static audit) and a last `test_game`.

## 3. Rules

- Server logic (money, damage, saving) → Script in ServerScriptService. Input/UI/camera → LocalScript in StarterPlayerScripts/StarterGui.
- Never trust the client: it sends *what* it wants (`Net.send("Buy", "Sword")`), the server decides and checks the price.
- `task.wait()` not `wait()`. Every `while true do` loop needs a `task.wait()`.
- Stats and saving: `PlayerData` (never raw DataStore code). Clients read stats with `player:GetAttribute("Coins")`.
- Anchor static parts. Positions are part centers, in studs, Y up.
- Don't invent APIs; read `roblox_guide luau`, `client-server`, `errors` when unsure.

## 4. Tool profiles

Default profile `starter` lists 25 tools. Need a low-level tool (tags, attributes, snapshots...)?
`find_tools { query }` then `call_tool { name, arguments }`, or `set_tool_profile { profile: "full" }`.

## 5. Guides available through the server

`roblox_guide` topics: workflow, design, luau, client-server, data, ui, building, testing, errors, publishing,
performance, gamekit-api, catalog, and every system/template id. Also exposed as MCP resources `gamekit://...`
and prompts `make_game`, `fix_my_game`, `add_feature`, `polish_game`.

Full reference: [docs/GAMEKIT.md](docs/GAMEKIT.md).
