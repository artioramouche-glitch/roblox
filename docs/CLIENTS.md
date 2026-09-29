# Brancher n'importe quel client MCP

Le serveur utilise le transport **stdio** : tout client MCP capable de lancer une commande locale fonctionne.
Remplace `CHEMIN` par le dossier où tu as cloné le dépôt (après `npm install`).

Commande universelle :

```
node CHEMIN/dist/index.js
```

Variables d'environnement utiles :

| Variable | Effet |
|---|---|
| `ROBLOX_MCP_PROFILE` | `starter` (défaut, 25 outils), `builder` (~46), `full` (tous) |
| `ROBLOX_STUDIO_PORT` | Port HTTP pour le plugin (défaut `3002`) |

---

## Claude Code

```bash
claude mcp add roblox -- node CHEMIN/dist/index.js
# profil complet :
claude mcp add roblox -e ROBLOX_MCP_PROFILE=full -- node CHEMIN/dist/index.js
```

## Claude Desktop

`claude_desktop_config.json` :

```json
{
  "mcpServers": {
    "roblox": {
      "command": "node",
      "args": ["CHEMIN/dist/index.js"]
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
    "roblox": { "type": "stdio", "command": "node", "args": ["CHEMIN/dist/index.js"] }
  }
}
```

## Gemini CLI

```bash
gemini mcp add roblox node CHEMIN/dist/index.js
```

## Codex CLI

`~/.codex/config.toml` :

```toml
[mcp_servers.roblox]
command = "node"
args = ["CHEMIN/dist/index.js"]
```

## OpenCode

`~/.config/opencode/opencode.json` :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "roblox": { "type": "local", "enabled": true, "command": ["node", "CHEMIN/dist/index.js"] }
  }
}
```

## Clients HTTP (sans stdio)

Les outils sont aussi exposés en HTTP local : `POST http://localhost:3002/mcp/<outil>` avec les arguments en JSON
(ex. `/mcp/create_game` avec `{"template":"obby"}`), utile pour des scripts ou des agents maison.

---

## Vérifier la connexion

1. ✅ Studio ouvert, plugin **MCP Server → Connect** actif
2. ✅ **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP**
3. ✅ Le client affiche le serveur `roblox` comme connecté
4. ✅ L'outil `roblox_start_here` renvoie `"connected": true`

```bash
curl http://localhost:3002/health
```

Attendu : `pluginConnected: true`, `mcpServerActive: true`.

> Windows : si `node` n'est pas trouvé par le client, mets le chemin complet
> (ex. `"command": "C:/Program Files/nodejs/node.exe"`).
