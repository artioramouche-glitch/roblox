# Brancher n'importe quel client MCP

Le serveur utilise le transport **stdio** : tout client MCP capable de lancer une commande locale fonctionne.
Remplace `CHEMIN` par le dossier où tu as cloné le dépôt (après `npm install`).

Commande universelle :

```
node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

Variables d'environnement utiles :

| Variable | Effet |
|---|---|
| `ROBLOX_MCP_PROFILE` | `starter` (défaut, 35 outils), `builder` (94), `full` (174) |
| `ROBLOX_STUDIO_PORT` | Port HTTP pour le plugin (défaut `58741`, secours `3002`) |
| `ROBLOX_OPEN_CLOUD_API_KEY` | Clé Open Cloud pour `search_assets` / `upload_asset` / `blender_to_roblox` (droits *asset:read*, *asset:write*) |
| `ROBLOX_CREATOR_USER_ID` / `ROBLOX_CREATOR_GROUP_ID` | Propriétaire des modèles envoyés (`upload_asset`, `blender_to_roblox`) |
| `ROBLOX_MCP_HOOK` | `0` coupe le lien optionnel vers le MCP officiel intégré à Studio |
| `BLENDER_HOST` / `BLENDER_PORT` | Adresse de l'addon Blender (défaut `127.0.0.1:9876`) |
| `ROBLOX_MCP_BLENDER` | `1` liste les outils `blender_*` dès le démarrage (sinon dès que Blender répond, ou en `builder`) |
| `BLENDER_MCP_SAFE_MODE` | `1` : chaque script `blender_python` est validé par `safe_mode.py` de blender-mcp (Python requis, `BLENDER_MCP_PYTHON` pour choisir l'exécutable) |

---

## Claude Code

```bash
claude mcp add roblox -- node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
# profil complet :
claude mcp add roblox -e ROBLOX_MCP_PROFILE=full -- node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

## Claude Desktop

`claude_desktop_config.json` :

```json
{
  "mcpServers": {
    "roblox": {
      "command": "node",
      "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"]
    }
  }
}
```

## Cursor / Windsurf / Cline / Roo Code / LM Studio / Jan

Même bloc `mcpServers` que Claude Desktop (fichier `mcp.json` / réglages MCP du client).

## VS Code (GitHub Copilot, mode Agent)

`.vscode/mcp.json` :

```json
{
  "servers": {
    "roblox": { "type": "stdio", "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"] }
  }
}
```

## Gemini CLI

```bash
gemini mcp add roblox node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

## Codex CLI

`~/.codex/config.toml` :

```toml
[mcp_servers.roblox]
command = "node"
args = ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"]
```

## OpenCode

`~/.config/opencode/opencode.json` :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "roblox": { "type": "local", "enabled": true, "command": ["node", "CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"] }
  }
}
```

## Édition lecture seule

Pour inspecter un jeu sans risque de modification :

```json
{ "mcpServers": { "roblox-inspector": { "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp-inspector/dist/index.js"] } } }
```

## Clients HTTP (sans stdio)

- MCP « streamable HTTP » : `http://localhost:58741/mcp` (mêmes outils, prompts et ressources).
- Appel direct d'un outil : `POST http://localhost:58741/mcp/<outil>` avec les arguments en JSON
  (ex. `/mcp/create_game` avec `{"template":"obby"}`), utile pour des scripts ou des agents maison.

## Plusieurs IA en même temps

Lance autant de clients que tu veux : la première instance possède le port, les suivantes passent en mode proxy et
partagent le même Studio. Plusieurs Studio ouverts : `list_studios` puis `set_active_studio`.

Pour qu'elles s'organisent : outil `team` (tâches + zones de carte, stockés dans le jeu) et prompt `team_build`.
Les tâches de fond (`start_job` / `job_status`) restent propres à chaque client.

## Blender

Une seule entrée MCP suffit : ce serveur parle directement à l'addon « MCP for Blender »
(`npm run install-blender-addon`, puis **N → MCP for Blender → Connect to MCP server** dans Blender).
Tu n'as **pas** besoin d'ajouter le serveur Python `blender-mcp` à ton IA (s'il tourne aussi, les deux se partagent
l'addon, une commande à la fois).

Exemple avec envoi automatique des modèles vers Roblox :

```json
{
  "mcpServers": {
    "roblox": {
      "command": "node",
      "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"],
      "env": { "ROBLOX_OPEN_CLOUD_API_KEY": "ta-cle", "ROBLOX_CREATOR_USER_ID": "123456" }
    }
  }
}
```

---

## Vérifier la connexion

1. ✅ Studio ouvert, plugin **MCP Server → Connect** actif
2. ✅ **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP**
3. ✅ Le client affiche le serveur `roblox` comme connecté
4. ✅ L'outil `roblox_start_here` renvoie `"connected": true`

```bash
curl http://localhost:58741/health
```

Attendu : `pluginConnected: true`, `mcpServerActive: true`.

> Windows : si `node` n'est pas trouvé par le client, mets le chemin complet
> (ex. `"command": "C:/Program Files/nodejs/node.exe"`).
