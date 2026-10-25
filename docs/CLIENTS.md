# Brancher n'importe quel client MCP

Le serveur utilise le transport **stdio** : tout client MCP capable de lancer une commande locale fonctionne.

**Le plus simple** : `npm run setup` (depuis le dossier) ou `npx roblox-ultimate-mcp setup` (une fois publié) configure
tout seul Claude Desktop, Cursor, Windsurf, OpenCode, Qoder, Gemini CLI, Antigravity, VS Code, Cline, Roo Code, Kiro,
LM Studio et Codex, et affiche la ligne pour les autres. La commande à donner à un client est alors :

```
npx -y roblox-ultimate-mcp@latest          (Windows : "command": "cmd", "args": ["/c", "npx", "-y", "roblox-ultimate-mcp@latest"])
```

**Depuis le dépôt** : remplace `CHEMIN` par le dossier où tu as cloné le dépôt (après `npm install`). Commande universelle :

```
node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

Variables d'environnement utiles :

| Variable | Effet |
|---|---|
| `ROBLOX_MCP_PROFILE` | `starter` (défaut, 46 outils), `builder` (106), `full` (186) |
| `ROBLOX_REFS_DIR` | Dossier de la bibliothèque d'images « roblox-ai » pour `design_refs` (défaut : cherchée dans Téléchargements) |
| `ROBLOX_MCP_COMPACT` | `0` : descriptions d'outils complètes (par défaut, version courte pour économiser les tokens) |
| `ROBLOX_MCP_PRETTY` | `1` : réponses JSON indentées (par défaut compactes) |
| `ROBLOX_MCP_HISTORY` | `0` : ne pas noter les changements de l'IA dans l'historique de `game_notes` |
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

`npm run setup` (ou `npx roblox-ultimate-mcp setup`) le configure tout seul. À la main :
`~/.config/opencode/opencode.json` (Windows : `C:\Users\<toi>\.config\opencode\opencode.json`) :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "roblox": { "type": "local", "enabled": true, "command": ["node", "CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"] }
  }
}
```

## Qoder (application et `qodercli`)

`npm run setup` l'écrit dans `~/.qoder/settings.json` (Windows : `C:\Users\<toi>\.qoder\settings.json`), le fichier
utilisateur lu par l'application Qoder et par `qodercli`. À la main : Qoder → Settings → MCP → My Servers → **+ Add** :

```json
{ "mcpServers": { "roblox-ultimate": { "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"] } } }
```

## Antigravity

`~/.gemini/config/mcp_config.json` (même bloc `mcpServers`), écrit par `npm run setup`.

## N'importe quel modèle (DeepSeek, Qwen, Kimi, GLM, local…)

Le modèle ne change rien au branchement : c'est l'application (OpenCode, Qoder, Cline…) qui parle au serveur. Conseils
pour les modèles plus faibles :
- garde le profil `starter` (46 outils) : moins de choix, moins d'erreurs ;
- commence chaque conversation par « Appelle roblox_start_here » (certaines applis ne transmettent pas les
  instructions du serveur au modèle) ;
- demande-lui de suivre `roblox_guide workflow` et de relancer `test_game` jusqu'à PASS.

## Figma (pour toutes les applis)

Le serveur parle directement au plugin Figma « Roblox MCP Bridge » (dossier `figma-plugin/`) : rien à ajouter dans
l'appli d'IA. Application Figma (bureau) → *Plugins → Development → Import plugin from manifest…* →
`figma-plugin/manifest.json`, puis lance le plugin dans ton fichier. Outil : `figma` (`status`, `draw`, `read`, `import`).

Le MCP officiel de Figma (`https://mcp.figma.com/mcp`) n'accepte que certaines applis (Claude Code, Claude Desktop,
Cursor, VS Code, Codex) : OpenCode et Qoder sont refusés (erreur 403 à la connexion). En plan gratuit, sa lecture est
limitée à quelques appels par mois. Pour Claude Code :
`claude mcp add --transport http figma https://mcp.figma.com/mcp`.

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
(`npx roblox-ultimate-mcp setup --blender` ou `npm run install-blender-addon`, puis **N → MCP for Blender → Connect
to MCP server** dans Blender).
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

1. ✅ Studio ouvert, plugin **MCP Server → Connect** actif (le bouton **AI Panel** montre ensuite ce que fait l'IA)
2. ✅ **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP**
3. ✅ Le client affiche le serveur `roblox` comme connecté
4. ✅ L'outil `roblox_start_here` renvoie `"connected": true`

```bash
curl http://localhost:58741/health
```

Attendu : `pluginConnected: true`, `mcpServerActive: true`.

> Windows : si `node` n'est pas trouvé par le client, mets le chemin complet
> (ex. `"command": "C:/Program Files/nodejs/node.exe"`).
