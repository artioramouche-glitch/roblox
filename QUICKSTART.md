# Démarrage rapide

## Installation (une seule fois)

1. Installe [Node.js](https://nodejs.org) 18+.
2. Dans un terminal :
   ```bash
   git clone https://github.com/artioramouche-glitch/roblox.git
   cd roblox
   npm install
   ```
3. Copie `studio-plugin/MCPPlugin.rbxmx` dans le dossier des plugins Roblox
   (Windows : `%LOCALAPPDATA%\Roblox\Plugins\` — macOS : `~/Documents/Roblox/Plugins/`) et redémarre Studio.
4. Dans Studio : **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP**.
5. Ajoute le serveur à ton IA (voir [README](README.md#3-brancher-ton-ia)), ex. Claude Code :
   ```bash
   claude mcp add roblox -- node CHEMIN/VERS/roblox/dist/index.js
   ```

## À chaque session

1. Ouvre Studio avec ton jeu.
2. Onglet **Plugins → MCP Server → Connect**.
3. Parle à ton IA :
   - « Crée un obby de 15 niveaux thème néon et teste-le. »
   - « Ajoute une boutique qui vend une épée et des traînées. »
   - « Le jeu a des erreurs, trouve-les et corrige-les. »
   - « Rends le jeu plus beau et plus fun. »

## Ce que l'IA fait toute seule

`roblox_start_here` → `create_game` → `test_game` → corrections → `add_system` / `build_world` / `build_ui` /
`set_environment` → `check_game`.

## Où modifier quoi dans Studio (sans code)

| Quoi | Où |
|---|---|
| Récompenses, prix, vitesses, textes | `ReplicatedStorage > GameKit > Config > <Système>` |
| Couleurs de toute l'interface | `ReplicatedStorage > GameKit > Config > Theme` |
| Le monde généré | `Workspace > GameKit` |
| Réglage d'un obstacle (puissance d'un jump pad…) | Sélectionne la pièce → Propriétés → Attributs |
| Scripts du kit | `ServerScriptService > GameKit` et `StarterPlayer > StarterPlayerScripts > GameKit` |

Tout ce que le kit installe s'annule en une fois avec **Ctrl+Z**.
