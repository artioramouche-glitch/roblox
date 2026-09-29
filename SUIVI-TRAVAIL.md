# Suivi du travail : round 3

Ce fichier dit ce qui est fait, ce qui reste et comment reprendre. Il sert à continuer le travail si la session s'arrête, que ce soit toi, moi ou une autre IA qui reprenne.

- **Dépôt :** `artioramouche-glitch/roblox`
- **Branche :** `claude/charming-johnson-0o1yse`
- **PR :** https://github.com/artioramouche-glitch/roblox/pull/1 (on met à jour cette PR, on n'en crée pas d'autre)
- **Derniers commits déjà poussés :** `b248f1f` (économie de tokens et aide au code), `69836d4` (Blender, travail en équipe, tower defense et farming)
- **État du round 3 :** le code décrit ci-dessous est commité et poussé sur la branche, en commit « travail en cours ». Les étapes de la partie « Reste à faire » ne sont pas encore faites.

## Ta demande pour ce round

1. Économiser des tokens entre les sessions, avec une mémoire du projet (`game_notes`).
2. Des jeux plus riches :
   - quêtes, inventaire, œufs et familiers, niveaux et XP ;
   - trois modèles : course, pêche, survie coopérative avec craft ;
   - une vérification des sons et animations.
3. La qualité avant publication : test à 2 joueurs et sur mobile, et `optimize_game`.
4. Le confort :
   - `npx roblox-ultimate-mcp` ;
   - un panneau dans le plugin Studio ;
   - des personnages riggés et des animations depuis Blender.

## ✅ Fait (code écrit et testé automatiquement)

### 2. Mémoire du projet
- Outil **`game_notes`** : `packages/core/src/gamekit/notes.ts`. Il gère les sections idea, decisions, todo, done, notes et history. Les notes sont stockées dans la place, sous `ServerStorage/GameKitNotes`.
- `roblox_start_here` renvoie la mémoire. Chaque modification réussie (create_game, add_system, write_script…) ajoute une ligne à `history`. On désactive ça avec `ROBLOX_MCP_HISTORY=0`.

### 3. Nouveaux systèmes (dossier `gamekit/systems/`)
| Système | Fichiers | Rôle |
|---|---|---|
| `inventory` | `Inventory.luau`, `InventoryServer.server.luau`, `Inventory.client.luau` | Objets sauvegardés, fenêtre 🎒, vente (tag `ItemSell`) |
| `levels` | `Levels.server.luau`, `Levels.client.luau` | XP, niveaux, barre d'XP, récompenses |
| `quests` | `Quests.server.luau`, `Quests.client.luau` | Quêtes Earn, Reach, Have et Touch (tag `QuestTarget`), avec un suivi à l'écran |
| `pets` | `Pets.server.luau`, `Pets.client.luau` | Œufs (tag `EggStand`), familiers aléatoires, multiplicateurs, fenêtre 🐾 |
| `racing` | `Racing.server.luau`, `Racing.client.luau` | Course avec tours, points de passage (`RaceCheckpoint` Order), départ (`RaceGrid`), arrivée (`RaceFinish`) et karts |
| `fishing` | `Fishing.server.luau`, `Fishing.client.luau` | Pêche : lancer, touche puis bouton REEL. Poissons par zone (`FishingSpot` Zone), canne améliorable |
| `crafting` | `Crafting.server.luau`, `Crafting.client.luau` | Récolte (`ResourceNode`), craft (fenêtre 🔨), outils, constructions (feu de camp, mur, pics) et faim |

- Enemies a une nouvelle option `Waves.DayNight` : il fait jour pendant les pauses et nuit pendant les vagues.
- Le catalogue est à jour dans `packages/core/src/gamekit/catalog.ts`.
- Nouvelles pièces dans `world.ts` : egg_stand, item_sell, quest_target, race_checkpoint, race_finish, race_grid, fishing_spot, resource_node, crafting_table et campfire.
- Nouveaux mondes : `race_track`, `fishing_lake` et `survival_camp`.
- Nouveaux modèles dans `templates.ts` : **`racing`**, **`fishing`** et **`craft_survival`**.
- `test_game` a des sondes automatiques pour tous ces systèmes, dans `gamekit/runtime/TestRunner.server.luau`.

### 4. Qualité avant publication
- **`test_game {players: 2}`** : un vrai test multijoueur, lancé par le plugin avec `ExecuteMultiplayerTestAsync`. Il vérifie que tous les joueurs sont chargés, qu'ils sont apparus et qu'ils se voient entre eux.
- **`test_game {device: "phone"}`** : le jeu tourne dans le simulateur d'appareil, sur le plus petit téléphone disponible. Le test détecte les boutons trop petits, l'interface hors de l'écran et le texte illisible. Le simulateur est remis dans son état d'origine à la fin. Code dans `playtest.ts` et `TestProbe.client.luau`.
- **`check_assets`** (`quality.ts`) :
  - il vérifie qu'un son, une animation ou une image se charge vraiment (`PreloadAsync` et `GetProductInfoAsync`) ;
  - il vérifie aussi que les animations appartiennent au propriétaire du jeu ;
  - on peut lui donner des ids, ou le laisser scanner tout le jeu.
- **`optimize_game`** (`quality.ts`) :
  - il fait un rapport pour les téléphones d'entrée de gamme : pièces, physique, ombres, lumières, particules, streaming, scripts lourds ;
  - il propose des corrections sûres avec `apply: ["shadows","lights","particles","streaming","technology"]`, qu'on annule d'un seul Ctrl+Z.
- `publish_checklist` vérifie maintenant aussi : le test à 2 joueurs, le test sur téléphone, les performances et les assets.

### 5. Confort
- **`npx roblox-ultimate-mcp setup`** (`packages/roblox-ultimate-mcp/src/setup.ts`) :
  - il installe le plugin Studio ;
  - il configure Claude Desktop, Cursor et Windsurf sans effacer les autres serveurs, et garde une copie `.bak` des fichiers modifiés ;
  - il affiche la commande pour Claude Code ;
  - avec `--blender`, il installe aussi l'addon Blender.

  J'ai testé tout ça avec un vrai `npm pack`, puis une installation dans un dossier vide : ça marche, et le serveur installé répond en MCP.
- **Pour que `npx` fonctionne pour tout le monde, il faut publier sur npm.** Le nom `roblox-ultimate-mcp` est libre. Deux façons de faire :
  - lancer le workflow `.github/workflows/publish.yml`, après avoir ajouté le secret `NPM_TOKEN` dans GitHub ;
  - ou faire `npm login` puis `npm publish -w packages/roblox-ultimate-mcp --access public`.
- **Panneau « IA : activité » dans le plugin Studio** (`studio-plugin/src/modules/ActivityPanel.ts` et `Activity.ts`) :
  - il montre ce que fait l'IA, le tableau d'équipe et la liste TODO de game_notes ;
  - le bouton **« Annuler l'action de l'IA »** n'annule que les changements faits par l'IA, dont l'étape d'annulation s'appelle `MCP: AI ...` ;
  - côté serveur, `packages/core/src/gamekit/activity.ts` ajoute une étiquette à chaque appel ;
  - le plugin est recompilé dans `studio-plugin/MCPPlugin.rbxmx`.
- **Blender riggé et animations** (`packages/core/src/gamekit/blender.ts`) :
  - `blender_to_roblox` détecte l'armature. Il exporte le maillage et les os (sans os terminaux, 4 influences maximum), puis ajoute un Animator dans Studio ;
  - nouvel outil **`blender_animation`** : il transforme une action Blender en KeyframeSequence dans `ServerStorage/GameKit/Animations`, avec un id temporaire pour tester tout de suite ;
  - il exporte aussi un FBX animé, qu'on peut importer avec l'Animation Editor.

### Vérifications passées
- Types Luau : `luau-lsp`, **0 diagnostic**. La syntaxe des 74 fichiers est bonne.
- Tests gamekit (jest) : **tous verts**, avec en plus des tests pour les nouveaux mondes, les modèles, check_assets, optimize_game, les tests multijoueur et téléphone, et Blender (Python validé par un vrai parseur Python).
- Intégration dans le faux Studio (Lune) : les 11 modèles, y compris racing, fishing et craft_survival, s'installent **sans avertissement**. `check_game` est CLEAN.
- `tsc` : OK. Le plugin se compile avec `rbxtsc` sans erreur.

## ⏳ Reste à faire (tâche 21)

1. **Mettre à jour les guides que lit l'IA** :
   - dans `packages/core/src/gamekit/knowledge.ts`, `tools.ts` (le plan de `roblox_start_here`) et `mcp-extras.ts` ;
   - y mentionner `test_game {players:2}`, `{device:"phone"}`, `check_assets`, `optimize_game`, `blender_animation` et les 3 nouveaux modèles ;
   - rester court, pour économiser les tokens.
2. **Vérification complète**, depuis la racine du dépôt :
   ```bash
   npm run build
   npm test                      # jest core + gamekit
   npm run lint
   npm run gamekit:smoke
   LUNE=<chemin lune> npm run gamekit:integration
   LUAU_LSP=<chemin luau-lsp> npm run gamekit:verify
   ```
   Problèmes connus qui existaient avant ce round et ne viennent pas de nous : un handle ouvert dans `bridge-service.test`, et 2 erreurs de lint dans `packages/core/src/tools/index.ts`.
3. **Documentation en français** : README, AGENT.md, QUICKSTART.md, docs/CLIENTS et doc GameKit à régénérer avec `npm run gamekit:docs`. On y met les nouveaux systèmes, modèles et outils, `npx ... setup`, le panneau Studio et Blender riggé.
4. **Commit et push** sur `claude/charming-johnson-0o1yse`, puis **mise à jour de la description de la PR #1**.

## ⚠️ À tester par toi dans le vrai Studio et le vrai Blender

Ces points ne peuvent pas être vérifiés ici :

- **Karts :** la conduite (vitesse, virages, stabilité), sur PC et sur mobile.
- **Pêche :** le bouton REEL au bon moment, sur téléphone.
- **Craft :** les constructions posées devant le joueur, et la faim.
- **Test à 2 joueurs :** il faut un Studio récent (`ExecuteMultiplayerTestAsync`).
- **Test téléphone :** vérifier que le simulateur d'appareil s'applique bien pendant le Play.
- **Panneau IA :** vérifier que le bouton Annuler n'annule que les actions de l'IA.
- **`check_assets` :** vérifier le résultat sur un son privé et sur une animation d'un autre créateur.
- **Blender riggé :**
  - importer un personnage riggé ;
  - lancer `blender_animation` et vérifier que les poses ont le bon sens (rotations et axes) ;
  - si ce n'est pas le cas, utiliser le FBX animé avec Animation Editor > Import > From FBX Animation.

## Pour reprendre dans une nouvelle session

Dis à l'IA :

> « Lis SUIVI-TRAVAIL.md, puis termine la partie "Reste à faire" : guides, vérification complète, docs en français, commit, push et mise à jour de la PR #1. »
