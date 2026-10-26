# Suivi du travail : round 3

Ce fichier dit ce qui est fait, ce qui reste et comment reprendre. Il sert à continuer le travail si la session s'arrête, que ce soit toi, moi ou une autre IA qui reprenne.

- **Dépôt :** `artioramouche-glitch/roblox`
- **Branche :** `claude/charming-johnson-0o1yse`
- **PR :** https://github.com/artioramouche-glitch/roblox/pull/1 (on met à jour cette PR, on n'en crée pas d'autre)
- **Derniers commits déjà poussés :** `b248f1f` (économie de tokens et aide au code), `69836d4` (Blender, travail en équipe, tower defense et farming)
- **État du round 3 :** terminé. Le code, les guides de l'IA, la doc en français et la vérification complète sont faits, commités et poussés. Il ne reste que les tests dans le vrai Studio et le vrai Blender (voir plus bas).

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

## ✅ Finition du round 3 (faite)

1. **Guides lus par l'IA** mis à jour : `knowledge.ts` (workflow, testing, blender, publishing, design), le plan de
   `roblox_start_here` et les instructions du serveur (`mcp-extras.ts`). Ils couvrent les 3 nouveaux modèles, les
   systèmes de rétention, `game_notes`, `test_game {players, device}`, `check_assets`, `optimize_game` et
   `blender_animation`.
2. **Vérification complète :**
   - `npm run build` : OK.
   - `npm test` : 107 tests serveur et 89 tests Game Kit, tous verts.
   - `npm run gamekit:smoke` : SMOKE OK.
   - Intégration Lune (faux Studio) : les 11 jeux s'installent sans avertissement, `check_game` est CLEAN.
   - Validation des installateurs contre la base de classes Roblox : 119 cas, 0 échec, 6 796 instances.
   - Test de traduction : LANG OK.
   - luau-lsp : 0 diagnostic.
   - `npm run lint` : 3 erreurs, toutes dans du code importé de 6xvl que ce round n'a pas touché (`bridge-service.test.ts` et `tools/index.ts`). Il y a aussi des avertissements `any` qui existaient déjà.
3. **Doc en français :** README (nouvelles sections Qualité, Panneau IA, Publier sur npm, chiffres à jour : 11 jeux, 28 systèmes, 53 pièces, profils 38 / 102 / 182 outils), QUICKSTART, docs/CLIENTS. AGENT.md est en anglais parce qu'il est destiné aux IA. `docs/GAMEKIT.md` est régénéré depuis le code.
4. Commit, push et mise à jour de la description de la PR #1.

## 👉 Prochaine étape possible
- Publier le paquet sur npm, pour que `npx roblox-ultimate-mcp setup` marche pour tout le monde. Il faut ajouter le secret `NPM_TOKEN` dans GitHub, puis lancer Actions > Publish to npm.

## ✅ Round 4 (fait) : corrections, traductions, codes, social, flèche de quête

1. **Relecture du code du round 3.** Un bug corrigé dans les quêtes : quand une même stat servait à une quête
   « Gagner N » et à une quête « Atteindre N », une seule écoute était enregistrée. Selon l'ordre de la liste, la
   progression de « Gagner » pouvait alors ne jamais être comptée.
2. **Traductions FR/ES/PT/DE** des textes des nouveaux systèmes : quêtes, XP, course, pêche, craft, noms des
   objets et des poissons, titres des quêtes des modèles, codes, invitations. La file des quêtes, la barre d'XP et
   le panneau de course passent maintenant par le traducteur. Des cas ont été ajoutés au test Lune `test-lang`.
3. **Système `codes`** : fenêtre 🎟 où le joueur saisit un code cadeau.
   - Chaque joueur ne peut utiliser un code qu'une fois (c'est sauvegardé).
   - La casse ne compte pas, une date d'expiration et un niveau minimum sont possibles.
   - Un seul essai par seconde, pour empêcher de deviner les codes.
4. **Système `social`** :
   - +10 % de gains par ami présent dans le serveur (jusqu'à +50 %) ;
   - bouton 👥 d'invitation, récompensé une fois par jour ;
   - bonus pour les membres de ton groupe Roblox (`Config.Social.GroupId`) ;
   - le bonus en cours s'affiche sur le bouton.
5. **Flèche de guidage des quêtes** : un rayon lumineux et un 📍 montrent où aller pour la quête en cours.
   - Les quêtes « Toucher » pointent vers leur QuestTarget.
   - Les autres utilisent `Target`, par exemple `"tag:FishingSpot"`, `"tag:ResourceNode/Node=Tree"` ou un chemin.
   - Les quêtes des modèles pêche et survie ont reçu leurs cibles, et un test vérifie qu'elles existent dans le monde.
6. **Boutons du HUD adaptés aux téléphones** : sur un petit écran, les boutons rapetissent et passent sur deux
   colonnes. Avant, une seule colonne de 68 px sortait de l'écran d'un téléphone dès 5 boutons.
7. `codes` et `social` sont ajoutés à 9 modèles sur 11 (pas tycoon, qui utilise Cash, ni horror_escape).
8. **Vérification** :
   - build OK ;
   - 107 tests serveur et 90 tests Game Kit, tous verts ;
   - smoke OK, intégration Lune OK (check_game CLEAN) ;
   - 121 installateurs validés (6 906 instances) ;
   - luau-lsp : 0 diagnostic ;
   - lint : toujours les 3 erreurs dans le code 6xvl, que ce round n'a pas touché.

## ✅ Génération 3D à partir d'images (2026-10-21)

`blender_assets {action: "generate"}` accepte maintenant `images` (images de référence, par exemple faites avec
Gemini) en plus de `query`. Code dans `packages/core/src/gamekit/blender.ts` (`referenceImages`).
- **Hyper3D (Rodin)** : plusieurs vues d'un même objet. Les chemins locaux sont envoyés en `[extension, base64]`
  (Rodin Mode « hyper3d.ai » dans l'addon), les URLs telles quelles (mode « fal.ai »). Le texte devient optionnel.
- **Hunyuan3D** : une seule image (chemin ou URL). Le texte est alors ignoré, parce que l'API refuse les deux ensemble.
- **Sécurité** : seuls les chemins absolus de fichiers .png/.jpg/.jpeg/.webp qui existent sont acceptés, puisque
  leur contenu part vers une API externe. Pas de mélange URLs + fichiers.
- Guide `roblox_guide blender`, README et AGENT.md mis à jour.
- Vérification : typecheck OK, build OK, 107 tests serveur et 91 tests Game Kit (nouveau test avec le faux addon).
- **À tester en vrai** : une génération Hyper3D et une Hunyuan3D à partir d'une image, avec les clés dans l'addon.

## ✅ Sons Mirelo, relief de carte, sécurité du pont (2026-10-22)

- **`make_sound`** (`packages/core/src/gamekit/sound.ts`, profil starter) : API Mirelo text-to-SFX v3
  (`MIRELO_API_KEY`, sfx-2.0, sfx-1.6 pour les boucles) → fichier mp3 → `upload_asset` Audio → `Sound` placé.
  Sans clé : mode `plugin` (sélectionne l'objet, donne les étapes du plugin Mirelo) puis `collect` (trouve les
  nouveaux sons de SoundService et les déplace). Guide `roblox_guide sound`.
- **Relief de carte** : `set_environment { features }` (`environment.ts`, `featurePayload`) : mountain, hill, lake,
  river, road, path, plateau, paint. Chaque élément est dans son propre `pcall` : un échec n'arrête pas les autres.
  Guide `roblox_guide map`.
- **Critique de Gemini, ce qui touchait vraiment notre code** :
  - le pont HTTP refuse les requêtes de navigateur venant d'un autre site (avant : `cors()` ouvert, donc une page web
    pouvait lancer du Luau dans Studio) ;
  - une requête épinglée sur un Studio qui se déconnecte échoue tout de suite au lieu d'attendre 30 s ;
  - `/poll` enregistre un plugin inconnu avec le rôle qu'il annonce (avant : toujours `edit`) ;
  - plugin : `print("a", nil, "b")` garde tous les arguments ; une réponse perdue est signalée dans Output.
  - Le reste vise des copies de `reference/` (serveur Rust, blueprint) qui ne sont pas livrées : non touché.
- Correction d'une erreur de type laissée dans `blender.ts` (`merge` manquant dans `buildInStudio`).
- Vérification : typecheck OK, build OK, 110 tests serveur et 97 tests Game Kit. Plugin recompilé et réinstallé.
- **À tester en vrai** : une génération Mirelo avec une clé, le mode plugin avec le vrai plugin Mirelo (vérifier que
  le son arrive bien dans SoundService), une carte avec montagne + lac + rivière + route.

## ✅ Figma, références visuelles, VFX, toutes les IA (2026-10-25)

- **`design_refs`** (`gamekit/refs.ts`) : cherche dans la bibliothèque d'images « roblox-ai » (dépôt GitHub de
  ~6 000 images : styles d'UI, VFX, animations, miniatures par genre, docs Studio). Trouvée dans
  Téléchargements/roblox-ai-main ou via `ROBLOX_REFS_DIR`. Renvoie les chemins ; `show: true` joint les 3 premières images.
- **`figma`** (`gamekit/figma.ts` + dossier `figma-plugin/`) : pont avec un plugin Figma de développement
  « Roblox MCP Bridge » qui interroge le serveur sur localhost (comme le plugin Studio). `draw` dessine une spec
  build_ui dans Figma, `read`/`import` transforme le cadre sélectionné en spec build_ui (positions en fractions d'écran,
  boutons, textes liés `{stat:Coins}`, actions dans les noms `[toggle:X]`, images exportées en PNG). Marche dans
  toutes les applis et en plan Figma gratuit. Le MCP officiel de Figma refuse OpenCode/Qoder (liste blanche) et limite
  la lecture en gratuit : c'est pour ça qu'on passe par un plugin.
- **`make_vfx`** (`gamekit/vfx.ts`) + **`Util.vfx(name, cible, secondes)`** : 11 effets prêts (textures livrées avec
  Roblox, aucun upload), modèles dans `ReplicatedStorage/GameKit/Effects`. Mode `plugin` + `collect` pour les effets
  faits avec le plugin gratuit **VFX Studio** (attributs `EmitCount`/`EmitDelay`).
- **Plugin Figma ajouté automatiquement** : `npm run install-figma-plugin` (et `npm run setup`) l'inscrit dans
  `%APPDATA%\Figma\settings.json` (`localFileExtensions`, même format que l'import manuel, lu dans le code de Figma
  bureau 126.10). Figma doit être fermé, sinon il réécrit le fichier : la commande le détecte et demande de le fermer.
- **Lancement automatique du plugin Figma (Windows)** : Figma ne démarre jamais un plugin tout seul. Le plugin laisse
  un bouton de relance dans le fichier (`setRelaunchData`) ; le serveur qui tient le port lance un petit script
  PowerShell qui, tant que le pont n'est pas connecté, trouve ce bouton dans l'arbre d'accessibilité de Figma (UI
  Automation) et le clique. Testé à froid : connecté 33 s après le lancement de Figma. Le clavier a été essayé
  d'abord et échoue en AZERTY (`Ctrl+/`, `Ctrl+Alt+P`). Coupure : `ROBLOX_MCP_FIGMA_AUTOSTART=0`.
- **Pont Figma qui reste connecté quand Figma est caché** : Chromium ralentit les minuteries d'une fenêtre cachée
  (jusqu'à une fois par minute après 5 min), donc l'ancien plugin (une requête par seconde) passait « déconnecté ».
  Le plugin fait maintenant une requête longue que le serveur garde ouverte jusqu'à 20 s (`/figma/poll?wait=`) et la
  relance aussitôt : une requête ouverte n'est pas ralentie.
- **`build_ui`** : nouveau champ `textAlign` (left/right).
- **Setup** : configure aussi Qoder (`~/.qoder/settings.json`, vérifié dans le code de l'appli), Gemini CLI,
  Antigravity (`~/.gemini/config/mcp_config.json`), VS Code (`servers`), Cline, Roo Code, Kiro, LM Studio, Codex (TOML).
- Guides `roblox_guide figma` et `vfx`, instructions serveur et `design` mis à jour.
- Vérification : typecheck OK, build OK, 111 tests serveur, 111 tests Game Kit (12 nouveaux), 3 tests setup ; test de
  bout en bout (serveur réel + faux plugin Figma en HTTP) OK.
- **À tester en vrai** : importer `figma-plugin/manifest.json` dans Figma bureau, `figma draw` puis `figma import` ;
  `make_vfx` de chaque effet dans Studio (le rendu des textures `explosion01_*` et `forcefield_*`) ; un effet fait avec
  VFX Studio puis `collect`.

## ✅ Images de référence → modèle mesuré dans Blender (2026-10-26)

- Le skill **blender-image-to-3d** (Majid Manzarpour, MIT) est copié tel quel dans `integrations/blender-image-to-3d`
  (et dans `blender/image-to-3d` du paquet npm). Il construit un asset par phases (brief, calibration, blockout,
  formes, topologie, UV et baking, rig, export) et chaque phase passe sur des chiffres : rendus comparés à l'image de
  référence (IoU de silhouette, largeurs à 10 hauteurs), pas à l'œil.
- Outil **`blender_image_to_3d`** (`gamekit/image3d.ts`) : `guide` (le skill et ses références), `run` (ses scripts,
  lancés dans un Blender en arrière-plan : la scène ouverte n'est pas touchée), `build` (écrit et lance
  `<asset>/build/<phase>.py` à partir du modèle du skill), `load` (ajoute LOW + RIG_DEF dans le Blender ouvert, dans une
  collection au nom de l'asset, sans les LOD1+ ; un rechargement remplace l'ancienne copie) puis `blender_to_roblox`.
- `compose_review.py` demande Python + Pillow, absents sur ce PC : `scripts/compose_review_bpy.py` fait la même planche
  et les mêmes mesures dans le Python de Blender (numpy). Blender est trouvé via `BLENDER_BIN`, le Blender connecté
  (`bpy.app.binary_path`) ou `Program Files\Blender Foundation`. Refusé en safe mode, sauf `guide`.
- Guide **`roblox_guide image3d`** : les phases adaptées à Roblox (mètres → studs, < 20k triangles par maillage,
  textures 1024, pas de LOD), et une partie **Maps** (chaque pièce passe les contrôles, puis assemblage dans Blender et
  `blender_to_roblox { keepLayout, merge }`). Guides `blender` et `reference`, instructions serveur et docs mis à jour.
- Vérification : typecheck et build OK, 111 tests serveur, 117 tests Game Kit (6 nouveaux), 4 tests setup. Test réel
  avec Blender 5.2 (`BLENDER_BIN=... npm test`) : un œuf conforme passe (IoU 0,99), une boule échoue (IoU 0,67), un
  build cassé renvoie l'erreur Python.
- **À tester en vrai** : un asset complet depuis une planche Gemini jusqu'à Studio (`bake_maps`, `world_gate`,
  `load` dans le Blender ouvert, puis `blender_to_roblox`).
- **Après le test du coffre dans le vrai Blender** (même jour, note Obsidian « 10 - Leçons image vers 3D ») :
  - `make_matte_bpy.py` : détoure une référence qui n'est pas sur fond blanc (sur une capture du viewport, un coffre
    juste donnait IoU 0,27) ; `fit_camera_bpy.py` : trouve `--ref-cam` d'une image en perspective (affine autour des
    3 meilleurs candidats) ; `review_render.py` en Standard (AgX délavait les couleurs cartoon). Liste dans
    `integrations/blender-image-to-3d/LOCAL-CHANGES.md`.
  - `load` garde l'emplacement de la copie précédente (avec mise à jour de `matrix_world`, sinon décalage de 22 cm) ;
    `build` prévient quand `asset-brief.md` manque ; guide `image3d` : planche 4 vues d'abord, matte, fit_camera,
    budget dès les formes, métal 0 en cartoon, un mesh par matériau et pièce mobile.
  - Coffre : IoU 0,275 → 0,924, 3 236 → 1 472 triangles. Tests réels (`BLENDER_BIN=...`) étendus à ces cas.
- **Deuxième passe, les détails** (même jour) :
  - `compose_review_bpy.py --detail` : grille de cases (r1 c1 en haut à gauche), détail relatif (force des contours
    rapportée à la moyenne de chaque image) et couleur médiane après alignement de l'exposition ; carte DETAIL sur la
    planche (rouge = détail manquant, bleu = couleur/pièce), score et liste des cases dans le JSON.
  - `assets/detail_kit.py`, ajouté à chaque script de build : `hex_bolt`, `bolt_grid`, `bolt_row`, `metal_plate`,
    `corner_cap`, `plank_stack`, `arch_points`, `prism`, `strap`, `tube`, `padlock`, `ring_handle`, `merge`,
    `tri_count` ; `guide template` les liste (`detailKit`).
  - Guide `image3d` : kit, contrôle des détails depuis la caméra de la référence, budget selon le niveau de détail.
  - Coffre refait avec le kit, budget 3 000 : IoU 0,949, largeurs ±0,047, détail 0,74, 2 904 triangles. Reste et
    leçons : note Obsidian « 10 - Leçons image vers 3D ». Le zip threejs-skills (connaissances three.js r186) servira
    pour une future page d'aperçu `/preview`, pas pour modéliser.

## ⚠️ À tester par toi dans le vrai Studio et le vrai Blender

Ces points ne peuvent pas être vérifiés ici :

- **Karts :** la conduite (vitesse, virages, stabilité), sur PC et sur mobile.
- **Pêche :** le bouton REEL au bon moment, sur téléphone.
- **Codes et invitations :** saisir `WELCOME` dans la fenêtre 🎟 ; le bouton 👥 (les invitations ne marchent que dans le jeu publié).
- **Flèche de quête :** dans le modèle `fishing`, la flèche doit mener au point de pêche, puis au marché, puis à la boutique.
- **Boutons sur téléphone :** avec `test_game {device: "phone"}`, aucun bouton ne doit sortir de l'écran.
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

> « Lis SUIVI-TRAVAIL.md pour savoir où en est le projet. »

Puis donne-lui la suite : tes retours de test dans Studio, ou de nouvelles idées.
