<div align="center">

# 🎮 Roblox Ultimate MCP

### N'importe quelle IA crée un vrai jeu Roblox, de A à Z

**Claude · ChatGPT/Codex · Gemini · Cursor · Windsurf · Copilot · modèles locaux** — tout client MCP

[Démarrage](#-démarrage-en-5-minutes) · [Premier jeu](#-ton-premier-jeu-en-une-phrase) · [Modèles](#-11-jeux-complets-prêts-à-lemploi) · [Systèmes](#-28-systèmes-plug-and-play) · [Qualité](#-qualité-avant-publication) · [Panneau Studio](#-le-panneau-ia-dans-studio) · [Blender](#-modèles-3d-avec-blender) · [Plusieurs IA](#-plusieurs-ia-sur-le-même-jeu) · [Outils](#-les-outils) · [Dev](#-développement)

</div>

---

Un serveur [MCP](https://modelcontextprotocol.io/) qui connecte ton IA à **Roblox Studio**. Il réunit :

- **le Game Kit** : des jeux complets, des systèmes testés, des générateurs de mondes et d'interfaces, et un **playtest
  automatique** qui trouve et explique les erreurs ;
- **plus de 140 outils Studio** (base [6xvl](https://github.com/6xvl/robloxstudio-mcp-server)) : scripts, objets,
  terrain, éclairage, animations, sons, particules, assets, profilage, captures d'écran, tests multijoueurs,
  plusieurs Studio à la fois, et le lien vers le MCP officiel intégré à Studio ;
- **Blender** ([blender-mcp](https://github.com/ahujasid/blender-mcp), addon inclus) : l'IA modélise, télécharge ou
  génère des objets 3D et les envoie dans le jeu à la bonne taille, **par le même serveur** ;
- **le travail à plusieurs IA** : tableau de tâches partagé, zones de carte réservées, tâches de fond.

Résultat : même une IA « faible en code » peut sortir un jeu jouable et propre, parce qu'elle **assemble des briques
déjà testées** au lieu d'écrire 2000 lignes de Luau fragile.

```
 Ton IA ──stdio──► Roblox Ultimate MCP ──HTTP localhost:58741──► Plugin Studio ──► Ton jeu
  (1 ou plusieurs)  │                                              (édition + copies serveur/client
                    │                                               pendant les playtests)
                    ├─ Game Kit : 11 jeux complets, 28 systèmes, mondes, décor, UI, ambiances
                    ├─ Mémoire : game_notes (idée, décisions, fait / à faire) stockée dans le jeu
                    ├─ Garde-fous : compilateur Luau (WASM) + linter « erreurs de débutant »
                    ├─ Vérification : check_game, test_game (solo, 2 joueurs, téléphone), look_at_game
                    ├─ Qualité : check_assets (sons/animations), optimize_game (téléphones), publish_checklist
                    ├─ Sécurité : backup_game (sauvegardes restaurables), tâches de fond
                    ├─ Équipe : tableau de tâches + zones partagées entre plusieurs IA
                    ├─ Blender ──TCP localhost:9876──► addon « MCP for Blender » ──► objets, personnages riggés, animations
                    └─ 140+ outils Studio (terrain, éclairage, animations, profilage, multi-Studio…)
```

## ✨ Ce qui le rend « ultime »

| | Fonction | Ce que ça change |
|---|---|---|
| 🏗️ | **`create_game`** — 11 jeux complets | Obby, Tycoon, Simulator, Arène PvP, Survie zombies, Horreur/évasion, Tower defense coop, Ferme (idle), **Course en karts**, **Pêche**, **Survie coop avec craft** : scripts serveur+client, config, monde, HUD et éclairage **en un seul appel** (avec sauvegarde automatique de l'existant) |
| 🧩 | **`add_system`** — 28 systèmes | Sauvegarde, checkpoints, boutique, rounds, épée, ennemis avec pathfinding, tower defense, ferme, **inventaire**, **niveaux & XP**, **quêtes**, **œufs & familiers**, **course**, **pêche**, **récolte & craft**, récompense quotidienne, classement mondial, monétisation, **analytics** et **traduction** intégrées… |
| 🧠 | **`game_notes`** — mémoire du projet | Idée, décisions, fait, à faire et historique des changements, **stockés dans le jeu** : une nouvelle conversation (ou une autre IA) reprend en un appel au lieu de tout relire |
| 🌍 | **`build_world`** — mondes & pièces | Parcours d'obby progressif (12 types d'obstacles), labyrinthe, arène, tycoon, simulateur, tower defense, ferme, **circuit**, **lacs de pêche**, **camp de survie**, 53 pièces (jump pad, pièce, spinner, œuf, point de pêche, arbre à couper…) |
| 🌳 | **`populate_world`** — décor en masse | Forêt, désert, neige, plage, fantasy, ville, ferme, spooky, jardin — ou tes modèles (Creator Store, Blender) ; posé au sol, sans jamais bloquer le gameplay |
| 👀 | **`look_at_game`** | L'IA **voit** son jeu : captures sous plusieurs angles (vue d'ensemble, dessus, joueur) |
| 🎨 | **Blender → Roblox** | `blender_to_roblox` : export (réduction auto à 20k triangles), upload, insertion à l'échelle (1 m = 3,57 studs), posé au sol ; **personnages riggés** et **animations** (`blender_animation`) |
| 🤝 | **`team`** + **`start_job`** | Plusieurs IA sur le même jeu (tâches, zones), et les outils lents tournent en arrière-plan |
| 💾 | **`backup_game`** | Instantanés restaurables en un appel (monde, scripts, UI, éclairage, terrain) |
| 📈 | **`balance_economy`** · **`publish_checklist`** | Simulation de progression (prix trop bas, murs de 20 min…) avec prix suggérés ; checklist de publication vérifiée |
| 🖼️ | **`build_ui`** — UI en JSON | Écrans responsive + comportements **sans code** (`bind: "stat:Coins"`, `action: "toggle:Boutique"`) |
| 🌅 | **`set_environment`** | 10 ambiances (jour, coucher de soleil, nuit, horreur, néon…) + terrain (collines, île, eau) |
| 🛡️ | **`write_script`** / **`check_luau`** | Le vrai compilateur Luau (WASM) + linter : refuse le code cassé **avant** Studio, explique la correction |
| 🔍 | **`check_game`** | Audit complet : syntaxe de tous les scripts, scripts mal placés (qui ne tournent jamais), spawn manquant, pièces non ancrées… |
| 🧪 | **`test_game`** | Lance le jeu, **joue tout seul** (checkpoints, pièces, pièges, quêtes, œufs, pêche, craft…), récupère les erreurs serveur ET client avec explication, s'arrête et nettoie. **`{players: 2}`** : vrai test multijoueur. **`{device: "phone"}`** : écran de téléphone + contrôle de l'interface |
| 🔊 | **`check_assets`** | Vérifie que chaque son, animation et image **se charge vraiment** (et que les animations appartiennent au propriétaire du jeu) avant que les joueurs n'entendent le silence |
| 📱 | **`optimize_game`** | Bilan pour les **téléphones d'entrée de gamme** (pièces, physique, ombres, lumières, particules, streaming, scripts lourds) et corrections sûres en un appel |
| 🖥️ | **Panneau « IA » dans Studio** | Ce que fait l'IA en direct, tableau d'équipe, tâches à faire, bouton **« Annuler l'action de l'IA »** |
| ⚡ | **`npx roblox-ultimate-mcp setup`** | Installation en une commande, sans cloner le dépôt : plugin Studio + configuration de tes applis d'IA (+ addon Blender) |
| 🧰 | **140+ outils Studio** | Terrain, éclairage, animations, particules, sons, matériaux, assets du Creator Store, captures d'écran, simulateur d'appareils, tests à 8 joueurs, profileurs, points d'arrêt, `.rbxm`, synchro de fichiers… |
| 🧠 | Guides, prompts, instructions | La méthode est injectée automatiquement dans l'IA ; `roblox_guide` explique Luau, client/serveur, game design, erreurs… |
| 🧑‍💻 | **Aide au code** | Correction auto des réflexes JavaScript/Python, détection des API Roblox inventées (avec la bonne suggestion), `edit_script` vérifié, 12 recettes de code prêtes à l'emploi |
| 🪙 | **Économe en tokens** | Liste d'outils allégée (−36 %), réponses JSON compactes, lecture de scripts ciblée, captures réduites |
| 🎚️ | Profils d'outils | 38 outils par défaut (au lieu de 182) pour ne pas perdre une petite IA ; tout reste accessible via `find_tools`/`call_tool` |

---

## 🚀 Démarrage en 5 minutes

Il faut [Node.js](https://nodejs.org) 18 ou plus.

### ⚡ En une commande (sans cloner le dépôt)

```bash
npx roblox-ultimate-mcp setup             # plugin Studio + Claude Desktop / Cursor / Windsurf configurés
npx roblox-ultimate-mcp setup --blender   # ... et l'addon Blender
```

La commande installe le plugin Studio, ajoute le serveur dans les applis d'IA trouvées sur l'ordinateur (sans toucher
aux autres serveurs, avec une copie `.bak`), et affiche la ligne à coller pour Claude Code ou une autre appli.
Il reste à redémarrer Studio et l'appli d'IA, puis à faire l'étape « Autoriser les requêtes HTTP » ci-dessous.

> Cette commande marche dès que le paquet est publié sur npm (workflow `.github/workflows/publish.yml`, voir
> [Publier sur npm](#publier-sur-npm)). En attendant, utilise l'installation depuis le dépôt ci-dessous.

### 📦 Depuis le zip (sans git)

1. Sur GitHub : bouton vert **Code → Download ZIP** (choisis la branche `claude/charming-johnson-0o1yse` tant que la
   PR n'est pas fusionnée). Dézippe dans un dossier qui ne bougera plus (ex. `C:\roblox-mcp`).
2. Dans ce dossier, ouvre un terminal (Windows : clic droit → *Ouvrir dans le terminal*) :
   ```bash
   npm install        # dépendances + compilation (le zip ne contient pas les fichiers compilés)
   npm run setup      # plugin Studio + Claude Desktop / Cursor / Windsurf configurés vers CE dossier
   ```
   `npm run setup -- --blender` installe aussi l'addon Blender.
3. Redémarre Studio et l'appli d'IA, puis active **Autoriser les requêtes HTTP** (étape 2 ci-dessous).

Si tu déplaces le dossier plus tard, relance `npm run setup -- --force`.

### 1. Installer le serveur (depuis le dépôt)

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

> Plus de variantes (Windows, ports, clé Open Cloud, Blender, édition lecture seule…) : [docs/CLIENTS.md](docs/CLIENTS.md).

### 4. (Optionnel) Brancher Blender

```bash
npm run install-blender-addon
```

Puis dans Blender : touche **N** → onglet **MCP for Blender** → **Connect to MCP server**. Rien d'autre à configurer :
le serveur Roblox parle directement à l'addon (pas de serveur Python, pas de télémétrie). Détails :
[Modèles 3D avec Blender](#-modèles-3d-avec-blender).

---

## 🗣️ Ton premier jeu en une phrase

Dis simplement à ton IA :

> *« Crée-moi un obby candy de 20 niveaux, difficulté moyenne, puis teste-le et corrige tout. »*

> *« Fais un simulateur avec 4 zones, des familiers et des renaissances. »*

> *« Un jeu d'horreur : labyrinthe sombre, 4 clés à trouver, un monstre qui poursuit. »*

> *« Un tower defense à 20 vagues avec une tour laser en plus, et un décor de désert autour. »*

> *« Modélise un coffre au trésor dans Blender et mets-en 5 dans la forêt. »*

> *« Un jeu de pêche avec un requin légendaire, des quêtes et des œufs de familiers marins. »*

> *« Une survie à plusieurs : on coupe du bois le jour, on se défend contre les zombies la nuit. »*

L'IA suit d'elle-même la méthode (elle lui est envoyée à la connexion) :
`roblox_start_here` → `create_game` → `test_game` → corrections → personnalisation (`populate_world`, `build_ui`…)
→ `look_at_game` → `check_game` → avant publication : `test_game {players: 2}`, `test_game {device: "phone"}`,
`check_assets`, `optimize_game`, `publish_checklist`. Elle note son avancement dans `game_notes`.

Les clients qui gèrent les **prompts MCP** proposent aussi `make_game`, `fix_my_game`, `add_feature`, `polish_game`,
`team_build` (plusieurs IA) et `blender_prop` (objet 3D sur mesure).

---

## 🎮 11 jeux complets prêts à l'emploi

| Modèle | Genre | Contenu |
|---|---|---|
| `obby` | Parkour | Parcours flottant au-dessus d'une mer de lave, checkpoints sauvegardés, 12 types d'obstacles à difficulté croissante, pièces, récompenses de fin, boutique (traînées, boosts), classement mondial |
| `tycoon` | Tycoon | Parcelles à réclamer, droppers → tapis → collecteur, amplificateur, 10 achats en chaîne (murs, jardin, super dropper, tour), progression sauvegardée |
| `simulator` | Simulator | Entraîne-toi → sac à dos → vends → améliorations & familiers → zones payantes → renaissance (multiplicateur permanent) |
| `arena` | Combat | Lobby + arène, boucle de rounds (le dernier debout gagne), épées pendant les rounds, récompenses, boutique |
| `survival` | Survie | Vagues de zombies (normal, rapide, colosse) de plus en plus grosses, épée, pièces par kill et par vague |
| `horror_escape` | Horreur | Labyrinthe généré, lumières qui clignotent, clés à trouver, porte de sortie, monstre avec pathfinding |
| `tower_defense` | Tower defense (coop) | Chemin sinueux, vagues (Basic, Fast, Tank, Boss), 15 emplacements : tours Archer, Canon (zone), Givre (ralentit), amélioration/revente, château à défendre, victoire récompensée |
| `farming` | Ferme / idle | 24 parcelles, 5 cultures qui poussent en 3 étapes visibles, récolte, marché, cultures à débloquer (blé → carotte → tomate → citrouille → cristal) |
| `racing` | Course | Circuit ovale avec grille de départ, 3-2-1-GO, karts (clavier, manette, mobile), tours et points de passage, positions en direct, meilleur tour sauvegardé, podium, quêtes et niveaux |
| `fishing` | Pêche / collection | Lancer, attendre la touche, ferrer à temps : 6 poissons et 2 zones (étang, océan) avec raretés, marché aux poissons, canne à améliorer (touches plus rapides, poissons plus rares, océan débloqué), quêtes, œufs et familiers marins |
| `craft_survival` | Survie coop + craft | Couper du bois, miner, cueillir le jour ; fabriquer haches, épées, murs, pics et feux de camp ; gérer la faim ; défendre le camp ensemble contre les zombies chaque nuit |

Options courantes : `title`, `theme` (rainbow, candy, neon, nature, space, lava, ice), `difficulty`, `stages`, `plots`,
`zones`, `mazeSize`, `keys`, `waves`, `laps`, `karts`, `seed`, `lighting`. Tout reste modifiable sans code dans
`ReplicatedStorage/GameKit/Config/<Système>` (fichiers Luau commentés).

## 🧩 28 systèmes plug-and-play

| Système | Rôle |
|---|---|
| `core` (toujours) | Sauvegarde DataStore sûre (verrou de session, réessais, sauvegarde auto, mode mémoire en Studio), leaderstats, réseau sécurisé (`Net`), UI kit, liaison UI sans code, **Analytics** (économie, funnel, progression dans le Creator Dashboard) et **traduction** de l'interface (FR/ES/PT/DE) |
| `hud` | Stats avec animations « +N », barre de statut/minuteur, notifications, boutons latéraux |
| `checkpoints` · `hazards` · `movers` · `collectibles` | Obby : checkpoints, kill bricks/dégâts/soins, plateformes mobiles/spinners/disparaissantes/qui tombent, tapis, téléporteurs, jump/speed pads, pièces |
| `rounds` · `combat` · `enemies` | Boucle de rounds, épée avec détection serveur anti-triche, PNJ avec pathfinding + mode vagues |
| `shop` · `daily` · `leaderboard` · `monetization` | Boutique validée par le serveur (boosts, outils, traînées, multiplicateurs, familiers, améliorations), récompense quotidienne avec série, classement mondial, produits/pass sans double attribution |
| `movement` · `atmosphere` · `admin` | Sprint + double saut, cycle jour/nuit + musique + lumières qui clignotent, commandes `/give /tp /kick…` |
| `tycoon` · `simulator` · `objectives` · `towerdefense` · `farming` | Mécaniques de genre complètes |
| `inventory` · `levels` · `quests` · `pets` | **Rétention** : objets sauvegardés (fenêtre 🎒, vente), XP et niveaux (barre, récompenses), quêtes en chaîne qui servent de tutoriel, œufs à éclore et familiers qui multiplient les gains |
| `racing` · `fishing` · `crafting` | Course (tours, points de passage, karts arcade), pêche (zones, raretés, canne), récolte + craft + constructions + faim (avec `enemies` en mode vagues jour/nuit) |

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

## 🧑‍💻 Une IA moyenne en code devient fiable

Les petits modèles échouent surtout sur trois choses : des habitudes d'autres langages, des API Roblox inventées, et
des réécritures complètes de scripts qui cassent tout. Le serveur s'en occupe :

| Aide | Ce qu'elle fait |
|---|---|
| **Correction automatique** | `write_script`, `edit_script` et `check_luau` convertissent `!=`, `&&`, `\|\|`, `!x`, `null`, `// commentaires`, `let/const`, `i++`, `"texte" + x`, `` `${x}` ``, `wait()`… en Luau correct, et disent ce qui a été changé (l'IA apprend) |
| **Détecteur d'API inventées** | Index de toute l'API Roblox (965 classes, 635 enums) : `GetService("Player")` → *Players*, `Instance.new("Brick")` → *Part*, `Enum.Material.Wooden` → *Wood*, `Vector3.New`, `humanoid.Walkspeed` → *WalkSpeed*, méthodes obsolètes (`AwardBadge` → `AwardBadgeAsync`)… |
| **`code_recipe`** | 12 scripts vérifiés à partir de quelques paramètres : récompense au toucher, prompt « E », porte à condition, apparition d'objets, récompense de temps de jeu, bouton UI → serveur, dialogue de PNJ, badge, stats du personnage, commande de chat, musique de zone, mouvement en boucle. Chacun passe le compilateur, le linter, le contrôle d'API et luau-lsp |
| **`edit_script`** | Modifie une partie d'un script par rechercher/remplacer (tolère une indentation différente), vérifie le résultat **avant** d'écrire : jamais de script cassé, et pas besoin de renvoyer tout le fichier |
| **`read_script`** / **`code_outline`** | Lire seulement les lignes utiles (plage ou mot-clé) ; plan du code du jeu en une ligne par script |
| **Erreurs avec leur code** | `test_game` et `check_game` montrent les lignes fautives à côté de l'explication : la correction se fait sans relire le script |

## 🪙 Économie de tokens

| | Avant | Maintenant |
|---|---|---|
| Liste d'outils du profil de base (renvoyée à chaque message par la plupart des clients) | ~7 200 tokens | ~4 600 tokens (avec 2 outils de plus) |
| `find_tools` (recherche) | ~2 600 tokens | ~400 tokens (index ; schéma complet pour un nom exact) |
| Catalogue | ~1 900 tokens | ~1 200 tokens |
| Réponses | JSON indenté, champs vides | JSON compact, champs vides retirés |
| Captures (`look_at_game`, `capture_screenshot`) | pleine taille | 640 / 1024 px (≈ 4× moins de tokens d'image) |
| Lire un script | le source envoyé deux fois | `read_script` : lignes numérotées, plage ou recherche |
| Modifier un script | tout réécrire | `edit_script` : seulement le passage changé |

Les descriptions détaillées sont dans `roblox_guide`, lues seulement quand l'IA en a besoin.
Variables : `ROBLOX_MCP_COMPACT=0` (descriptions complètes), `ROBLOX_MCP_PRETTY=1` (JSON indenté).

---

## ✅ Qualité avant publication

| Outil | Ce qu'il vérifie |
|---|---|
| `test_game { players: 2 }` | Un vrai test serveur + 2 clients (StudioTestService) : tous les joueurs chargés, apparus, et qui se voient. Les rounds, le PvP et la coop ne cassent souvent qu'à plusieurs |
| `test_game { device: "phone" }` | Le jeu tourne dans le simulateur d'appareil (le plus petit téléphone disponible) : boutons trop petits pour le doigt, interface hors de l'écran, texte illisible. Le simulateur est remis comme avant |
| `check_assets` | Chaque son, animation et image du jeu (ou les ids donnés) **se charge-t-il vraiment ?** Les animations d'un autre créateur ne jouent pas dans un jeu publié : elles sont signalées |
| `optimize_game` | Bilan vert / orange / rouge pour les téléphones d'entrée de gamme ; `optimize_game { apply: ["shadows", "lights", "particles", "streaming", "technology"] }` corrige sans risque (un seul Ctrl+Z) |
| `publish_checklist` | Reprend tout : erreurs, playtests (solo, 2 joueurs, téléphone), performances, assets, monétisation, étapes manuelles |

## 🖥️ Le panneau IA dans Studio

Le plugin ajoute un bouton **AI Panel** qui ouvre le panneau **« IA : activité »** :

- **Ce que fait l'IA**, en direct : chaque outil (« create_game obby », « write_script … »), en ✏️ quand il modifie le
  jeu, en ❌ quand il échoue ;
- le **tableau d'équipe** (`team`) et la liste **À faire** de `game_notes` ;
- **« ↶ Annuler l'action de l'IA »** : chaque modification de l'IA est une seule étape d'annulation nommée
  `MCP: AI …`. Le bouton n'annule que ça, jamais une modification que tu as faite toi-même. Une action de l'IA qui
  échoue est annulée automatiquement.

---

## 🎨 Modèles 3D avec Blender

Le dossier `integrations/blender-mcp/` contient [blender-mcp](https://github.com/ahujasid/blender-mcp) (MIT). Seul son
**addon** est utilisé : le serveur Roblox lui parle directement en TCP (`localhost:9876`), donc une seule entrée MCP
dans ton IA pour Studio **et** Blender.

| Outil | Rôle |
|---|---|
| `blender_status` | Vérifie le lien, liste la scène ; explique l'installation si besoin. Une fois Blender connecté, les autres outils apparaissent |
| `blender_python` | Modélise en Python (`bpy`), étape par étape |
| `blender_scene` | Objets (taille en mètres, triangles, matériaux) + capture de la vue 3D |
| `blender_assets` | Modèles gratuits (Poly Pizza, Sketchfab, Poly Haven) ou génération par IA (Hyper3D, Hunyuan3D) |
| `blender_to_roblox` | Export (réduction auto à 20 000 triangles/maillage, alertes textures et matériaux) → upload Roblox → insertion à la bonne taille, posée au sol. **Personnage riggé** : l'armature est exportée avec le maillage (4 influences max par sommet) et le modèle reçoit un Animator |
| `blender_animation` | Une **action Blender** (Marche, Attaque…) devient une **KeyframeSequence** dans `ServerStorage/GameKit/Animations`, testable tout de suite (id temporaire), + un FBX animé pour l'Animation Editor. Publie-la ensuite (clic droit → *Save to Roblox*) et vérifie l'id avec `check_assets` |

- **Automatique** avec une clé Open Cloud : `ROBLOX_OPEN_CLOUD_API_KEY` (droits *asset:read* + *asset:write*) et
  `ROBLOX_CREATOR_USER_ID` (ou `ROBLOX_CREATOR_GROUP_ID`).
- **Sans clé** : le fichier est exporté, tu fais *Accueil → Importer 3D* dans Studio, puis l'IA l'ajuste
  (`blender_to_roblox { name, existing: "Workspace/MonModele" }`).
- `BLENDER_MCP_SAFE_MODE=1` fait valider chaque script Python par le validateur de blender-mcp (Python requis).

## 🤝 Plusieurs IA sur le même jeu

Lance plusieurs clients (Claude, Gemini, Codex, un modèle local…) : le premier serveur tient le port, les suivants
passent en mode proxy vers le **même Studio**.

1. Une IA « chef » : `team { action: "plan", goal: "..." }` crée les tâches (jeu de base, zones, décor, objets 3D,
   UI, économie, QA, publication), puis `create_game`.
2. Chaque IA prend un nom (`claude-1`, `gemini-1`…) et boucle : `claim` → travail → `done`.
3. Avant de construire : `claim_zone` réserve une boîte de la carte ; une zone qui chevauche celle d'une autre IA est
   refusée. `build_world { zone }` et `populate_world { zone }` construisent dedans.
4. Les outils lents passent en arrière-plan : `start_job { tool: "blender_to_roblox", … }` puis `job_status`.

Le tableau est stocké **dans le jeu** (`ServerStorage/GameKitTeam`) : il est partagé et sauvegardé avec la place.

---

## 🔧 Les outils

**Game Kit (toujours visibles)** : `roblox_start_here`, `roblox_guide`, `gamekit_catalog`, `create_game`, `add_system`,
`build_world`, `build_ui`, `set_environment`, `game_notes`, `write_script`, `edit_script`, `read_script`, `code_outline`,
`code_recipe`, `check_luau`, `check_game`, `test_game`, `populate_world`, `look_at_game`, `backup_game`, `team`,
`start_job`, `job_status`, `blender_status`, `blender_to_roblox`.

**En plus dès le profil `builder`** : `check_assets`, `optimize_game`, `balance_economy`, `publish_checklist`,
`blender_python`, `blender_scene`, `blender_assets`, `blender_animation`, `blender_command` (les outils Blender
apparaissent aussi dès que Blender est connecté).

**Profils** (variable `ROBLOX_MCP_PROFILE` ou outil `set_tool_profile`) :

| Profil | Outils listés | Contenu |
|---|---|---|
| `starter` *(défaut)* | 38 | Game Kit + essentiels (propriétés, objets, `execute_luau`, annuler, capture d'écran, doc Roblox) |
| `builder` | 102 | + qualité (assets, performances), économie, publication, Blender, scripts bas niveau, tags, attributs, opérations de masse, terrain, éclairage, assets, playtest manuel, logs par pair, runtime eval, navigation du personnage, multi-Studio |
| `full` | 182 | Tout : animations, sons, particules, matériaux, profileurs, points d'arrêt, simulateur d'appareils/réseau, tests multijoueurs, `.rbxm`, synchro de fichiers, publication… |

Même en `starter`, **tous** les outils restent utilisables : `find_tools` (recherche + schéma) puis `call_tool`.

```json
{ "mcpServers": { "roblox": { "command": "node", "args": ["CHEMIN/packages/roblox-ultimate-mcp/dist/index.js"], "env": { "ROBLOX_MCP_PROFILE": "full" } } } }
```

**Édition lecture seule** : `packages/roblox-ultimate-mcp-inspector/dist/index.js` (inspection, guides, vérification
Luau ; aucune écriture) — pratique pour faire relire un jeu sans risque.

---

## 🧠 Pourquoi ça marche même avec une petite IA

1. **Moins de code à écrire** : un jeu complet = 1 appel ; une fonctionnalité = 1 système + un peu de config.
2. **Moins de choix** : 38 outils au lieu de 182, avec des descriptions courtes qui disent *quand* les utiliser.
3. **Instructions automatiques** : la méthode est envoyée à l'IA dès la connexion (champ `instructions` MCP).
4. **Garde-fous** : `write_script` / `edit_script` corrigent automatiquement les réflexes d'autres langages, compilent
   le Luau (vrai compilateur), vérifient les noms d'API Roblox et bloquent les erreurs de débutant
   (`LocalPlayer` côté serveur, boucle infinie sans `task.wait`, argent modifié côté client…).
5. **Du code déjà écrit** : `code_recipe` fournit des scripts vérifiés au lieu de les faire écrire de zéro.
6. **Boucle de correction** : `test_game` renvoie chaque erreur avec le script, la ligne, **le code fautif** et
   **l'explication en clair** ; `edit_script` corrige juste ce passage.
7. **Guides intégrés** : méthode de code, Luau, client/serveur, sauvegarde, UI, game design, erreurs courantes,
   Blender, travail en équipe, traduction, publication.
8. **Filets de sécurité** : sauvegarde automatique avant chaque `create_game`, `backup_game` pour revenir en arrière,
   chaque action de l'IA annulable d'un clic dans le panneau Studio, `look_at_game` pour vérifier visuellement.
9. **Mémoire** : `game_notes` garde l'idée, les décisions et la liste des tâches dans le jeu ; une nouvelle
   conversation reprend là où la précédente s'est arrêtée.

---

## 🧰 Développement

```bash
npm run build            # intègre gamekit/*.luau puis compile core + serveur + édition lecture seule
npm test                 # 107 tests du serveur + 89 tests Game Kit (faux addon Blender, multijoueur, téléphone, assets…)
npm run gamekit:smoke    # test MCP de bout en bout (stdio)
npm run gamekit:verify   # syntaxe (WASM) + types Roblox (si luau-lsp est installé) de tout le Luau, recettes comprises
npm run build:plugin     # recompile le plugin Studio (roblox-ts) et l'installe (Windows/macOS)
```

Validation avancée (optionnelle, nécessite [Lune](https://github.com/lune-org/lune)) :

```bash
node scripts/dump-gamekit-cases.mjs /tmp/cases && lune run scripts/lune/validate-installers.luau /tmp/cases
LUNE=lune npm run gamekit:integration   # MCP -> pont HTTP -> faux plugin Studio (Lune) -> Luau
```

La première commande exécute chaque installateur (119 cas, ~6 800 instances) contre la base de données officielle des
classes Roblox : un mauvais nom de propriété ou un mauvais type est détecté sans ouvrir Studio. Le test d'intégration
crée les 11 jeux, fait tourner le tableau d'équipe (réservations exclusives, zones qui se chevauchent refusées), les
sauvegardes, le décor, une tâche de fond et la checklist de publication.

### Organisation

| Dossier | Contenu |
|---|---|
| `gamekit/` | **La bibliothèque Luau** : `shared/` (Net, Util, UIKit, Lang), `core/` (PlayerData, Analytics…), `systems/<système>/`, `runtime/` (installateur, audit, test) |
| `packages/core/` | Le serveur : pont HTTP multi-Studio, 140+ outils (`src/tools/`), et la couche Game Kit (`src/gamekit/` : Blender, équipe, tâches de fond, décor, captures, sauvegardes, économie…) |
| `integrations/blender-mcp/` | blender-mcp (MIT) : l'addon Blender `addon.py` utilisé par les outils `blender_*` (+ son serveur Python d'origine, non requis) |
| `packages/roblox-ultimate-mcp/` | Point d'entrée (commande `roblox-ultimate-mcp`, `setup`, `--install-plugin`, `--install-blender-addon`) |
| `packages/roblox-ultimate-mcp-inspector/` | Édition lecture seule |
| `studio-plugin/` | Plugin Studio (`MCPPlugin.rbxmx` prêt à l'emploi + sources roblox-ts, dont le panneau IA `src/modules/ActivityPanel.ts`) |
| `docs/` | [GAMEKIT.md](docs/GAMEKIT.md) (référence), [CLIENTS.md](docs/CLIENTS.md) |
| `reference/` | Autres serveurs MCP Roblox importés (ancienne base, serveurs Rust officiels), non utilisés par le build |

Ajouter un système : écrire les `.luau` dans `gamekit/systems/<id>/` (`.server.luau` → ServerScriptService,
`.client.luau` → StarterPlayerScripts, sinon ModuleScript), l'ajouter dans `packages/core/src/gamekit/catalog.ts`,
puis `npm run build && npm test`.

### Publier sur npm

C'est ce qui rend possible `npx roblox-ultimate-mcp setup` pour tout le monde (le nom est libre sur npm) :

1. Sur [npmjs.com](https://www.npmjs.com) : *Access Tokens → Generate New Token* (type *Automation*).
2. Sur GitHub : *Settings → Secrets and variables → Actions → New repository secret* `NPM_TOKEN`.
3. *Actions → Publish to npm → Run workflow* (ou pousse un tag `v4.1.0`). Le workflow compile, lance les tests et publie.

Sans GitHub : `npm login` puis `npm publish -w packages/roblox-ultimate-mcp --access public`.

---

## 🩺 Dépannage

| Problème | Solution |
|---|---|
| `Roblox Studio is not connected` | Studio ouvert ? Plugin installé (`npm run install-plugin`) ? Requêtes HTTP autorisées ? Clique **Connect** |
| « Saving is OFF » dans la sortie | Normal en Studio non publié : publie puis active *Enable Studio Access to API Services* pour tester la sauvegarde |
| L'IA ne voit pas un outil | Profil `starter` : `find_tools` puis `call_tool`, ou `set_tool_profile full` |
| `test_game` ne s'arrête pas | Appuie sur **Stop** dans Studio puis relance ; `check_game` signale un reste de runner de test |
| Deux IA en même temps | Supporté : la 2e instance passe en mode proxy et partage le même Studio ; organise-les avec `team` |
| `blender_status` : `connected: false` | Blender ouvert ? Addon activé (`npm run install-blender-addon`) ? N → **MCP for Blender** → **Connect** ; port 9876 libre (ou `BLENDER_PORT`) |
| `look_at_game` sans image | Studio en mode Édition, vue 3D visible, **Paramètres du jeu → Sécurité → Allow Mesh / Image APIs** ✅ |
| Un changement a tout cassé | `backup_game { action: "list" }` puis `restore` (ou Ctrl+Z) |
| `failed to connect to roblox studio: -32000` | Sans gravité : c'est le lien optionnel vers le MCP officiel de Studio. Pour le couper : `ROBLOX_MCP_HOOK=0` |
| Un son/une animation ne se charge pas | `check_assets` : l'asset est privé ou appartient à un autre créateur ; utilise un asset public ou le tien |
| Le jeu rame sur téléphone | `optimize_game`, puis `optimize_game { apply: [...] }` et `test_game { device: "phone" }` |
| Le bouton « Annuler l'action de l'IA » est gris | La dernière modification vient de toi (Studio annule dans l'ordre) : fais d'abord Ctrl+Z sur la tienne |
| `test_game { players: 2 }` refuse de démarrer | Studio trop ancien (test multijoueur indisponible) : mets Studio à jour ; sinon Test → Clients and Servers à la main |

---

## Crédits & licence

MIT. Serveur et plugin basés sur [6xvl/robloxstudio-mcp-server](https://github.com/6xvl/robloxstudio-mcp-server)
(lui-même issu de [boshyxd/robloxstudio-mcp](https://github.com/boshyxd/robloxstudio-mcp) et
[Chrrxs/robloxstudio-mcp](https://github.com/Chrrxs/robloxstudio-mcp)), addon Blender de
[ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp), et [luau-web](https://github.com/xNasuni/luau-web)
pour la compilation Luau hors-ligne. Détails : [NOTICE.md](NOTICE.md).
