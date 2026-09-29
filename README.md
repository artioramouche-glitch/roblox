<div align="center">

# 🎮 Roblox Ultimate MCP

### N'importe quelle IA crée un vrai jeu Roblox, de A à Z

**Claude · ChatGPT/Codex · Gemini · Cursor · Windsurf · Copilot · modèles locaux** — tout client MCP

[Démarrage](#-démarrage-en-5-minutes) · [Premier jeu](#-ton-premier-jeu-en-une-phrase) · [Modèles](#-6-jeux-complets-prêts-à-lemploi) · [Systèmes](#-18-systèmes-plug-and-play) · [Outils](#-les-outils) · [Petites IA](#-pourquoi-ça-marche-même-avec-une-petite-ia) · [Dev](#-développement)

</div>

---

Un serveur [MCP](https://modelcontextprotocol.io/) qui connecte ton IA à **Roblox Studio**. Il réunit :

- **le Game Kit** : des jeux complets, des systèmes testés, des générateurs de mondes et d'interfaces, et un **playtest
  automatique** qui trouve et explique les erreurs ;
- **plus de 140 outils Studio** (base [6xvl](https://github.com/6xvl/robloxstudio-mcp-server)) : scripts, objets,
  terrain, éclairage, animations, sons, particules, assets, profilage, captures d'écran, tests multijoueurs,
  plusieurs Studio à la fois, et le lien vers le MCP officiel intégré à Studio.

Résultat : même une IA « faible en code » peut sortir un jeu jouable et propre, parce qu'elle **assemble des briques
déjà testées** au lieu d'écrire 2000 lignes de Luau fragile.

```
 Ton IA ──stdio──► Roblox Ultimate MCP ──HTTP localhost:58741──► Plugin Studio ──► Ton jeu
                    │                                              (édition + copies serveur/client
                    │                                               pendant les playtests)
                    ├─ Game Kit : 6 jeux complets, 18 systèmes, mondes, UI, ambiances
                    ├─ Garde-fous : compilateur Luau (WASM) + linter « erreurs de débutant »
                    ├─ Vérification : check_game (audit) + test_game (playtest automatique)
                    └─ 140+ outils Studio (terrain, éclairage, animations, profilage, multi-Studio…)
```

## ✨ Ce qui le rend « ultime »

| | Fonction | Ce que ça change |
|---|---|---|
| 🏗️ | **`create_game`** — 6 jeux complets | Obby, Tycoon, Simulator, Arène PvP, Survie zombies, Horreur/évasion : scripts serveur+client, config, monde, HUD et éclairage **en un seul appel** |
| 🧩 | **`add_system`** — 18 systèmes | Sauvegarde, checkpoints, boutique, familiers, rounds, épée, ennemis avec pathfinding, récompense quotidienne, classement mondial, monétisation… |
| 🌍 | **`build_world`** — mondes & pièces | Parcours d'obby progressif (12 types d'obstacles), labyrinthe généré, arène, parcelles de tycoon, zones de simulateur, 29 pièces (jump pad, pièce, spinner…) |
| 🖼️ | **`build_ui`** — UI en JSON | Écrans responsive + comportements **sans code** (`bind: "stat:Coins"`, `action: "toggle:Boutique"`) |
| 🌅 | **`set_environment`** | 10 ambiances (jour, coucher de soleil, nuit, horreur, néon…) + terrain (collines, île, eau) |
| 🛡️ | **`write_script`** / **`check_luau`** | Le vrai compilateur Luau (WASM) + linter : refuse le code cassé **avant** Studio, explique la correction |
| 🔍 | **`check_game`** | Audit complet : syntaxe de tous les scripts, scripts mal placés (qui ne tournent jamais), spawn manquant, pièces non ancrées… |
| 🧪 | **`test_game`** | Lance le jeu, **joue tout seul** (checkpoints, pièces, pièges), récupère les erreurs serveur ET client avec explication, s'arrête et nettoie |
| 🧰 | **140+ outils Studio** | Terrain, éclairage, animations, particules, sons, matériaux, assets du Creator Store, captures d'écran, simulateur d'appareils, tests à 8 joueurs, profileurs, points d'arrêt, `.rbxm`, synchro de fichiers… |
| 🧠 | Guides, prompts, instructions | La méthode est injectée automatiquement dans l'IA ; `roblox_guide` explique Luau, client/serveur, game design, erreurs… |
| 🎚️ | Profils d'outils | 27 outils par défaut (au lieu de 160) pour ne pas perdre une petite IA ; tout reste accessible via `find_tools`/`call_tool` |

---

## 🚀 Démarrage en 5 minutes

### 1. Installer le serveur

Il faut [Node.js](https://nodejs.org) 18 ou plus.

```bash
git clone https://github.com/artioramouche-glitch/roblox.git
cd roblox
npm install        # installe ET compile tout
```

### 2. Installer le plugin dans Roblox Studio

```bash
npm run install-plugin
```

(ou copie `studio-plugin/MCPPlugin.rbxmx` dans `%LOCALAPPDATA%\Roblox\Plugins\` sous Windows,
`~/Documents/Roblox/Plugins/` sous macOS). Puis :

1. Redémarre Studio et ouvre un jeu (Fichier → Nouveau → Baseplate suffit).
2. **Paramètres du jeu → Sécurité → Autoriser les requêtes HTTP** ✅
3. Onglet **Plugins → MCP Server → Connect**.

### 3. Brancher ton IA

Remplace `CHEMIN` par le dossier cloné (ex. `C:/Users/moi/roblox` ou `/home/moi/roblox`).

**Claude Code**
```bash
claude mcp add roblox -- node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

**Claude Desktop / Cursor / Windsurf / Cline / LM Studio / tout client JSON**
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

**VS Code (Copilot)** — `.vscode/mcp.json`
```json
{ "servers": { "roblox": { "type": "stdio", "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"] } } }
```

**Gemini CLI**
```bash
gemini mcp add roblox node CHEMIN/packages/roblox-ultimate-mcp/dist/index.js
```

**Codex CLI** — `~/.codex/config.toml`
```toml
[mcp_servers.roblox]
command = "node"
args = ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"]
```

> Plus de variantes (Windows, ports, clé Open Cloud, édition lecture seule…) : [docs/CLIENTS.md](docs/CLIENTS.md).

---

## 🗣️ Ton premier jeu en une phrase

Dis simplement à ton IA :

> *« Crée-moi un obby candy de 20 niveaux, difficulté moyenne, puis teste-le et corrige tout. »*

> *« Fais un simulateur avec 4 zones, des familiers et des renaissances. »*

> *« Un jeu d'horreur : labyrinthe sombre, 4 clés à trouver, un monstre qui poursuit. »*

L'IA suit d'elle-même la méthode (elle lui est envoyée à la connexion) :
`roblox_start_here` → `create_game` → `test_game` → corrections → personnalisation → `check_game`.

Les clients qui gèrent les **prompts MCP** proposent aussi `make_game`, `fix_my_game`, `add_feature` et `polish_game`.

---

## 🎮 6 jeux complets prêts à l'emploi

| Modèle | Genre | Contenu |
|---|---|---|
| `obby` | Parkour | Parcours flottant au-dessus d'une mer de lave, checkpoints sauvegardés, 12 types d'obstacles à difficulté croissante, pièces, récompenses de fin, boutique (traînées, boosts), classement mondial |
| `tycoon` | Tycoon | Parcelles à réclamer, droppers → tapis → collecteur, amplificateur, 10 achats en chaîne (murs, jardin, super dropper, tour), progression sauvegardée |
| `simulator` | Simulator | Entraîne-toi → sac à dos → vends → améliorations & familiers → zones payantes → renaissance (multiplicateur permanent) |
| `arena` | Combat | Lobby + arène, boucle de rounds (le dernier debout gagne), épées pendant les rounds, récompenses, boutique |
| `survival` | Survie | Vagues de zombies (normal, rapide, colosse) de plus en plus grosses, épée, pièces par kill et par vague |
| `horror_escape` | Horreur | Labyrinthe généré, lumières qui clignotent, clés à trouver, porte de sortie, monstre avec pathfinding |

Options courantes : `title`, `theme` (rainbow, candy, neon, nature, space, lava, ice), `difficulty`, `stages`, `plots`,
`zones`, `mazeSize`, `keys`, `seed`, `lighting`. Tout reste modifiable sans code dans
`ReplicatedStorage/GameKit/Config/<Système>` (fichiers Luau commentés).

## 🧩 18 systèmes plug-and-play

| Système | Rôle |
|---|---|
| `core` (toujours) | Sauvegarde DataStore sûre (verrou de session, réessais, sauvegarde auto, mode mémoire en Studio), leaderstats, réseau sécurisé (`Net`), UI kit, liaison UI sans code |
| `hud` | Stats avec animations « +N », barre de statut/minuteur, notifications, boutons latéraux |
| `checkpoints` · `hazards` · `movers` · `collectibles` | Obby : checkpoints, kill bricks/dégâts/soins, plateformes mobiles/spinners/disparaissantes/qui tombent, tapis, téléporteurs, jump/speed pads, pièces |
| `rounds` · `combat` · `enemies` | Boucle de rounds, épée avec détection serveur anti-triche, PNJ avec pathfinding + mode vagues |
| `shop` · `daily` · `leaderboard` · `monetization` | Boutique validée par le serveur (boosts, outils, traînées, multiplicateurs, familiers, améliorations), récompense quotidienne avec série, classement mondial, produits/pass sans double attribution |
| `movement` · `atmosphere` · `admin` | Sprint + double saut, cycle jour/nuit + musique + lumières qui clignotent, commandes `/give /tp /kick…` |
| `tycoon` · `simulator` · `objectives` | Mécaniques de genre complètes |

La référence complète (réglages, tags, attributs) est dans **[docs/GAMEKIT.md](docs/GAMEKIT.md)**
(générée depuis le code, donc toujours exacte) — et l'IA peut la lire avec `roblox_guide <système>`.

## 🖼️ Une interface sans écrire de code

```json
{ "name": "MonUI", "children": [
  { "type": "frame", "position": "top-right", "size": [220, 56], "stroke": true, "padding": 8, "children": [
    { "type": "label", "size": [1, 1], "bind": "stat:Coins", "format": "💰 {value}" } ] },
  { "type": "button", "position": "bottom-right", "size": [150, 50], "text": "Menu", "action": "toggle:Fenetre" },
  { "type": "frame", "name": "Fenetre", "position": "center", "size": [0.4, 0.5], "visible": false } ] }
```

`bind` suit une stat en direct, `bar` fait une barre de progression, `showIf` affiche selon l'état,
`action` ouvre/ferme/déclenche un RemoteEvent. Tailles ≤ 1 = fraction d'écran, > 1 = pixels.

---

## 🔧 Les outils

**Game Kit (toujours visibles)** : `roblox_start_here`, `roblox_guide`, `gamekit_catalog`, `create_game`, `add_system`,
`build_world`, `build_ui`, `set_environment`, `write_script`, `check_luau`, `check_game`, `test_game`.

**Profils** (variable `ROBLOX_MCP_PROFILE` ou outil `set_tool_profile`) :

| Profil | Outils listés | Contenu |
|---|---|---|
| `starter` *(défaut)* | 27 | Game Kit + essentiels (lecture/édition de scripts, propriétés, objets, `execute_luau`, annuler, capture d'écran, doc Roblox) |
| `builder` | 80 | + tags, attributs, opérations de masse, terrain, éclairage, assets, playtest manuel, logs par pair, runtime eval, navigation du personnage, multi-Studio |
| `full` | 160 | Tout : animations, sons, particules, matériaux, profileurs, points d'arrêt, simulateur d'appareils/réseau, tests multijoueurs, `.rbxm`, synchro de fichiers, publication… |

Même en `starter`, **tous** les outils restent utilisables : `find_tools` (recherche + schéma) puis `call_tool`.

```json
{ "mcpServers": { "roblox": { "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"], "env": { "ROBLOX_MCP_PROFILE": "full" } } } }
```

**Édition lecture seule** : `packages/roblox-ultimate-mcp-inspector/dist/index.js` (inspection, guides, vérification
Luau ; aucune écriture) — pratique pour faire relire un jeu sans risque.

---

## 🧠 Pourquoi ça marche même avec une petite IA

1. **Moins de code à écrire** : un jeu complet = 1 appel ; une fonctionnalité = 1 système + un peu de config.
2. **Moins de choix** : 27 outils au lieu de 160, avec des descriptions qui disent *quand* les utiliser.
3. **Instructions automatiques** : la méthode est envoyée à l'IA dès la connexion (champ `instructions` MCP).
4. **Garde-fous** : `write_script` compile le Luau (vrai compilateur) et bloque les erreurs de débutant
   (`LocalPlayer` côté serveur, boucle infinie sans `task.wait`, argent modifié côté client, `!=` au lieu de `~=`…).
5. **Boucle de correction** : `test_game` renvoie chaque erreur avec le script, la ligne et **l'explication en clair**.
6. **Guides intégrés** : Luau, client/serveur, sauvegarde, UI, game design, erreurs courantes, publication.

---

## 🧰 Développement

```bash
npm run build            # intègre gamekit/*.luau puis compile core + serveur + édition lecture seule
npm test                 # 107 tests du serveur + 36 tests Game Kit
npm run gamekit:smoke    # test MCP de bout en bout (stdio)
npm run gamekit:verify   # syntaxe (WASM) + types Roblox (si luau-lsp est installé) de tout le Luau
npm run build:plugin     # recompile le plugin Studio (roblox-ts) et l'installe (Windows/macOS)
```

Validation avancée (optionnelle, nécessite [Lune](https://github.com/lune-org/lune)) :

```bash
node scripts/dump-gamekit-cases.mjs /tmp/cases && lune run scripts/lune/validate-installers.luau /tmp/cases
LUNE=lune npm run gamekit:integration   # MCP -> pont HTTP -> faux plugin Studio (Lune) -> Luau
```

La première commande exécute chaque installateur (76 cas, ~4000 instances) contre la base de données officielle des
classes Roblox : un mauvais nom de propriété ou un mauvais type est détecté sans ouvrir Studio.

### Organisation

| Dossier | Contenu |
|---|---|
| `gamekit/` | **La bibliothèque Luau** : `shared/` (Net, Util, UIKit), `core/` (PlayerData…), `systems/<système>/`, `runtime/` (installateur, audit, test) |
| `packages/core/` | Le serveur : pont HTTP multi-Studio, 140+ outils (`src/tools/`), et la couche Game Kit (`src/gamekit/`) |
| `packages/roblox-ultimate-mcp/` | Point d'entrée (commande `roblox-ultimate-mcp`, option `--install-plugin`) |
| `packages/roblox-ultimate-mcp-inspector/` | Édition lecture seule |
| `studio-plugin/` | Plugin Studio (`MCPPlugin.rbxmx` prêt à l'emploi + sources roblox-ts) |
| `docs/` | [GAMEKIT.md](docs/GAMEKIT.md) (référence), [CLIENTS.md](docs/CLIENTS.md) |
| `reference/` | Autres serveurs MCP Roblox importés (ancienne base, serveurs Rust officiels), non utilisés par le build |

Ajouter un système : écrire les `.luau` dans `gamekit/systems/<id>/` (`.server.luau` → ServerScriptService,
`.client.luau` → StarterPlayerScripts, sinon ModuleScript), l'ajouter dans `packages/core/src/gamekit/catalog.ts`,
puis `npm run build && npm test`.

---

## 🩺 Dépannage

| Problème | Solution |
|---|---|
| `Roblox Studio is not connected` | Studio ouvert ? Plugin installé (`npm run install-plugin`) ? Requêtes HTTP autorisées ? Clique **Connect** |
| « Saving is OFF » dans la sortie | Normal en Studio non publié : publie puis active *Enable Studio Access to API Services* pour tester la sauvegarde |
| L'IA ne voit pas un outil | Profil `starter` : `find_tools` puis `call_tool`, ou `set_tool_profile full` |
| `test_game` ne s'arrête pas | Appuie sur **Stop** dans Studio puis relance ; `check_game` signale un reste de runner de test |
| Deux IA en même temps | Supporté : la 2e instance passe en mode proxy et partage le même Studio |
| `failed to connect to roblox studio: -32000` | Sans gravité : c'est le lien optionnel vers le MCP officiel de Studio. Pour le couper : `ROBLOX_MCP_HOOK=0` |
| Un son/une animation ne se charge pas | L'asset est privé : utilise un asset public ou le tien |

---

## Crédits & licence

MIT. Serveur et plugin basés sur [6xvl/robloxstudio-mcp-server](https://github.com/6xvl/robloxstudio-mcp-server)
(lui-même issu de [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp) et
[Chrrxs/robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp)), avec [luau-web](https://github.com/xNasuni/luau-web)
pour la compilation Luau hors-ligne. Détails : [NOTICE.md](NOTICE.md).
