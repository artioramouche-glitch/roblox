# Intégrations

## `blender-mcp/`

Copie de [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp) v1.9.1 (licence MIT, voir `LICENSE`).

| Fichier | Utilisé par Roblox Ultimate MCP ? |
|---|---|
| `addon.py` | **Oui** : l'addon à installer dans Blender (`npm run install-blender-addon`). Il ouvre un socket local (port 9876) auquel les outils `blender_*` se connectent directement. |
| `src/blender_mcp/safe_mode.py` | Oui, seulement si `BLENDER_MCP_SAFE_MODE=1` : valide les scripts `blender_python` (Python requis). |
| `src/blender_mcp/server.py` et le reste | Non : c'est le serveur MCP Python d'origine. Inutile avec Roblox Ultimate MCP (et il envoie de la télémétrie par défaut). Gardé pour référence et pour ceux qui veulent l'utiliser seul (`uvx blender-mcp`). |

Protocole de l'addon : une commande JSON `{"type": "...", "params": {...}}` par message, réponse
`{"status": "success", "result": ...}` ou `{"status": "error", "message": "..."}`. Le client TypeScript est dans
`packages/core/src/gamekit/blender.ts`.

Pour mettre à jour : remplace le dossier par la nouvelle version de blender-mcp (sans `build/` ni `*.egg-info`), puis
`npm test` (un faux addon TCP vérifie le protocole).
