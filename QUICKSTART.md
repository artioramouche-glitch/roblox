# Démarrage rapide

## Installation (une seule fois)

**En une commande** (dès que le paquet est publié sur npm, voir le [README](README.md#publier-sur-npm)) :

```bash
npx roblox-ultimate-mcp setup             # plugin Studio + applis d'IA configurées
npx roblox-ultimate-mcp setup --blender   # ... et l'addon Blender
```

Puis redémarre Studio et ton appli d'IA, et fais l'étape 4 ci-dessous (requêtes HTTP).

**Depuis le dépôt :**

1. Installe [Node.js](https://nodejs.org) 18+.
2. Dans un terminal :
   ```bash
   git clone https://github.com/artioramouche-glitch/roblox.git
   cd roblox
   npm install
   ```
3. Installe le plugin Studio : `npm run install-plugin` (ou copie `studio-plugin/MCPPlugin.rbxmx` dans
   `%LOCALAPPDATA%\Roblox\Plugins\` sous Windows, `~/Documents/Roblox/Plugins/` sous macOS), puis redémarre Studio.
4. Dans Studio : **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP**.
5. Ajoute le serveur à ton IA (voir [README](README.md#3-brancher-ton-ia)), ex. Claude Code :
   ```bash
   claude mcp add roblox -- node CHEMIN/VERS/roblox/packages/roblox-ultimate-mcp/dist/index.js
   ```
6. *(Optionnel, objets 3D)* `npm run install-blender-addon`, puis dans Blender : **N → MCP for Blender → Connect to MCP
   server**. Pour l'envoi automatique vers Roblox, ajoute à la config MCP `ROBLOX_OPEN_CLOUD_API_KEY` et
   `ROBLOX_CREATOR_USER_ID` (voir [docs/CLIENTS.md](docs/CLIENTS.md)).

## À chaque session

1. Ouvre Studio avec ton jeu.
2. Onglet **Plugins → MCP Server → Connect**.
3. Parle à ton IA :
   - « Crée un obby de 15 niveaux thème néon et teste-le. »
   - « Ajoute une boutique qui vend une épée et des traînées. »
   - « Le jeu a des erreurs, trouve-les et corrige-les. »
   - « Rends le jeu plus beau et plus fun. »
   - « Fais un tower defense à 20 vagues » / « Fais un jeu de ferme relaxant ».
   - « Entoure la carte d'une forêt et montre-moi le résultat. » (`populate_world` + `look_at_game`)
   - « Modélise une fontaine dans Blender et mets-la au centre du lobby. »
   - « Ajoute un PNJ qui explique le jeu, et une porte VIP à 500 pièces. » (recettes `npc_dialog`, `door`)
   - « Fais un jeu de course en karts » / « un jeu de pêche » / « une survie à plusieurs avec du craft ».
   - « Ajoute des quêtes pour guider les nouveaux joueurs, des niveaux et des œufs de familiers. »
   - « Vérifie que le jeu marche à 2 joueurs et sur téléphone, et qu'il ne rame pas. »
   - « Anime mon personnage Blender (marche et attaque) et mets-le dans le jeu. »

## Ce que l'IA fait toute seule

`roblox_start_here` → `create_game` → `test_game` → corrections → `add_system` / `build_world` / `build_ui` /
`set_environment` / `populate_world` → `look_at_game` → `check_game` → avant publication : `test_game {players: 2}`,
`test_game {device: "phone"}`, `check_assets`, `optimize_game`, `publish_checklist`.

Elle note l'idée, ses décisions et ce qui reste à faire dans `game_notes` (stocké dans le jeu) : dans une nouvelle
conversation, dis juste *« reprends le jeu »*.

## Voir ce que fait l'IA

Dans Studio, clique sur **AI Panel** (onglet Plugins) : le panneau **« IA : activité »** montre chaque action de l'IA
en direct, le tableau d'équipe et la liste des choses à faire. **« ↶ Annuler l'action de l'IA »** annule sa dernière
modification (jamais la tienne).

## Plusieurs IA en même temps

Branche plusieurs IA sur le même Studio, puis dis à la première : *« Utilise le prompt team_build avec le nom
chef-1 pour faire un jeu de ferme »*, et aux autres : *« team_build avec le nom aide-1 »*. Elles se répartissent les
tâches et les zones de la carte (`team`) sans se marcher dessus.

## Revenir en arrière

Chaque `create_game` sauvegarde d'abord le jeu existant. Dis *« restaure la dernière sauvegarde »*
(`backup_game { action: "restore" }`), ou fais **Ctrl+Z** dans Studio.

## Où modifier quoi dans Studio (sans code)

| Quoi | Où |
|---|---|
| Récompenses, prix, vitesses, textes | `ReplicatedStorage > GameKit > Config > <Système>` |
| Couleurs de toute l'interface | `ReplicatedStorage > GameKit > Config > Theme` |
| Le monde généré | `Workspace > GameKit` |
| Réglage d'un obstacle (puissance d'un jump pad…) | Sélectionne la pièce → Propriétés → Attributs |
| Scripts du kit | `ServerScriptService > GameKit` et `StarterPlayer > StarterPlayerScripts > GameKit` |
| Traductions (FR/ES/PT/DE + les tiennes) | `ReplicatedStorage > GameKit > Config > Lang` |
| Sauvegardes / tableau d'équipe / mémoire du projet | `ServerStorage > GameKitBackups` / `GameKitTeam` / `GameKitNotes` |
| Animations créées depuis Blender | `ServerStorage > GameKit > Animations` |

Tout ce que le kit installe s'annule en une fois avec **Ctrl+Z**.
