# 🧠 STEAL A BRAINROT: LEGENDS — DOCUMENT MAÎTRE V2

> **Version :** 2.0 | **Statut :** Bible de production complète — édition exhaustive
> **Usage :** Ce document est auto-suffisant. Une IA équipée d'un MCP Blender et d'un MCP Roblox Studio peut construire le jeu complet en suivant la PARTIE H.
> **Règle absolue pour l'IA exécutante :** suivre les étapes DANS L'ORDRE, valider chaque étape avec le critère ✅ avant de passer à la suivante, et ne JAMAIS faire confiance au client (tout le gameplay — économie, vol, combat PvP — est simulé et validé côté serveur).

---

## 🚀 PROMPT D'EXÉCUTION (à donner à l'IA qui possède les MCP)

```text
Lis ce document maître en entier. Tu vas construire le jeu Roblox "Steal a Brainrot: Legends"
de A à Z en utilisant ton MCP Roblox Studio (scripts, map, UI) et ton MCP Blender (modèles 3D,
export FBX vers D:/SABL_Assets/).

Méthode obligatoire :
1. Exécute le plan de production de la PARTIE H, étape par étape, DANS L'ORDRE (0 → 18).
2. Après chaque étape, présente-moi le résultat et attends ma validation avant de continuer.
3. Respecte EXACTEMENT les configs chiffrées (PARTIES B, C, E, F, G) — elles sont l'équilibrage.
4. Les descriptions de map (PARTIE D) contiennent des prompts prêts à copier ; adapte-les au
   format réel de ton MCP si besoin, mais ne change ni les dimensions ni les couleurs.
5. Sécurité : toute logique gameplay côté serveur, le client ne fait que demander et afficher.
6. Si une information manque, choisis la solution la plus simple et signale-le dans ton rapport.
```

---

## 🆕 CHANGELOG V2 — ce qui a été amélioré

| # | Ajout / Amélioration | Où |
|---|----------------------|-----|
| 1 | **Système PvP complet : Le Colisée Brainrot** (arène 1v1/2v2, combat hybride auto-battle + capacités activables, ultimes, spectateurs) | PARTIE E |
| 2 | **Combat des brainrots** : stats de combat, types élémentaires, 54 capacités signature | PARTIES B + E |
| 3 | **5 maps complètes décrites** : Brainrot Street (M1), Dessert Kingdom (M2), Sushi Abyss (M3), Candy Space (M4) + Colisée PvP — plans ASCII, fiches par zone, palettes hex, props, prompts MCP | PARTIE D |
| 4 | **Bestiaire étendu : 54 brainrots** (30 classiques + 24 inédits répartis sur les mondes 2-4), chacun avec fiche 3D + capacité PvP | PARTIE B |
| 5 | **Clans & Guerres de territoire** (guildes, coffre de clan, guerre hebdo à 3 fronts) | PARTIE F |
| 6 | **Classement Elo + saisons mensuelles + boutique arène + tournoi hebdo à bracket** | PARTIE E |
| 7 | **Architecture technique enrichie** : 6 nouveaux services, remotes PvP, schéma de données V2, code Luau complet | PARTIE G |
| 8 | **Plan de production 19 étapes** (au lieu de 15) avec les étapes PvP, clans et mondes 2-4 | PARTIE H |
| 9 | **Équilibrage PvP** : normalisation des stats en match classé (collection ≠ victoire garantie) | PARTIE E |
| 10 | Œufs par monde (8 au total), nouvelles quêtes PvP, monétisation adaptée | PARTIES B/C/E |

---

## 📑 SOMMAIRE

- **PARTIE A — Vision & Gameplay**
- **PARTIE B — Bestiaire complet (54 Brainrots, 4 mondes)**
- **PARTIE C — Économie, Progression & Monétisation**
- **PARTIE D — Les Maps (5 mondes détaillés : plans, palettes, prompts MCP)**
- **PARTIE E — Système PvP : Le Colisée Brainrot**
- **PARTIE F — Clans & Guerres de territoire**
- **PARTIE G — Architecture technique Roblox (structure + code critique)**
- **PARTIE H — Plan de production A→Z (19 étapes, prompts MCP prêts)**
- **PARTIE I — Checklist de publication + Codes de lancement**

---

# PARTIE A — VISION & GAMEPLAY

## A1. Fiche d'identité

| Champ | Valeur |
|---|---|
| **Nom** | Steal a Brainrot: Legends |
| **Pitch** | Collecte des Brainrots italiens légendaires, fusionne-les, bâtis ton empire, vole ceux des autres… et deviens champion du Colisée ! |
| **Genre** | Collecte + Fusion + Tycoon + Steal + **PvP en arène** |
| **Plateforme cible** | Mobile-first (80% des joueurs), PC |
| **Taille serveur** | 8 joueurs (mondes) — l'arène instancie des matches séparés |
| **Session visée** | 20-40 min, rétention quotidienne + rendez-vous hebdo (tournoi samedi, guerre de clans dim-jeu) |
| **Références** | Steal a Brainrot, Pet Simulator 99, Adopt Me (économie), Fortnite (Elo/saisons) |
| **Cible** | 9-15 ans, culture brainrot/TikTok |

## A2. Les 4 piliers de design

1. **DOPAMINE** → tirages d'œufs avec raretés (Commun → SECRET), annonces serveur sur les Secrets, fusions spectaculaires.
2. **DRAMA** → vol de brainrots, poursuites en zigzag, vengeances trackées — le carburant à clips TikTok/YouTube.
3. **PROGRESSION** → base qui grossit, 5 tiers de fusion, rebirths, 4 mondes à débloquer, collection à compléter.
4. **COMPÉTITION (nouveau)** → le Colisée : arène PvP où les brainrots se battent, classement Elo, saisons, tournoi hebdo, guerres de clans. Donne une raison de jouer AU-DELÀ du grind.

> Pourquoi ce 4e pilier change tout : dans Steal a Brainrot original, un joueur qui a tout n'a plus rien à faire. L'arène transforme la collection en puissance de combat et crée une boucle compétitive longue durée (classements, saisons, gloire) sans casser les 3 autres piliers — le joueur casual n'y est jamais forcé.

## A3. Les boucles de gameplay

| Boucle | Durée | Contenu |
|---|---|---|
| **COURTE** | 2 min | Revenu passif → acheter œuf → tirage → placer sur piédestal → fusion si 3 identiques |
| **MOYENNE** | 20 min | Upgrader base → cycle bouclier → aller voler → fuir avec le butin → sécuriser → **2-3 matchs au Colisée** |
| **LONGUE** | jours | Rebirth → multiplicateurs → mondes 2-4 → collection complète → build PvP optimal |
| **HEBDO** | semaine | Tournoi du samedi → guerre de clans dim-jeu → récompenses de fin de saison (mensuelle) |

## A4. Le système de Vol (machine à états — CŒUR DU JEU)

```text
VOLEUR : IDLE ──[E sur brainrot, bouclier cible OFF]──> PORTAGE (vitesse -30%, timeout 60s)
               ──[pose 5s sur son piédestal]──────────> VOL SÉCURISÉ ✅
               ──[3 coups reçus / timeout 60s]────────> LÂCHÉ (brainrot au sol, ramassable)

CIBLE  : BOUCLIER (dôme bleu, 5 min) ──> ALERTE (dôme clignote rouge, 60s)
         ──> VULNÉRABLE (8 min, vol possible) ──> retour BOUCLIER
```

**Anti-frustration obligatoire :**
- Débutants : ni voler ni être volé avant niveau 5 **ET** 1h de jeu cumulé
- Cooldown vol : 60s par voleur / 30s par cible
- Rachat du brainrot volé : prix ×1.5, disponible 10 min
- Tracker de vengeance : notification "X t'a volé Y" + bouton téléportation directe
- Les Secrets ne sont volables que sur cible vulnérable et coûtent 3× le cooldown au voleur
- **Pendant un match d'arène, les 3 brainrots engagés sont invulnérables au vol** (pas de frustration double)

## A5. La base joueur (composants)

| Composant | Niveaux | Effet | Coûts (courbe ×4) |
|---|---|---|---|
| Piédestaux (slots) | 3 → 25 | Placer les brainrots | 5K → 50M |
| Générateur bouclier | 1 → 3 | Protection 5/6/7 min | 50K / 5M / 500M |
| Alarme | 1 → 3 | Notifie tout le serveur au vol | 25K / 2M / 200M |
| Tourelle | 1 → 5 | Tire sur les voleurs, 30 studs, 1 tir/s | 100K → 100M |
| Piège à colle | 1 → 3 | Ralentit voleurs 50% pendant 5s | 30K / 3M / 300M |
| Coffre-fort | 1 → 5 | Capacité stockage argent | 10K → 10M |
| **Anneau d'entraînement (nouveau)** | 1 → 5 | +2%/niv. stats PvP des brainrots placés | 250K → 250M |
| Décos (12 objets) | — | +2% revenu chacun | 1K → 1M |

## A6. UI — liste des écrans

1. **HUD** : argent + revenu/s, état bouclier, 6 boutons : 🥚Œufs 🏠Base 📦Inventaire 📜Quêtes ♻️Rebirth ⚔️Arène
2. **Boutique d'œufs** : onglets par monde, % affichés (obligatoire), boutons ×1/×10/×50, skip animation
3. **Inventaire** : grille, tri par revenu OU par stats PvP, duplicatas surlignés + bouton FUSIONNER, PLACER/VENDRE/**ENGAGER (PvP)**
4. **Gestion de base** : upgrades avec prix/niveaux
5. **Alerte vol** : plein écran rouge + flèche vers le voleur + bouton "Y ALLER" (téléport)
6. **Portage** : timer circulaire autour du voleur
7. **Rebirth** : gains affichés avant confirmation
8. **Écran d'arène** (nouveau) : file d'attente, sélection des 3 combattants, Elo, historique
9. **Écran de combat** (nouveau) : barres HP des 2 brainrots actifs, jauges de capacité, jauge de foule, boutons CAPACITÉ / SWITCH / ULTIME (≥ 44px)
10. **Écran de clan** (nouveau) : membres, coffre, guerre en cours, chat
11. **Settings** : audio, codes, qualité

Contraintes mobiles : boutons ≥ 44px, texte ≥ 16px, testé en 720p paysage.

## A7. Audio

- Musiques : lobby lo-fi joyeuse / base triomphante / **arène épique percussive (montée de tension)** / **hymne de victoire + défaite (3s)**
- SFX : casse d'œuf (5 variantes par rareté), fusion (fanfare), alarme vol (sirène 2 tons), saisie ("boing"), sécurisation ("cha-ching")
- **Spawn SECRET :** silence 1s → sting orchestral + screen shake serveur, audible partout
- **PvP :** impact de coups (3 sons), activation de capacité (whoosh + flash sonore), ULTIME (impact grave + ralenti 0.3s), foule qui rugit (montée de foule à 50% et 100% de jauge)

---
# PARTIE B — BESTIAIRE COMPLET (54 BRAINROTS, 4 MONDES)

## B0. Conventions 3D (à respecter pour TOUTES les créatures)

- **Échelle : 1 unité Blender = 1 stud Roblox** | Pivot : au sol, centre des pieds
- **Style :** low-poly cartoon, formes primitives arrondies (bevel 0.05), couleurs franches flat, roughness 0.6, metallic 0
- **Yeux :** règle des 20% (gros yeux = mignon/mème) — 2 sphères blanches + pupilles noires décalées
- **Membres :** 2 bras + 2 jambes cylindriques (rayon 0.08, longueur 0.5) sauf mention contraire
- **Polycount :** < 2 000 triangles par créature, < 500 par prop. **Aucune animation Blender** — idles faits en Roblox via TweenService
- **Nommage :** `CRT_<id>` | **Export :** FBX, échelle 1, vers `D:/SABL_Assets/`
- **Rareté → aura en jeu :** Commun/Rare : rien | Épique : particules légères | Légendaire : halo doré | Mythique : particules + lumière | GOD : aura dorée intense | SECRET : aura noire-violette #3A0CA3 + trail + screen shake au spawn

## B0bis. Les 3 Types PvP (triangle des forces)

| Type | Symbole | Bat | Est battu par |
|---|---|---|---|
| **SALÉ** | 🍟 | SUCRÉ (+20% dégâts) | FRUITÉ (-20% dégâts reçus contre lui) |
| **SUCRÉ** | 🍩 | FRUITÉ | SALÉ |
| **FRUITÉ** | 🍌 | SALÉ | SUCRÉ |

Règle simple : le type du brainrot inflige **+20% de dégâts** à celui qu'il bat, et encaisse **-20%** de celui qui le bat. Les 3 types sont répartis dans tout le bestiaire (voir colonne Type).

## B1. TABLEAU MAÎTRE — MONDE 1 : BRAINROT STREET (30 brainrots)

| # | ID | Nom | Rareté | Revenu/s | Type |
|---|----|-----|--------|----------|------|
| 1 | noobini | Noobini Pizzanini | Commun | 10 | SALÉ |
| 2 | tim_cheese | Tim Cheese | Commun | 12 | SALÉ |
| 3 | fluriflura | FluriFlura | Commun | 15 | FRUITÉ |
| 4 | pipi_kiwi | Pipi Kiwi | Commun | 18 | FRUITÉ |
| 5 | talpa | Talpa Di Fero | Commun | 22 | SALÉ |
| 6 | trippi | Trippi Troppi | Rare | 65 | SALÉ |
| 7 | tung_tung | Tung Tung Tung Sahur | Rare | 80 | SALÉ |
| 8 | boneca | Boneca Ambalabu | Rare | 95 | SALÉ |
| 9 | footera | Gangster Footera | Rare | 110 | SALÉ |
| 10 | chim_banana | Chimpanzini Bananini | Rare | 130 | FRUITÉ |
| 11 | cappuccino | Cappuccino Assassino | Épique | 400 | SALÉ |
| 12 | patapim | Brr Brr Patapim | Épique | 480 | FRUITÉ |
| 13 | blueberrini | Blueberrinni Octopusini | Épique | 550 | FRUITÉ |
| 14 | strawberelli | Strawberelli Flamingelli | Épique | 620 | FRUITÉ |
| 15 | burbaloni | Burbaloni Loliloli | Légendaire | 2 500 | SALÉ |
| 16 | bombombini | Bombombini Gusini | Légendaire | 3 000 | SALÉ |
| 17 | frigo_camelo | Frigo Camelo | Légendaire | 3 600 | SALÉ |
| 18 | tukanno | Tukanno Bananno | Légendaire | 4 200 | FRUITÉ |
| 19 | bombardiro | Bombardiro Crocodilo | Mythique | 15 000 | SALÉ |
| 20 | lirili | Lirili Larila | Mythique | 18 000 | FRUITÉ |
| 21 | glorbo | Glorbo Fruttodrillo | Mythique | 22 000 | FRUITÉ |
| 22 | gorillo | Gorillo Watermelondrillo | Mythique | 26 000 | FRUITÉ |
| 23 | tralalero | Tralalero Tralala | Brainrot God | 90 000 | SALÉ |
| 24 | vaca | La Vaca Saturno Saturnita | Brainrot God | 110 000 | SALÉ |
| 25 | sammyni | Sammyni Spyderini | Brainrot God | 130 000 | SALÉ |
| 26 | girafa | Girafa Celestre | Brainrot God | 150 000 | FRUITÉ |
| 27 | los_tralaleritos | Los Tralaleritos | SECRET | 600 000 | SALÉ |
| 28 | chicleteira | Chicleteira Bicicleteira | SECRET | 800 000 | SUCRÉ |
| 29 | la_grande | La Grande Combinazione | SECRET | 1 000 000 | SALÉ |
| 30 | garama | Garama and Madundung | SECRET | 1 500 000 | SALÉ |

## B1b. MONDE 2 : DESSERT KINGDOM (rebirth 3 requis — 8 brainrots inédits)

| # | ID | Nom | Rareté | Revenu/s | Type |
|---|----|-----|--------|----------|------|
| 31 | biscottino | Biscottino Ballerino | Rare | 8 000 | SUCRÉ |
| 32 | gelato_gangsterino | Gelato Gangsterino | Rare | 12 000 | SUCRÉ |
| 33 | tiramisu_tornado | Tiramisù Tornado | Épique | 30 000 | SUCRÉ |
| 34 | macaroni_mago | Macaroni Mago | Épique | 45 000 | SUCRÉ |
| 35 | donut_drago | Donut Drago | Légendaire | 150 000 | SUCRÉ |
| 36 | croissant_crusherino | Croissant Crusherino | Légendaire | 220 000 | SUCRÉ |
| 37 | gateau_guardiano | Gateau Guardiano | Mythique | 900 000 | SUCRÉ |
| 38 | millefeuille_celestre | Millefeuille Célestre | SECRET | 6 000 000 | SUCRÉ |

## B1c. MONDE 3 : SUSHI ABYSS (rebirth 5 requis — 8 brainrots inédits)

| # | ID | Nom | Rareté | Revenu/s | Type |
|---|----|-----|--------|----------|------|
| 39 | onigirino_orcano | Onigirino Orcano | Rare | 150 000 | SALÉ |
| 40 | maki_rayona | Maki Rayona | Rare | 220 000 | FRUITÉ |
| 41 | nigiri_anguilla | Nigiri Anguilla | Épique | 500 000 | SALÉ |
| 42 | tempura_titano | Tempura Titano | Épique | 750 000 | SALÉ |
| 43 | ramen_krakeno | Ramen Krakeno | Légendaire | 2 500 000 | SALÉ |
| 44 | unagi_imperatore | Unagi Imperatore | Légendaire | 4 000 000 | SALÉ |
| 45 | wasabi_wraitho | Wasabi Wraitho | Mythique | 15 000 000 | SALÉ |
| 46 | sushi_shogun | Sushi Shogun Supremo | SECRET | 80 000 000 | SALÉ |

## B1d. MONDE 4 : CANDY SPACE (rebirth 10 requis — 8 brainrots inédits)

| # | ID | Nom | Rareté | Revenu/s | Type |
|---|----|-----|--------|----------|------|
| 47 | bonbonni_bourdonna | Bonbonni Bourdonna | Rare | 3 000 000 | SUCRÉ |
| 48 | chamallow_astronauta | Chamallow Astronauta | Rare | 5 000 000 | SUCRÉ |
| 49 | sucetta_satellita | Sucetta Satellita | Épique | 12 000 000 | SUCRÉ |
| 50 | gommosa_galattica | Gommosa Galattica | Épique | 20 000 000 | SUCRÉ |
| 51 | cotone_cosmico | Cotone Cosmico | Légendaire | 60 000 000 | SUCRÉ |
| 52 | caramel_cometa | Caramel Cometa | Légendaire | 100 000 000 | FRUITÉ |
| 53 | gravita_grandosa | Gravita Grandosa | Mythique | 500 000 000 | SUCRÉ |
| 54 | ourson_galattico | Ourson Galattico | SECRET | 3 000 000 000 | SUCRÉ |

## B2. Les œufs (8 au total, 1 gamme par monde)

| Œuf | Prix | Pool | Odds |
|---|---|---|---|
| 🥚 egg_basic | 100 | noobini, tim_cheese, fluriflura, pipi_kiwi, talpa, trippi | Common 85 / Rare 15 |
| 🥚 egg_street | 8 500 | noobini, trippi, tung_tung, boneca, footera, chim_banana, cappuccino, patapim | Common 10 / Rare 55 / Epic 33 / Legendary 2 |
| 🥚 egg_golden | 150 000 | chim_banana, cappuccino, patapim, blueberrini, strawberelli, burbaloni, bombombini, frigo_camelo, tukanno | Rare 20 / Epic 55 / Legendary 22 / Mythic 3 |
| 🥚 egg_mythic | 5 000 000 | burbaloni, bombombini, frigo_camelo, tukanno, bombardiro, lirili, glorbo, gorillo | Epic 25 / Legendary 50 / Mythic 22 / God 3 |
| 🥚 egg_secret | 250 000 000 | gorillo, tralalero, vaca, sammyni, girafa, los_tralaleritos, chicleteira, la_grande, garama | Legendary 30 / Mythic 35 / God 34.5 / Secret 0.5 |
| 🍰 egg_dessert (M2) | 25 000 000 | Tout le monde 2 | Rare 55 / Epic 33 / Legendary 10 / Mythic 1.9 / Secret 0.1 |
| 🍣 egg_abyss (M3) | 2 000 000 000 | Tout le monde 3 | Rare 55 / Epic 33 / Legendary 10 / Mythic 1.9 / Secret 0.1 |
| 🍬 egg_cosmic (M4) | 200 000 000 000 | Tout le monde 4 | Rare 55 / Epic 33 / Legendary 10 / Mythic 1.9 / Secret 0.1 |

Règles : probabilités TOUJOURS affichées dans l'UI (obligation Roblox). Boutons ×1/×10/×50 + skip animation. Les œufs des mondes 2-4 ne sont achetables que dans leur monde (ajoute un intérêt d'exploration).

## B3. Tiers de fusion (identiques pour tous)

| Tier | Nom | Obtention | Mult revenu | Mult PvP (classé) | Mult PvP (libre) |
|---|---|---|---|---|---|
| 1 | Normal | — | ×1 | ×1 | ×1 |
| 2 | Doré | 3 normaux | ×3 | ×1.15 | ×3 |
| 3 | Arc-en-ciel | 3 dorés (=9) | ×10 | ×1.30 | ×10 |
| 4 | Galaxie | 3 arc-en-ciel (=27) | ×40 | ×1.45 | ×40 |
| 5 | Céleste | 3 galaxie (=81) | ×150 | ×1.60 | ×150 |

> En arène CLASSÉE les tiers sont volontairement aplatis (max ×1.6) : la victoire se joue sur les capacités et le timing, pas sur le grind. En arène LIBRE, les stats brutes s'appliquent — c'est le mode flex/de démonstration.

## B4. Stats de combat PvP (calcul automatique côté serveur)

```text
HP  = BaseHP(rareté)    × WorldMult(monde) × TierMultPvP
ATK = BaseATK(rareté)   × WorldMult(monde) × TierMultPvP
Vitesse d'attaque : toutes les 1.5s (auto-attaque), modifiée par la capacité passive
```

| Rareté | BaseHP | BaseATK | WorldMult |
|---|---|---|---|
| Commun | 300 | 25 | M1 ×1 |
| Rare | 500 | 40 | M2 ×2.5 |
| Épique | 850 | 65 | M3 ×6 |
| Légendaire | 1 400 | 105 | M4 ×15 |
| Mythique | 2 400 | 175 | |
| Brainrot God | 4 000 | 280 | |
| SECRET | 7 000 | 480 | |

Exemple : Tung Tung Sahur Galaxie (classé) = HP 500×1×1.45 = 725, ATK 40×1.45 = 58. Tralalero Céleste (classé) = HP 4000×1.6 = 6 400, ATK 280×1.6 = 448.

---
## B5. FICHES DE MODÉLISATION 3D + CAPACITÉS PvP — MONDE 1

**Template commun à appliquer à CHAQUE modèle :**
> "Créer une collection nommée `CRT_<id>`. Style low-poly cartoon, bevel 0.05 sur toutes les arêtes dures, matériaux flat (roughness 0.6, metallic 0). Yeux : 2 sphères blanches + pupilles noires décalées, taille = 20% de la tête. Membres : 2 bras + 2 jambes cylindriques (rayon 0.08, longueur 0.5) sauf mention contraire. Pivot à l'origine, au niveau du sol. Exporter en FBX `<id>.fbx`, échelle 1, vers `D:/SABL_Assets/`."

**Rappel capacités** (voir PARTIE E) : BURST = dégâts ×3 (cooldown 8s) | SOIN = +40% HP | BOUCLIER = absorbe 2 coups | CONTRÔLE = étourdit 2s. Les variantes surpuissantes ont un cooldown plus long.

## COMMUNS

### CRT_noobini — Noobini Pizzanini (2.5 studs)
**3D :** Noob Roblox classique — torse bleu #1B6FD0, jambes vertes #7CB518, tête jaune ; chapeau pizza (cylindre plat + part de pizza en travers), part de pizza dans la main.
**Idle :** balancement gauche-droite.
**Capacité PvP — "Pizza Slash" (BURST) :** lance une part de pizza tournoyante, dégâts ×3.

### CRT_tim_cheese — Tim Cheese (2.2 studs)
**3D :** Fromage triangulaire jaune #FFD23F avec trous (sphères creusées), sourire géant, calotte blanche de chef, lunettes.
**Idle :** sautille sur place.
**Capacité PvP — "Cheese Melt" (SOIN) :** fond au soleil et récupère 40% de ses HP.

### CRT_fluriflura — FluriFlura (2.5 studs)
**3D :** Grande fleur fuchsia #FF70A6 à 6 pétales, visage joyeux au cœur jaune, jambes-tiges vertes #8AC926, petites feuilles-bras.
**Idle :** tournoie lentement comme une graine.
**Capacité PvP — "Pollen Dodo" (CONTRÔLE) :** nuage de pollen, l'adversaire s'endort 2s.

### CRT_pipi_kiwi — Pipi Kiwi (2 studs)
**3D :** Kiwi coupé en deux — cou vert #7BA428 avec graines noires, dos brun duveteux #8B6F47, yeux énergiques, jambes sauteuses.
**Idle :** rebonds rapides.
**Capacité PvP — "Kiwi Splash" (BURST) :** jets de jus acide — dégâts ×3 ET -10% ATK adverse pendant 3s.

### CRT_talpa — Talpa Di Fero (2.3 studs)
**3D :** Taupe brune #6B4F35 trapue, casque de chantier jaune, lunettes de protection sur le front, pioche gris acier sur l'épaule.
**Idle :** gratte le sol du pied.
**Capacité PvP — "Tunnel Trap" (CONTRÔLE) :** s'enterre et ressort sous l'adversaire — étourdissement 2s.

## RARES

### CRT_trippi — Trippi Troppi (3 studs)
**3D :** Crevette-chat rose #FF9EBB au gros ventre, moustaches de crevette, chapeau melon violet, nageoires-bras.
**Idle :** claquement de queue rythmé.
**Capacité PvP — "Shrimp Punch" (BURST) :** coup de poing géant — dégâts ×3.

### CRT_tung_tung — Tung Tung Tung Sahur (3.2 studs)
**3D :** Bûche de bois marron #9C6644 avec visage inquiétant, grande batte de baseball noire à deux mains, silhouette penchée en avant.
**Idle :** tapote la batte au sol (3 coups — tung tung tung).
**Capacité PvP — "Bam Bam Bam" (BURST) :** triple frappe — dégâts ×3 + mini screen shake sur l'adversaire.

### CRT_boneca — Boneca Ambalabu (2.8 studs)
**3D :** Grenouille verte #6AB04C avec un pneu usé noir autour du ventre, yeux globuleux sur tiges, grande bouche souriante.
**Idle :** gonfle la gorge.
**Capacité PvP — "Tire Bounce" (BOUCLIER) :** se réfugie dans son pneu — absorbe 2 coups.

### CRT_footera — Gangster Footera (3.2 studs)
**3D :** Requin gris anthopomorphe en costume pinstripe gris-bleu, fedora noir, nageoires comme mains, cicatrice sur l'aileron.
**Idle :** ajuste son chapeau.
**Capacité PvP — "Drive-By" (BURST) :** rafale de coups de nageoires — dégâts ×3.

### CRT_chim_banana — Chimpanzini Bananini (3 studs)
**3D :** Banane jaune vif #FFE156 au visage de singe, pelure écartée en "jambes", bras longs de primate, excrétion de petites bananes (particules).
**Idle :** grimace joyeuse + balancement.
**Capacité PvP — "Banana Split" (SOIN) :** se coupe en deux et se régénère — +40% HP.

## ÉPIQUES

### CRT_cappuccino — Cappuccino Assassino (3 studs)
**3D :** Tasse de cappuccino blanc avec motif cœur caramel, mousse en couette, deux mini-fusils (boîtes noires), yeux déterminés, jambes rapides.
**Idle :** recharge ses armes.
**Capacité PvP — "Espresso Rush" (BURST) :** double rafale — dégâts ×3 ET vitesse d'attaque +30% pendant 5s.

### CRT_patapim — Brr Brr Patapim (3.5 studs)
**3D :** Créature forêt — corps-arbre brun avec feuilles #6BBF59 en coiffe, long nez turquoise, grands yeux doux, bras branchus.
**Idle :** les feuilles ondulent (tween rotation).
**Capacité PvP — "Brr Frost" (CONTRÔLE) :** souffle glacial — gèle l'adversaire 2s.

### CRT_blueberrini — Blueberrinni Octopusini (3.5 studs)
**3D :** Poulpe bleu profond #3A86FF avec baies bleues lumineuses sur chaque tentacule, grande tête ronde, yeux malicieux.
**Idle :** tentacules qui ondulent (tween sinusoïdal).
**Capacité PvP — "Ink Blast" (BURST) :** jet d'encre — dégâts ×3 ET précision adverse -15% (3s).

### CRT_strawberelli — Strawberelli Flamingelli (3.2 studs)
**3D :** Fraise rouge #E63946 au corps musclé, graines dorées, flamme orange sur la tête (particules), petites ailes de feu.
**Idle :** la flamme crépite.
**Capacité PvP — "Flambée" (BURST) :** explosion de jus enflammé — dégâts ×3.

## LÉGENDAIRES

### CRT_burbaloni — Burbaloni Loliloli (3.5 studs)
**3D :** Perroquet turquoise #40C9A2 à grande crête arc-en-ciel, ailes colorées, post fière sur un perchoir doré portable.
**Idle :** hoche la tête en rythme.
**Capacité PvP — "Loli Lasso" (CONTRÔLE) :** cri perçant hypnotique — étourdit 2s.

### CRT_bombombini — Bombombini Gusini (3.8 studs)
**3D :** Gorille gris anthracite en débardeur, deux bombes noires à mèche allumée dans les mains, mèche de dynamite dans la bouche.
**Idle :** jongle avec une bombe.
**Capacité PvP — "Bomb Barrage" (BURST+) :** déflagration — dégâts ×3.5, cooldown +2s.

### CRT_frigo_camelo — Frigo Camelo (4.5 studs)
**3D :** Chameau beige dont les bosses sont remplacées par un réfrigérateur blanc double porte (contenu lumineux multicolore), sourire satisfait.
**Idle :** la porte du frigo s'entrouvre (tween) avec lumière.
**Capacité PvP — "Frigorification" (CONTRÔLE+) :** vague de froid — gèle l'adversaire 2.5s.

### CRT_tukanno — Tukanno Bananno (3.5 studs)
**3D :** Toucan noir au bec géant jaune #FFD23F en forme de banane, ailes bleu nuit, petites baskets.
**Idle :** ouvre/ferme le bec.
**Capacité PvP — "Beak Barrage" (BURST) :** mitraille des mini-bananes du bec — dégâts ×3.

## MYTHIQUES

### CRT_bombardiro — Bombardiro Crocodilo (5 studs)
**3D :** Crocodile vert olive en avion — fuselage autour du corps, ailes militaires kaki, hélice arrière, casque de pilote et écharpe rouge.
**Idle :** hélice qui tourne + léger flottement.
**Capacité PvP — "Bombardement" (BURST+) :** vol en piqué — dégâts ×4, cooldown +2s.

### CRT_lirili — Lirili Larila (4.2 studs)
**3D :** Éléphant-cactus — corps cactus vert #6BBF59 à piquants, trompe cactus, oreilles de fleurs roses, démarche lourde.
**Idle :** les piquants brillent.
**Capacité PvP — "Cactus Spikes" (BOUCLIER) :** hérisse ses piquants — absorbe 2 coups ET renvoie 25% des dégâts pendant 5s.

### CRT_glorbo — Glorbo Fruttodrillo (4.5 studs)
**3D :** Crocodile-dragonfruit rose vif #FF5D8F à écailles, une moitié de fruit dragon sur le dos, queue épineuse.
**Idle :** claquement de mâchoires.
**Capacité PvP — "Juice Flood" (SOIN) :** onde de jus — +40% HP et purge les effets négatifs.

### CRT_gorillo — Gorillo Watermelondrillo (5 studs)
**3D :** Gorille massif rayé pastèque (vert #38B000 et rouge #E63946, facés noir), postures de bodybuilder, micro-pastèque en toque.
**Idle :** flexion de biceps lente.
**Capacité PvP — "Melon Slam" (BURST+) :** écrase une pastèque géante sur l'adversaire — dégâts ×3.5.

## BRAINROT GODS

### CRT_tralalero — Tralalero Tralala (5.5 studs)
**3D :** Le requin iconique — requin gris debout en baskets blanches à swoosh bleu, tenue de sport noire, sangle ventrale, sourire confiant.
**Idle :** dribble un ballon de basket invisible.
**Capacité PvP — "TRALALERO !" (BURST+) :** aileron suprême — dégâts ×4 ET accélère sa jauge de foule de 25%.

### CRT_vaca — La Vaca Saturno Saturnita (5 studs)
**3D :** Vache brune et blanche entourée d'anneaux de Saturne dorés (tore incliné, semi-émissif), tête fière, petites étoiles en particules.
**Idle :** les anneaux tournent lentement.
**Capacité PvP — "Saturn Rings" (BOUCLIER+) :** anneau protecteur — absorbe 3 coups.

### CRT_sammyni — Sammyni Spyderini (4.5 studs)
**3D :** Araignée noire élégante à 8 pattes fines, visage souriant avec moustache, petite canne, chapeau haut-de-forme.
**Idle :** tapote les pattes.
**Capacité PvP — "Spider Web" (CONTRÔLE+) :** toile collante — immobilise 2.5s.

### CRT_girafa — Girafa Celestre (6 studs)
**3D :** Girafe jaune pâle au corps constellé d'étoiles bleutées (points émissifs), longue tête sereine, aura de particules d'étoiles.
**Idle :** lévitation légère + constellation qui scintille.
**Capacité PvP — "Neck Whip" (BURST+) :** coup de cou galactique — dégâts ×3.5.

## SECRETS

### CRT_los_tralaleritos — Los Tralaleritos (5 studs)
**3D :** Troupe de 3 mini-requins choristes en costumes noirs, cravates rouges, partitions à la main, micros rétro.
**Idle :** chant synchronisé (rotation + particules de notes).
**Capacité PvP — "Chorus Attack" (BURST++) :** les 3 chantent en canon — dégâts ×4.5, cooldown +3s.

### CRT_chicleteira — Chicleteira Bicicleteira (4.5 studs)
**3D :** Bulle de chewing-gum rose géante sur un vélo rétro turquoise, personnage pédaillant à l'intérieur de la bulle (semi-transparente), confettis.
**Idle :** la bulle grossit/rétrécit.
**Capacité PvP — "Gum Trap" (CONTRÔLE+) :** bulle géante — colle l'adversaire 3s.

### CRT_la_grande — La Grande Combinazione (5.5 studs)
**3D :** Figure mafieuse en trench-coat gris anthracite, chapeau noir, valise marron, aura de fumée de cigarette (particules grises).
**Idle :** ouvre la valise — lumière dorée.
**Capacité PvP — "La Combinazione" (SOIN+) :** l'affaire du siècle — +50% HP ET +20% ATK pendant 5s.

### CRT_garama — Garama and Madundung (6.5 studs)
**3D :** Colosse violet-noir #3A0CA3 à 4 bras, visages multiples (2 têtes), chaînes brisées aux poignets, aura sombre, trail violet.
**Idle :** lévite + rotation lente, particules noires.
**Capacité PvP — "Madundung Quake" (BURST++) :** frappe le sol de ses 4 poings — dégâts ×5, cooldown +4s.

---
## B6. FICHES DE MODÉLISATION 3D + CAPACITÉS PvP — MONDES 2-4

Même template et mêmes conventions que B5 (collection `CRT_<id>`, bevel 0.05, yeux 20%, export FBX `D:/SABL_Assets/`).

## MONDE 2 — DESSERT KINGDOM

### CRT_biscottino — Biscottino Ballerino (2.8 studs)
**3D :** Biscuit doré #D4A373 allongé en tutu rose, chaussons de danse, bras gracieux, miettes en particules.
**Idle :** pirouette de ballet.
**Capacité PvP — "Grand Jeté" (BURST) :** coup de pied sauté — dégâts ×3.

### CRT_gelato_gangsterino — Gelato Gangsterino (3 studs)
**3D :** Cône de glace à 3 boules (pistache, vanille, fraise) avec fedora marron, dégoulinures colorées, mine menaçante.
**Idle :** les boules fondent légèrement (tween scale).
**Capacité PvP — "Cold Deal" (CONTRÔLE) :** poignée de main gelée — gèle 2s.

### CRT_tiramisu_tornado — Tiramisù Tornado (3.5 studs)
**3D :** Coupe de tiramisù en spirale tourbillonnante, cacao en tempête de particules, cuillère comme arme.
**Idle :** rotation permanente lente.
**Capacité PvP — "Tempête de Cacao" (BURST) :** tourbillon de cacao — dégâts ×3 ET aveugle (précision -15%, 3s).

### CRT_macaroni_mago — Macaroni Mago (3.2 studs)
**3D :** Macaron rose-lavande avec chapeau pointu de magicien étoilé, baguette sucre-glace, étoiles en particules.
**Idle :** fait léviter une mini-meringue.
**Capacité PvP — "Abracadolce" (CONTRÔLE) :** sortilège sucré — étourdit 2s.

### CRT_donut_drago — Donut Drago (4.5 studs)
**3D :** Donut rose géant #FF70A6 avec glaçage, pépites, cornes beige, ailes de sucre-candy semi-transparentes, queue-fourchette.
**Idle :** battement d'ailes + flottement.
**Capacité PvP — "Souffle Sucre" (BURST+) :** jet de glaçage brûlant — dégâts ×3.5.

### CRT_croissant_crusherino — Croissant Crusherino (4 studs)
**3D :** Croissant doré massif et musclé, bretelles de lutteur, ceinture de champion, miettes de farine en particules de puissance.
**Idle :** flexion des croûtes.
**Capacité PvP — "Croque Suprême" (BURST+) :** croquement dévastateur — dégâts ×3.5.

### CRT_gateau_guardiano — Gateau Guardiano (5 studs)
**3D :** Gâteau à 5 étages (dégradé pastèque/vanille/pistache) avec créneaux de glaçage, bougies-torches, petits yeux gardiens à chaque étage.
**Idle :** les flammes de bougies vacillent.
**Capacité PvP — "Mur de Crème" (BOUCLIER+) :** rempart de chantilly — absorbe 3 coups.

### CRT_millefeuille_celestre — Millefeuille Célestre (4.5 studs) — SECRET
**3D :** Millefeuille flottant à 12 feuilles d'or translucides, poussière d'étoiles entre les couches, lévite, aura blanche-dorée + trail.
**Idle :** les feuilles s'écartent et se referment (respiration).
**Capacité PvP — "Feuilleton Divin" (BURST++) :** pluie de 12 feuilles d'or — dégâts ×4.5, cooldown +3s.

## MONDE 3 — SUSHI ABYSS

### CRT_onigirino_orcano — Onigirino Orcano (3.5 studs)
**3D :** Onigiri blanc triangulaire avec bande d'algue noire, nageoire d'orque sur le dos, dents souriantes, queue.
**Idle :** nage sur place (mouvement sinusoïdal).
**Capacité PvP — "Orca Bite" (BURST) :** morsure d'épaulard — dégâts ×3.

### CRT_maki_rayona — Maki Rayona (3.5 studs)
**3D :** Rouleau de maki vu de face (riz blanc, cœur saumon, concombre) qui ondule comme une raie, nageoires latérales vertes.
**Idle :** ondulation plane.
**Capacité PvP — "Glide Sting" (BURST) :** piqué épineux — dégâts ×3 ET -10% ATK adverse (3s).

### CRT_nigiri_anguilla — Nigiri Anguilla (4.5 studs)
**3D :** Nigiri long et sinueux, bande d'anguille grillée brillante (nappage caramel), corps serpenté, yeux jaunes.
**Idle :** slalom en place.
**Capacité PvP — "Électro-Shock" (CONTRÔLE) :** décharge d'anguille — paralyse 2s.

### CRT_tempura_titano — Tempura Titano (4.5 studs)
**3D :** Crevette tempura XLL en armure de pâte dorée croustillante, queue massive, poings de pâte, éclats de friture en particules.
**Idle :** craque ses doigts de pâte.
**Capacité PvP — "Friture Impact" (BURST+) :** poing pané — dégâts ×3.5.

### CRT_ramen_krakeno — Ramen Krakeno (5.5 studs)
**3D :** Bol de ramen fumant avec 6 nouilles-tentacules sortant du bouillon, œuf mollet comme œil central, baguettes plantées comme cornes.
**Idle :** les nouilles ondulent, la vapeur fume (particules).
**Capacité PvP — "Sauce Piquante" (BURST+) :** jet de bouillon brûlant — dégâts ×3.5.

### CRT_unagi_imperatore — Unagi Imperatore (5 studs)
**3D :** Anguille empereur bleu-nuit avec couronne dorée de Japon, cape d'algue royale, moustache impériale (nori).
**Idle :** hoche la tête noblement.
**Capacité PvP — "Décret Impérial" (SOIN) :** décret de guérison — +40% HP et +15% vitesse d'attaque (4s).

### CRT_wasabi_wraitho — Wasabi Wraitho (4.5 studs) — MYTHIQUE
**3D :** Spectre vert translucide #00F5D4 en volute de wasabi, yeux flamboyants, traînée brûlante, bouche hurlante.
**Idle :** volute fantomatique (flottement).
**Capacité PvP — "Sinus Inferno" (CONTRÔLE+) :** vapeur de wasabi — brûlure ET immobilise 2.5s.

### CRT_sushi_shogun — Sushi Shogun Supremo (6 studs) — SECRET
**3D :** Guerrier samouraï dont l'armure est faite de sushis (épaulières onigiri, plastron maki, katana baguette), casque kabuto avec shachihoko crevette, aura bleu profond + trail.
**Idle :** dégaine lentement son katana-baguette (iai).
**Capacité PvP — "Iai Sushi" (BURST++) :** tranchage suprême — dégâts ×5, cooldown +4s.

## MONDE 4 — CANDY SPACE

### CRT_bonbonni_bourdonna — Bonbonni Bourdonna (3.5 studs)
**3D :** Bonbon lissé translucent rose avec ailes d'insecte irisées, antennes sucre, yeux à facettes ronds, butine des particules de poussière d'étoiles.
**Idle :** vol stationnaire bourdonnant.
**Capacité PvP — "Buzz Dash" (BURST) :** charge piquante — dégâts ×3.

### CRT_chamallow_astronauta — Chamallow Astronauta (4 studs)
**3D :** Chamallow blanc géant en combinaison spatiale blanche, casque bulle transparent, drapeau sucette planté sur le dos.
**Idle :** flottement lunaire (sauts lents).
**Capacité PvP — "Moon Bounce" (BOUCLIER) :** rebond anti-gravité — absorbe 2 coups.

### CRT_sucetta_satellita — Sucetta Satellita (5 studs)
**3D :** Sucette spirale multicolore avec panneaux solaires déployés de chaque côté, orbite de mini-bonbons, antenne parabolique.
**Idle :** les panneaux pivotent vers "la lumière".
**Capacité PvP — "Satellite Lock" (CONTRÔLE) :** rayon tracteur sucré — immobilise 2s.

### CRT_gommosa_galattica — Gommosa Galattica (4.5 studs)
**3D :** Gelée violette translucide avec galaxie spirale à l'intérieur (texture simple émissive), corps qui frémit, étoiles-incrustations.
**Idle :** frémissement gélatineux (scale sinusoïdal).
**Capacité PvP — "Wobble Quake" (BURST) :** onde sismique gélatineuse — dégâts ×3.

### CRT_cotone_cosmico — Cotone Cosmico (5.5 studs)
**3D :** Nuage-tapis de barbe à papa rose géant sur lequel reposent des mini-étoiles-bonbons, volutes douces, traînée sucrée.
**Idle :** ondulation de nuage.
**Capacité PvP — "Douce Nuée" (SOIN+) :** pluie sucrée régénérante — +50% HP.

### CRT_caramel_cometa — Caramel Cometa (4.5 studs)
**3D :** Comète-caramel ambre avec queue de caramel fondu étincelante, noyau dur et brillant, trajectoire inclinée figée.
**Idle :** la queue scintille.
**Capacité PvP — "Comet Crash" (BURST+) :** impact cométaire — dégâts ×3.5.

### CRT_gravita_grandosa — Gravita Grandosa (6 studs) — MYTHIQUE
**3D :** Colosse de bonbon-diamant violet aux facettes géantes, cœur lumineux au centre, aura de distorsion (particules orbitales).
**Idle :** les facettes réfléchissent (flash léger).
**Capacité PvP — "Puits de Gravité" (CONTRÔLE+) :** attire et écrase l'adversaire — dégâts + immobilisation 2.5s.

### CRT_ourson_galattico — Ourson Galattico (6.5 studs) — SECRET
**3D :** Ourson gummy géant semi-translucide (rouge/framboise) avec galaxie spirale dans le ventre, oreilles étoilées, aura arc-en-ciel + trail cosmique, lévite.
**Idle :** les étoiles internes orbitent.
**Capacité PvP — "Calin Cosmique" (BURST++) :** étreinte écrasante d'amour — dégâts ×5, cooldown +4s.

---
# PARTIE C — ÉCONOMIE, PROGRESSION & MONÉTISATION

## C1. Parcours cible d'un nouveau joueur

| Temps de jeu | État attendu |
|---|---|
| 0-5 min | Clics (5 💰/clic), 1er œuf Snack, 2 communs placés |
| 5-15 min | ~2K/s de revenu, 1er rare, 4e slot |
| 15-45 min | ~15K/s, 1er épique, bouclier acheté, **découverte du Colisée (spectateur)** |
| 45-90 min | ~100K/s, 1er vol réussi, 8 slots, **1er match d'arène (vs bot facile)** |
| 2-4 h | 1M/s, 1er REBIRTH 🎉 |
| Semaine 1 | Rebirth 2-3, **Bronze II en arène**, monde 2 débloqué |
| Mois 1 | Rebirth 5-8, monde 3, **Or+ en arène**, clan actif, 2-3 guerres jouées |

## C2. Multiplicateurs de revenu (tous cumulables)

- Rebirths : ×2 par rebirth
- Tiers de fusion : ×3 / ×10 / ×40 / ×150
- Générateur de base : jusqu'à +50%
- VIP : +50% | Décos : +24% max | Pluie de confettis : ×2 (événement)
- Perks de clan : jusqu'à +15% (voir PARTIE F)

## C3. Rebirth & déblocage des mondes

| Rebirth | Coût | Récompense |
|---|---|---|
| 1 | 1M | ×2 revenus permanent, +10% chance |
| 2 | 50M | ×2 supplémentaire, 500 tokens arène |
| 3 | 2.5B | **MONDE 2 : Dessert Kingdom** 🍰 + ×2 |
| 4 | 100B | ×2, 2 000 tokens arène |
| 5 | 500B | **MONDE 3 : Sushi Abyss** 🌊 + ×2 |
| 6-9 | ×20 à chaque palier | ×2 + tokens arène croissants |
| 10 | 100T | **MONDE 4 : Candy Space** 🍬🚀 + ×2 + aura dorée sur le perso |
| 15+ | ×50 à chaque palier | ×2 + titre cosmétique (Légende, Mythe…) |

Chaque monde : nouvelles familles de brainrots (PARTIE B), nouvelle map (PARTIE D), nouveaux œufs. La base du joueur est réinitialisée à chaque rebirth SAUF : brainrots des mondes précédents placés en "Réserve d'or" (conservés mais non productifs) — ils restent utilisables en PvP.

## C4. Événements

| Événement | Fréquence | Durée | Effet |
|---|---|---|---|
| 🌙 Frénésie Minuit | toutes les 3h | 15 min | Chance ×10 sur tous les œufs + ciel étoilé |
| 👹 Boss du Serveur | toutes les 2h | 5 min | Méga-boss au hub, dégâts = clics, top 1 → œuf Mythique garanti |
| 🎊 Pluie de Confettis | aléatoire | 10 min | Revenus ×2 serveur |
| ⚔️ **Double Colisée** | samedi-dimanche | 48h | Tokens arène ×2 + matchmaking prioritaire |
| 📅 Week-end Chance | sam-dim | 48h | Chance ×2 globale |
| 🏆 **Tournoi du Samedi** | samedi 18h | ~45 min | Bracket 8/16 joueurs, récompenses PARTIE E |
| 🛡️ **Guerre de Clans** | dimanche→jeudi | 4 jours | Voir PARTIE F |

## C5. Quêtes quotidiennes (3/jour, reset 00h00 UTC)

| Quête | Récompense |
|---|---|
| Cliquer 200× | 2 500 💰 |
| Ouvrir 5 œufs | 10 000 💰 |
| Fusionner 3× | 25 000 💰 |
| Voler 1 brainrot | 50 000 💰 |
| Défendre ta base 2× | 30 000 💰 |
| Gagner 1 match d'arène (nouveau) | 40 💰 tokens arène |
| Utiliser 5 capacités PvP (nouveau) | 25 💰 tokens arène |
| Passe 20 min en jeu | 100 000 💰 |

Streak quotidien 7 jours : J1-3 argent croissant • J4-5 egg_street • J6 épique garanti • J7 rare garanti + 1 spin roulette. Un jour manqué = reset (FOMO sain).

## C6. Monétisation (gamepasses & produits)

| Produit | Prix | Contenu |
|---|---|---|
| ⭐ VIP | 199 R$ | +50% revenus permanent, tag doré, zone VIP |
| 🍀 ×2 Chance | 149 R$ | Permanent |
| 👟 ×2 Vitesse | 99 R$ | Course + poursuites |
| 🤖 Auto-collect | 249 R$ | Collecte automatique |
| 📦 +5 Slots | 199 R$ | Au-delà du max normal |
| 🛡️ Bouclier d'urgence | 49 R$ | Consommable, +3 min (jamais permanent) |
| 🎖️ Passe Gladiateur (nouveau) | 179 R$ | +25% tokens arène gagnés, emote de victoire exclusive, n'est JAMAIS un avantage de stats |
| 🎁 Starter Pack | 99 R$ | 10K + rare garanti + bouclier (unique) |
| 🎡 Spins roulette | 25-499 R$ | Cosmétiques/boosts, JAMAIS de Secrets directs |

**Règles d'or :** on vend de la CHANCE et du CONFORT, jamais la victoire. Aucun gamepass n'augmente ATK/HP en arène classée. Probabilités affichées (obligation Roblox).

## C7. Tokens arène — la 2e monnaie (détail en PARTIE E)

Gagnés uniquement en jouant : victoire 25 / défaite 8 / +2 par minute jouée / quêtes PvP / tournoi / guerre de clans. Dépensés dans la boutique du Colisée : œufs exclusifs, cosmétiques PvP (trails d'attaque, poses de victoire), boosts, slots d'équipes PvP supplémentaires (loadouts A/B/C).

---
# PARTIE D — LES MAPS (5 MONDES DÉTAILLÉS)

> **Convention générale de construction :** chaque monde reprend la même structure "hub central + 12 plots en anneau + ruelles" (cohérence de code et de repères joueurs), MAIS le thème, les couleurs, les props et 3 zones uniques par monde changent tout. Une map = un dossier dans `Workspace/Map_Monde<N>`. Tout est Anchor. StreamingEnabled ON.

---

## D1. MONDE 1 — BRAINROT STREET 🍟 (map de départ)

### D1.1 Concept & ambiance
Une rue italienne cartoon, dansante et saturée de néons — le "brainrot district". Asphalte chaud, marquages jaunes, immeubles pastel en fond, graffitis brainrot, lampadaires rigolos. Le jour-nuit cosmétique tourne en 20 min (à la tombée de la nuit : néons +50% intensité).

### D1.2 Plan ASCII global

```text
                         N
        [P4]───────────[P5]
       /                  \
   [P3]                    [P6]
    │                        │
   [P2]      HUB CENTRAL     [P7]        ← plots en anneau r=130
    │      (plateau r=60)    │              chaque plot : 80×80
   [P1]                    [P8]
       \                  /
        [P12]──────────[P9]
             [P11] [P10]
              S      ·
        
  DÉTAIL DU HUB (vue zoom) :

                    [PORTAILS M2/M3/M4]
                            │
        [BOSS ARENA] ─── [ENTRÉE COLISÉE] ─── [BOUTIQUE ŒUFS]
        (ouest, r=25)      │  (nord, arche     (est, 30×20)
                            │   dorée, lvl 5+)
                    [PLACE CENTRALE]
                  (r=60, spawn S au sud,
                   leaderboard ×2, NPC guide)
                            │
                    [MUSÉE DES SECRETS]
                     (sud, vitrines)
```

### D1.3 Fiches par zone

| Zone | Dimensions | Couleurs | Contenu & gameplay |
|---|---|---|---|
| **Z1 — Place centrale (Hub)** | plateau cylindre r=60, h=2 | asphalte #8A8580, disque central jaune #FFD23F r=8 (logo brainrot peint) | Spawn (S), NPC guide tuto, 2 leaderboards (revenus, vols), 6 lampadaires, marquages piétons |
| **Z2 — Boutique d'œufs (est)** | bâtiment 30×20×12 ouvert sur la place | façade #F4D58D, néon "EGG SHOP" #FFB703 | 5 socles d'œufs M1 (egg_basic→secret) avec prix au-dessus, PNJ caisse |
| **Z3 — Boss Arena (ouest)** | plateforme octogonale r=25, surélevée 4 studs, 2 marches | gris #6C757D, liseré rouge #E63946 | PROP_boss_totem au centre, 8 places de spectateurs délimitées |
| **Z4 — Entrée Colisée (nord)** | arche dorée 16 de large × 12 haut + escalier 8 marches | or #FFD23F, marbre #E9ECEF | Portail de téléportation vers le Colisée (PARTIE D5), condition : niveau 5+ |
| **Z5 — Musée des Secrets (sud)** | vitrine 20×8, 6 socles en verre | verre semi-transparent, socles noirs | Affiche les Secrets obtenus par le serveur (flex social, FOMO) |
| **Z6 — Les 12 plots** | anneau r=130, plots 80×80, tous les 30° | plot #9B9484, bordure jaune | Attribut `Owner=""`, arche d'entrée orientée vers le hub, 1 plot = 1 base joueur |
| **Z7 — Ruelles** | 20 de large entre les plots | asphalte, graffitis multicolores | 2 rampes + 2 trampolines + 3 lampadaires + 1 banc par ruelle — le terrain de chases |
| **Z8 — Portails des mondes** | 3 arches 12 de haut alignées au nord (derrière le Colisée) | M2 rose #FFD6E8 / M3 bleu #00B4D8 / M4 violet #3A0CA3 | Vortex à particules, panneaux "Rebirth 3 / 5 / 10 requis" |

### D1.4 Props spécifiques (kit Blender)

`PROP_lampadaire` (poteau 8 studs + globe néon multicolore) • `PROP_ramp` (plan incliné 30°, 12×2×6, marquage jaune) • `PROP_trampoline` (cylindre r=4 h=0.5 rouge #E63946 sur 4 pieds, surface émissive) • `PROP_graffiti` (plane 6×3, textures brainrot) • `PROP_banc` (banc burger) • `PROP_boss_totem` • `PROP_arche_colisee` • `PROP_portail_monde` • `PROP_batiment1..6` (façades décoratives 20×30, pastel, pour la skyline)

### D1.5 Palette récapitulative

Asphalte **#8A8580** • Plots **#9B9484** • Marquages **#FFD23F** • Néons ketchup **#E63946** / moutarde **#FFB703** / salade **#8AC926** • Façades pastel **#F4D58D, #CDB4DB, #A8DADC**

### D1.6 Prompt MCP Roblox (Étape 1 — map blanche)

```text
Dans Workspace, crée un Model "Map_Monde1" contenant :
(1) "Hub" : cylindre r=60 h=2 à (0,1,0), couleur #8A8580, + disque jaune #FFD23F r=8 h=0.2
    à (0,2.1,0), + 12 lampadaires placeholder (cylindres gris h=8) en cercle r=50.
(2) "Plots" : 12 Parts 80×1×80 nommées Plot1..Plot12 en anneau r=130 (un tous les 30°),
    couleur #9B9484, chacune avec attribut string "Owner"="" et 2 piliers (2×8×2) + linteau
    (10×2×2) formant arche côté hub.
(3) "Ruelles" : entre chaque plot, 2 rampes (boîtes inclinées 30°) et 2 plateformes
    trampoline placeholder (cylindres r=4 h=0.5 rouges).
(4) "EggShop" : dalle 30×1×20 à (60,1,0) + 5 socles (cylindres r=2 h=1) en ligne.
(5) "BossArena" : octogone r=25 h=4 à (-60,2,0) avec 2 marches d'accès.
(6) "ColiseeGate" : arche dorée (2 piliers 4×12×4 + linteau 16×2×4) à (0,1,-55) face au sud.
(7) "Musee" : boîte vitrine 20×6×8 semi-transparente à (0,1,50).
Anchor sur toutes les Parts. Ajoute SpawnLocation à (0,3,20).
```

---
## D2. MONDE 2 — DESSERT KINGDOM 🍰 (rebirth 3)

### D2.1 Concept & ambiance
Un royaume de pâtisserie géant au coucher de soleil rose. Sol en biscuit, collines de chantilly rebondissantes, rivières de chocolat tiède (qui RALENTISSENT les voleurs de 30% — avantage défensif des bases riveraines), cannes-candy en colonnes, pluie de pépites permanente (particules). La nuit, les bougies du château s'allument.

### D2.2 Plan ASCII global

```text
                         N
        [P4]───────────[P5]
       /   ~ CHOCOLAT ~   \
   [P3]     RIVIÈRE         [P6]     ← plots r=130 sur rives
    │                        │           en "couronne brisée"
   [P2]    [CHÂTEAU-CENTRAL] [P7]       par la rivière Ouest
    │      (hub r=60)        │
   [P1]                        [P8]
       \                  /
        [P12]──────────[P9]
             [P11] [P10]
              S      ·
        
  ZONES UNIQUES (hors anneau standard) :
  • CASCADE CARAMEL (nord-est) : cascade #C68B4E r=15 — zone bonus revenus +10%
    tant qu'on y reste (max 2 min, cooldown 10 min)
  • FORÊT SUCRÉE (sud-ouest) : 12 arbres-guimauve ; 1 bonheur caché par heure
    contient un œuf egg_dessert gratuit (premier trouvé)
  • DOUCHE DE PÉPITES (centre du hub) : 1×/h, 30s de pluie dorée = clics ×5
```

### D2.3 Fiches par zone

| Zone | Dimensions | Couleurs | Contenu & gameplay |
|---|---|---|---|
| **Château-central (Hub)** | cylindre r=60 + château décoratif 30×30×25 au centre | gâteau à étages rose #FFD6E8 / crème #FFF8F0 / cerise rouge #E63946 | Spawn, boutique egg_dessert, leaderboard, 2 bougies géantes lumineuses la nuit |
| **Rivière de chocolat** | anneau partiel ouest, largeur 25, profondeur 2 | chocolat #7B4B2A semi-brillant, reflets caramel | Traverser = -30% vitesse pendant 3s (poursuites tendues) ; ponts biscuits ×3 |
| **Collines de chantilly** | 8 dômes r=10-15 dans les ruelles | crème #FFF8F0, arêtes dorées | Sauts boostés (+30% hauteur) — raccourcis spectaculaires |
| **Cascade Caramel** | nord-est, r=15 | caramel #C68B4E, particules de gouttes | Zone bonus revenus (voir plan) |
| **Forêt Sucrée** | sud-ouest 60×60 | arbres guimauve blancs tiges brun | Chasse à l'œuf caché horaire |
| **12 plots** | anneau r=130 comme M1 | plots biscuit #D4A373, bordure glaçage rose | Identique techniquement à M1 (même scripts) |
| **Ruelles** | 20 de large | sol biscuit | Canne-candy en colonnes lumineuses, guimauves-bancs |

### D2.4 Props spécifiques (kit Blender)

`PROP_canne_candy` (colonne 6 studs rayée blanc-rouge, émissive) • `PROP_colline_chantilly` (dôme crème r=10) • `PROP_pont_biscuit` (arc 20×4) • `PROP_arbre_guimauve` (tronc brun + houppier blanc r=3) • `PROP_cascade_caramel` (plan incliné + particules) • `PROP_cerise_geante` (r=2, émissive) • `PROP_gateau_chateau` (le hub-château)

### D2.5 Palette récapitulative

Sol biscuit **#D4A373** • Crème **#FFF8F0** • Rose pâtisserie **#FFD6E8** • Chocolat **#7B4B2A** • Caramel **#C68B4E** • Cerise **#E63946** • Glaçage néon **#FF70A6**

### D2.6 Prompt MCP Roblox (résumé — Étape 16)

```text
Duplique Map_Monde1 en Map_Monde2 puis rethème : sols biscuit #D4A373, plots #D4A373 bordure
#FF70A6, hub = château gâteau (5 cylindres empilés r=30..8, rose #FFD6E8, cerise #E63946),
rivière = anneau partiel ouest largeur 25 couleur #7B4B2A avec 3 ponts, 8 dômes chantilly
#FFF8F0 dans les ruelles, 12 cannes-candy lumineuses. Portail retour M1 au nord.
```

---

## D3. MONDE 3 — SUSHI ABYSS 🌊 (rebirth 5)

### D3.1 Concept & ambiance
Les profondeurs abyssales : lumière ambiante cyan, bulles qui montent partout, méduses-lampadaires, plateformes de riz/sushi flottantes reliées par des ponts d'algues. Un COURANT MARIN traverse la map d'est en ouest (pousse les joueurs : défense facile, vol plus risqué). Les secrets de ce monde brillent dans le noir.

### D3.2 Plan ASCII global

```text
                         N
        [P4]───────────[P5]
       ║ COURANT MARIN ║          ← flèche est→ouest, couloir central
   [P3]    (zone bleue)   [P6]
    │                      │
   [P2]   [RÉCIF-CENTRAL]  [P7]    ← hub = récif de corail lumineux
    │      (r=60)          │
   [P1]                    [P8]
       \                  /
        [P12]──────────[P9]
             [P11] [P10]
              S      ·

  ZONES UNIQUES :
  • COLONNES DE BULLES (×4) : ascenseurs verticaux — montée 20 studs/s
  • GROTTE DU POISSON-LANTERNE : mini-donjon 30×30, 10 mini-brainrots corrompus
    à vaincre à la capacité PvP → récompense 1 egg_abyss (cooldown 1h)
  • FAILLE DES ANGUILLES : courant ×2 (seuls les courageux traversent pour
    un plot à revenus +5% — les "plots premium" M3)
```

### D3.3 Fiches par zone

| Zone | Dimensions | Couleurs | Contenu & gameplay |
|---|---|---|---|
| **Récif-central (Hub)** | cylindre r=60, corail lumineux | sable #FAF0D7, corail #FF6B6B, cyan #00B4D8 | Spawn, boutique egg_abyss, leaderboard coquillages, 8 méduses-lampadaires |
| **Courant marin** | couloir central est→ouest, largeur 30 | bleu translucide #48CAE4, flèches particules | Pousse +12 studs/s dans le sens du courant (les voleurs fuyant vers l'est rament) |
| **Colonnes de bulles** | 4 colonnes r=3, hauteur 40 | bulles semi-transparentes | Ascenseurs verticaux 20 studs/s |
| **Grotte du poisson-lanterne** | 30×30×12, entrée voûtée | noir #03045E, lanternes #FFD23F | Mini-donjon instance 1 joueur, 10 vagues corrompues |
| **Fosse des anguilles** | anneau sud profond | bleu nuit #023E8A | Courant ×2, 2 plots premium +5% revenus |
| **12 plots** | anneau r=130 | plateformes sushi (riz #FFF8F0, algue #2A9D8F) | Identique techniquement à M1 |
| **Ruelles** | 20 de large | ponts d'algues souples (légère déformation) | Algues-cordes, poulpes-fontaines |

### D3.4 Props spécifiques (kit Blender)

`PROP_meduse_lampadaire` (méduse cyan émissive sur tige) • `PROP_plateforme_sushi` (disque riz + algue + garniture) • `PROP_pont_algue` (pont souple 20×3) • `PROP_colonne_bulle` (cylindre translucide + particules) • `PROP_lanterne_poisson` • `PROP_corail` (5 variantes lumineuses) • `PROP_coffre_grotte`

### D3.5 Palette récapitulative

Eau profonde **#03045E** • Cyan **#00B4D8** • Translucide **#48CAE4** • Corail **#FF6B6B** • Sable **#FAF0D7** • Algue **#2A9D8F** • Bleu nuit **#023E8A**

### D3.6 Prompt MCP Roblox (résumé — Étape 16)

```text
Duplique Map_Monde1 en Map_Monde3 puis rethème : ambiance abyssale (Lighting bleu #03045E,
fog), hub = récif corail lumineux, plots = plateformes sushi #FFF8F0, couloir courant marin
est→ouest largeur 30 (particules #48CAE4, script poussée +12 studs/s), 4 colonnes de bulles
ascenseurs, grotte instance 30×30 au nord-ouest. Portail retour M1 au nord.
```

---
## D4. MONDE 4 — CANDY SPACE 🍬🚀 (rebirth 10)

### D4.1 Concept & ambiance
Une station orbitale sucrée au milieu d'un champ d'astéroïdes-bonbons. Ciel = nébuleuse violette. Certaines zones sont en **GRAVITÉ FAIBLE** (sauts ×2 en hauteur, chute lente — les chases deviennent des ballets spatiaux). Des tapis roulants de caramel relient les plots. Une navette fait le tour de la map toutes les 5 min (ride cosmétique + vue sur les Secrets du joueur en hologramme).

### D4.2 Plan ASCII global

```text
                         N
        [P4]───────────[P5]
       /                  \
   [P3]     [STATION]      [P6]     ← hub = station orbitale
    │      (r=60, anneau)   │           + navette orbitale
   [P2]                      [P7]
    │                        │
   [P1]                      [P8]
       \                  /
        [P12]──────────[P9]
             [P11] [P10]
              S      ·

  ZONES UNIQUES :
  • ZONES GRAVITÉ FAIBLE (×6) : bulles violetes translucides r=15 — saut ×2
  • TAPIS DE CARAMEL : boucles de convoyeurs entre plots (vitesse +8 studs/s)
  • CHAMP D'ASTÉROÏDES (pourtour extérieur r=200) : 20 astéroïdes-bonbons
    flottants ; 3 d'entre eux (aléatoire/heure) cachent un mini-portail
    vers un défi "Réflexes" (obby 60s) → 1 token arène ×20
```

### D4.3 Fiches par zone

| Zone | Dimensions | Couleurs | Contenu & gameplay |
|---|---|---|---|
| **Station orbitale (Hub)** | cylindre r=60 + anneau décoratif r=70 | blanc glace, fenêtres cyan, néons #F72585 | Spawn, boutique egg_cosmic, leaderboard holographiques, dôme d'observation |
| **Zones gravité faible** | 6 bulles r=15 réparties dans les ruelles | violet translucide #7209B7 | Sauts ×2 hauteur, chute lente (JumpPower + Gravity locaux) |
| **Tapis de caramel** | 4 boucles 20 de large | caramel #C68B4E émissif | Convoyeur +8 studs/s (sens indiqué par flèches particules) |
| **Champ d'astéroïdes** | anneau r=200, 20 astéroïdes r=5-12 | bonbons multicolores translucides | 3 caches horaires avec mini-obby (60s) → 20 tokens arène |
| **12 plots** | anneau r=130 | plateformes sucette (disque multicolore + tige) | Identique techniquement à M1 |
| **Ruelles** | 20 de large | sol métallique rose | Tapis roulants, étoiles scintillantes |

### D4.4 Props spécifiques (kit Blender)

`PROP_station_anneau` (anneau torique blanc autour du hub) • `PROP_navette` (capsule 8×3×3, hublots cyan) • `PROP_asteroide_bonbon` (rocher translucide, 6 variantes de couleur) • `PROP_bulle_zero_g` (sphère violette translucide r=15) • `PROP_tapis_caramel` (segment convoyeur 10×4, émissif) • `PROP_holo_leaderboard`

### D4.5 Palette récapitulative

Nébuleuse/noir spatial **#1A1A2E** • Violet **#3A0CA3** • Bulles **#7209B7** • Rose néon **#F72585** • Or **#FFD23F** • Cyan hublot **#4CC9F0**

### D4.6 Prompt MCP Roblox (résumé — Étape 16)

```text
Duplique Map_Monde1 en Map_Monde4 puis rethème : ambiance spatiale (Lighting #1A1A2E,
Skybox nébuleuse violette), hub = station orbitale avec anneau blanc, plots = plateformes
sucette multicolores, 6 sphères gravité faible #7209B7 (script JumpPower×2 + Gravity 100),
4 boucles de tapis roulants caramel, 20 astéroïdes-bonbons à r=200. Portail retour M1.
```

---

## D5. LE COLISÉE BRAINROT ⚔️ (map PvP dédiée — PARTIE E)

### D5.1 Concept & ambiance
Un colisée doré futuriste flottant, accessible depuis l'arche du hub de chaque monde. À l'intérieur : une fosse de combat circulaire éclairée de projecteurs, des gradins remplis d'un public de brainrots (particules + NPC low-poly), un écran géant qui diffuse le match en cours (score, HP, Elo) et uneenergie de stade de foot le soir de finale. C'est LE lieu de rendez-vous du serveur.

### D5.2 Plan ASCII

```text
              VUE DE DESSUS (Colisée r=90)

        ╔════════════════════════════════════╗
        ║   GRADINS N3 (r=75-90 · loges VIP)  ║
        ║  ┌──────────────────────────────┐  ║
        ║  │ GRADINS N2 (r=60-75 · public)│  ║
        ║  │  ┌────────────────────────┐  │  ║
        ║  │  │ GRADINS N1 (r=45-60)    │  │  ║
        ║  │  │   ┌──────────────┐      │  │  ║
        ║  │  │   │  ARÈNE (r=30)│      │  │  ║
        ║  │  │   │  2 cercles   │      │  │  ║
        ║  │  │   │  d'apparition│      │  │  ║
        ║  │  │   └──────────────┘      │  │  ║
        ║  │  │  E = écran géant (sud)  │  │  ║
        ║  │  └────────────────────────┘  │  ║
        ║  │ H = hall (entrée sud, r=45) │  ║
        ║  └──────────────────────────────┘  ║
        ╚════════════════════════════════════╝

  HALL (coupe) :
  [PORTE D'ENTRÉE] → [CLASSEMENTS ELO] → [BOUTIQUE TOKENS] → [NPC FILE 1v1]
                                        → [NPC FILE 2v2]     → [LOGES PRÉPARATION ×4]
                                        → [PORTE SPECTATEUR]
```

### D5.3 Fiches par zone

| Zone | Dimensions | Couleurs | Contenu & gameplay |
|---|---|---|---|
| **Hall d'entrée** | demi-cercle r=45 au sud | marbre #E9ECEF, or #FFD23F | 3 panneaux de classement Elo (global/serveur/saison), boutique tokens, 2 NPC de file (1v1/2v2), 4 loges de préparation (changement de l'équipe PvP) |
| **Fosse d'arène** | disque r=30, murs de 6 de haut | sol sablé #B8A88A avec cercles d'apparition bleu/rouge r=4, liserés néon | LE terrain de combat. Deux cercles d'apparition à ±10 studs du centre. Sol remplace en surface "plate" pour le combat |
| **Gradins N1** | anneau r=45-60 | pierre #B8A88A | Places spectateurs assises (sièges cliquables), vue plongée |
| **Gradins N2** | anneau r=60-75 | pierre + banderole publicitaires brainrot rigolotes ("TRALALERO COLA") | Public automatique : 60 NPC brainrots low-poly qui s'agitent (billboard tween) |
| **Gradins N3 / Loges VIP** | anneau r=75-90 | or #FFD23F, vitres | Réservé VIP + top 10 Elo : banquettes, écran privé, emote flex |
| **Écran géant** | panneau 40×20 suspendu au sud | émissif | Affiche le match : HP des combattants, noms, Elo, jauge de foule. Double comme écran de replay de l'ULTIME |
| **Loges de préparation** | 4 pièces 10×10 | néons équipes bleu/rouge | Sélection des 3 brainrots, écran stats, prêt → téléport fosse |
| **Tunnels d'entrée** | 2 tunnels 6 de large | bleu (joueur A) / rouge (joueur B) | Entrée cinématique : le brainrot actif avance vers le centre + smoke |

### D5.4 Props spécifiques (kit Blender)

`PROP_colisee_exterieur` (coque dorée à 3 niveaux d'arcades) • `PROP_fosse` (disque + murets + 2 cercles néon) • `PROP_gradin_segment` (segment 15°, répétable ×24) • `PROP_ecran_geant` • `PROP_npc_spectateur` (10 variantes brainrots assis, low-poly 300 triangles) • `PROP_torche_colisee` (brasero or) • `PROP_banniere_pub` (plane 8×3)

### D5.5 Palette récapitulative

Or **#FFD23F** • Rouge arene **#E63946** • Pierre **#B8A88A** • Marbre **#E9ECEF** • Bleu équipe A **#4CC9F0** • Rouge équipe B **#E63946** • Néon nuit **#F72585**

### D5.6 Prompt MCP Roblox (Étape 13)

```text
Crée Workspace/Map_Colisee (position Y=1000 pour isolation) : coque colisée r=90 or #FFD23F
(3 anneaux d'arcades), fosse circulaire r=30 sol #B8A88A avec 2 cercles d'apparition néon
(r=4, bleu #4CC9F0 à (-10,1,0), rouge #E63946 à (10,1,0)), murets h=6, gradins = 24 segments
pierre #B8A88A (r=45-90), écran géant 40×20 émissif au sud (SurfaceGui), hall demi-cercle
r=45 avec 3 panneaux leaderboard et 4 loges 10×10, 60 NPC spectateurs low-poly dans les
gradins, 4 braseros or. SpawnLocation dans le hall. Anchor tout.
```

---
# PARTIE E — SYSTÈME PVP : LE COLISÉE BRAINROT ⚔️

## E1. Vue d'ensemble

| Élément | Valeur |
|---|---|
| **Accès** | Arche dorée du hub (chaque monde) → téléport Colisée. Niveau 5 requis. |
| **Match** | Instance isolée (position Y=2000) : 2 joueurs, 3 brainrots chacun, 60-90s |
| **Philosophie** | Auto-battle spectaculaire + décisions tactiques (capacités, switch, timing d'ultime). Aucun reflex FPS : lisible sur mobile, équitable PC/mobile. |
| **Anti-frustration** | Les brainrots engagés sont invulnérables au vol pendant le match. Déconnexion = défaite mais AUCUNE perte de brainrot (jamais). |
| **Bots** | File d'attente < 30s → un bot équivalent Elo est proposé (refusable). Les 3 premiers matchs d'un joueur = bots faciles (tutoriel déguisé). |

## E2. Formats de jeu

| Format | File | Durée | Récompenses |
|---|---|---|---|
| **1v1 Rapide (classé)** | NPC bleu du hall | 60-90s | Elo, 25 tokens (V) / 8 (D) |
| **2v2 Duo (classé)** | NPC rouge (co-équipier = ami OU tirage) | 90-120s | Elo, 35/12 tokens |
| **Arène Libre** | panneau latéral | illimité | Stats brutes (tiers ×3/×10/…), pas d'Elo, 5 tokens max/15 min |
| **Tournoi du Samedi** | inscription samedi 17h30 | bracket 17h45-18h30 | voir E9 |

## E3. Le combat hybride — déroulé d'un match

```text
PRÉ-MATCH (30s) : les 2 joueurs sont en loges → valident leur équipe de 3
                  (dans l'ordre voulu : brainrot actif + 2 remplaçants)
                  → tunnels d'entrée (3s) → cinématique face-à-face (2s)

MATCH : boucle serveur à 10 Hz
  • AUTO-ATTAQUE : le brainrot actif A attaque le brainrot actif B toutes les 1.5s
    dégâts = ATK × modificateur de type (±20%) × variance ±10% (seed partagé)
  • JAUGE DE CAPACITÉ : se remplit en 8s → le joueur peut l'ACTIVER (bouton/E)
    → effet selon la capacité signature (BURST/SOIN/BOUCLIER/CONTRÔLE, PARTIE B)
    → la jauge se vide et se recharge
  • SWITCH : remplacer le brainrot actif par un remplaçant (cooldown 5s,
    soin passif +2%/s sur le banc)
  • JAUGE DE FOULE : monte de +4% par coup porté, +2% par coup encaissé
    → à 100% : bouton ULTIME actif

MOR T D'UN BRAINROT : animation ragdoll comique 1.5s → remplaçant suivant
  entre automatiquement (0.5s d'invulnérabilité)

FIN DE MATCH : équipe adverse à 0 OU timeout 90s (le plus haut % HP total gagne)
  → ralenti 2s → hymne de victoire + pose de victoire + pluie de confettis
  → écran de résultat (HP restants, dégâts infligés, capacité réussies,
    Elo avant/après, tokens gagnés) → téléport retour hall
```

## E4. Les 4 actions du joueur (toutes mobile-first)

| Action | Contrôle PC | Contrôle mobile | Validation serveur |
|---|---|---|---|
| ACTIVER CAPACITÉ | touche E (ou clic bouton) | gros bouton rond central (≥44px) | jauge pleine côté serveur, sinon ignoré |
| SWITCH | touches 1/2/3 | 2 petits boutons à droite | cooldown 5s respecté |
| ULTIME | touche F (bouton doré) | bouton doré (≥56px) | jauge de foule = 100% |
| EMOTE (cosmétique) | G | bouton drôle | aucune (client only) |

## E5. L'ULTIME — "HYPER BRAINROT MODE"

Quand la jauge de foule est pleine, le joueur déclenche l'ultime de son brainrot actif : **3s de cinématique** (zoom caméra, aura, screen shake, la foule rugit) puis :
- Dégâts = 3× l'ATK actuelle du brainrot, AVANT application des types
- + Effet bonus selon le type du brainrot : SALÉ = -25% ATK adverse 5s | SUCRÉ = soin 30% de l'équipe | FRUITÉ = étourdit 2.5s
- L'ultime vide la jauge de foule (retour à 0)

> Design : la jauge de foule récompense l'ENGAGEMENT (prendre et donner des coups), pas le camping. Le timing de l'ultime (avant un switch adverse ? pendant le bouclier ennemi ?) est LE moment skill du jeu.

## E6. Matchmaking & Elo

- Elo de départ : 1000. K = 32. Victoire/Défaite standard ELO FIDE.
- Matchmaking : adversaire à ±150 Elo (élargi +50 toutes les 20s d'attente, max ±400 puis bot).
- File séparée par format (1v1 et 2v2 ont chacun un Elo — 2v2 = Elo duo).
- Protection : 3 défaites consécutives → prochain match contre bot -100 Elo (garde-fou anti rage-quit, invisible pour le joueur).

## E7. Rangs & saisons

| Rang | Elo | Badge (UI + au-dessus du perso) |
|---|---|---|
| 🪵 Bois | 0-999 | badge brun |
| 🥉 Bronze | 1000-1199 | badge bronze |
| 🥈 Argent | 1200-1399 | badge argent |
| 🥇 Or | 1400-1599 | badge or |
| 💎 Platine | 1600-1799 | badge platine émissif |
| 🔷 Diamant | 1800-1999 | badge diamant + particules |
| 🧠 Brainrot Master | 2000+ | badge violet pulsant |
| 👑 Brainrot God | top 1 de la saison | couronne dorée + statue au Colisée |

**Saisons :** 1 mois calendaire. Fin de saison : reset souple (Elo ramené à 25% de la distance vers 1200), récompenses par rang atteint (Or = 1 œuf Mythique, Platine = 2, Diamant = 3, Master = 1 God garanti, Brainrot God = skin doré + titre). La statue du champion reste affichée au Colisée toute la saison suivante.

## E8. Boutique du Colisée (tokens arène)

| Article | Prix (tokens) | Type |
|---|---|---|
| Œuf Colisée (pool M1, odds egg_golden) | 500 | Consommable |
| Skin "Champion Doré" (aura de combat) | 1 200 | Cosmétique PvP |
| Trail d'attaque feu/foudre/galaxie | 400 chacun | Cosmétique PvP |
| Pose de victoire (3 danses) | 250 chacun | Cosmétique |
| 2e loadout PvP (équipe B sauvegardée) | 800 | Confort |
| Boost +20% revenus 30 min | 100 | Boost |
| Anneau d'entraînement +1 niveau | 600 | Progression base (max via boutique : niv 3) |

## E9. Tournoi du Samedi (bracket hebdo)

- Inscription : samedi 17h30 au NPC doré du hall (gratuit, Elo ≥ 1100 requis, 8 ou 16 joueurs par serveur de tournoi selon les inscrits).
- Déroulé : 17h45 brief → quarts/demi/finale en 1v1 classé (stats normalisées, pas de drapeau de type caché : les types sont affichés pendant la préparation).
- L'écran géant diffuse la finale, les éliminés peuvent parier 50 tokens sur le vainqueur (double ou rien).
- Récompenses : top 8 = 300 tokens • top 4 = 800 + 1 egg_mythic • finaliste = 1 500 + 2 egg_mythic • **champion = 3 000 tokens + 1 brainrot GOD garanti + titre "Champion de la Semaine" (tag au-dessus du perso 7 jours)**.

## E10. Spectateurs

- Pendant un match, les joueurs du hall peuvent cliquer sur l'écran géant → caméra dans les gradins (vue d'ensemble + caméra "suivre l'action").
- Chat local activé pendant les matches (émotes rapides préfabriquées si modération impossible : GG / OH / RIEN DE TEL).
- Les ULTIMES sont visibles depuis les gradins (la fosse flashe au server entier).

## E11. Équilibrage — les 4 règles inviolables

1. **Classé = normalisé** : tiers comptent ×1.15-1.6 max (B3). La collection donne la VARIÉTÉ (capacités, types), pas la victoire.
2. **Le triangle des types est affiché AVANT le match** (pas de rock-paper-scissors caché frustrant) — l'écran de préparation montre le type des 3 brainrots adverses, le joueur peut adapter son ordre.
3. **Aucune monétisation de stats** : les gamepasses PvP ne donnent que tokens/cosmétiques (C6).
4. **Bots plafonnés** : un bot ne dépasse jamais 45% d'Elo du joueur, et perd toujours à 100% après 3 défaites consécutives du joueur.

## E12. Anti-triche PvP (server-authoritative)

- Le combat tourne à 100% sur le serveur (boucle 10 Hz). Le client n'envoie QUE : ActivateAbility, Switch, TriggerUltimate — le serveur valide l'état des jauges avant d'appliquer.
- Variance des dégâts : seed aléatoire généré serveur, transmise aux 2 clients pour l'affichage — impossible de la prédire côté client.
- Détection macro : délai d'activation de capacité identique à ±20ms sur 20 activations → flag modération silencieux.
- Timeout 90s géré serveur ; déconnexion volontaire = défaite (aucune perte de créature).
- Le spectateur est en lecture seule (aucun remote du spectateur vers la simulation).

---
# PARTIE F — CLANS & GUERRES DE TERRITOIRE 🛡️

## F1. Les guildes ("Crews")

| Élément | Règle |
|---|---|
| Création | 500 000 💰, nom 3-16 caractères (filtre Roblox), tag 2-4 lettres, logo parmi 20 emblèmes préfabriqués (pas d'upload custom) |
| Taille | 20 membres max |
| Rôles | Chef (unique, transférable) / Officier (×3 : déclare la guerre, accepte les membres) / Membre |
| Tag visible | [TAG] coloré au-dessus du pseudo (couleur = niveau du coffre) |
| Chat de clan | canal séparé, messages système (guerre, coffre, arrivee/départ) |

## F2. Le coffre de clan (progression commune)

Les membres déposent de l'argent (dons). Le total cumulé fait monter le niveau du coffre — les perks s'appliquent à TOUS les membres :

| Niveau | Dons cumulés requis | Perk permanent |
|---|---|---|
| 1 | 500 K | +3% revenus membres, tag gris |
| 2 | 5 M | +6% revenus, tag bleu |
| 3 | 50 M | +10% revenus, tag doré, aura légère de clan |
| 4 | 500 M | +15% revenus, tag violet, emote exclusive de clan |
| 5 | 5 B | +18% revenus, tag arc-en-ciel, bannière de clan au Colisée |

Les dons ne sont JAMAIS remboursables (anticipation des drames). Le chef et les officiers voient l'historique des dons (transparence).

## F3. La Guerre de territoire (dimanche → jeudi, résultats jeudi 20h)

Deux clans appariés par somme des Elo PvP s'affrontent sur **3 fronts**. Chaque front rapporte des points ; le clan avec le plus de points remporte la guerre.

```text
FRONT 1 — L'ARÈNE (500 pts max)
  5 duels 1v1 programmés (officiers choisissent 5 combattants) : mardi/jeudi 18h
  victoire = 75 pts, défaite = 15 pts (participation)

FRONT 2 — LE VOL (500 pts max)
  Chaque base adverse possède un DRAPEAU de clan (sur la façade de la base)
  Voler le drapeau adverse et le ramener à sa base = 50 pts
  (règles du vol A4 classiques, le drapeau ne compte pas dans la limite de vol)

FRONT 3 — LE BOSS (500 pts max)
  Un méga-boss de guerre (HP ×10) apparaît mardi soir dans la Boss Arena
  Les dégâts CUMULÉS par clan déterminent la part des 500 pts
```

**Récompenses de guerre (au jeudi 20h, annonce serveur + écran de cérémonie) :**
- Clan gagnant : 400 tokens arène + 250 K 💰 par membre + 1 egg_mythic offert à chaque membre ayant marqué ≥ 1 point
- Clan perdant : 100 tokens + 50 K 💰 par membre (la participation vaut toujours quelque chose)
- MVP des 3 fronts : pose de héros au Colisée pendant 7 jours

## F4. Règles anti-abus

- Guerre déclarable uniquement par un officier, max 1 guerre active par clan, 24h de pause après la fin.
- Un joueur ne peut marquer que sur les 2 premiers fronts s'il a joué ≥ 30 min pendant la guerre (anti-multi-comptes factices).
- Les clans de moins de 5 membres actifs ne sont pas appariés (protection des petits clans).
- Fusion de clans impossible (évite les usines à perks).

---
# PARTIE G — ARCHITECTURE TECHNIQUE ROBLOX

## G1. Arborescence du projet

```text
ReplicatedStorage/
├── Config/                        ← ModuleScripts de TOUT l'équilibrage
│   ├── CreatureConfig             (54 créatures + raretés + tiers + stats PvP)
│   ├── EggConfig                  (8 œufs)
│   ├── CombatConfig               (types, capacités, ultimes, équilibrage arène)
│   ├── UpgradeConfig              (composants de base)
│   ├── QuestConfig                (quêtes quotidiennes + PvP)
│   ├── RebirthConfig              (paliers + mondes)
│   ├── MonetizationConfig         (gamepasses/produits, IDs)
│   └── DefaultProfile             (schéma de données V2)
├── Remotes/                       ← RemoteEvents + RemoteFunctions (voir G4)
└── Shared/                        ← NumberFormatter, WeightedRandom, TableUtil, EloUtil

ServerScriptService/
├── Main                           (bootstrap : require tous les Services dans l'ordre)
└── Services/
    ├── DataService                (ProfileService, sauvegarde)
    ├── IncomeService              (calcul des revenus, boucle 1s)
    ├── EggService                 (tirages + rareté)
    ├── PlacementService           (plots, piédestaux)
    ├── FusionService              (tiers de fusion)
    ├── StealService               (TOUTE la logique de vol)
    ├── ShieldService              (cycle bouclier 5/8 min)
    ├── UpgradeService             (achats de base)
    ├── RebirthService
    ├── QuestService
    ├── EventService               (Frénésie, Boss serveur, Confettis)
    ├── AnnouncementService        (Secrets, vols, victoires arène)
    ├── LeaderboardService         (revenus, vols, Elo)
    ├── MonetizationService        (gamepasses + produits)
    ├── AntiCheatService           (rate-limit, rollback vitesse)
    ├── CombatService              (simulation PvP 10 Hz — E3)     ★ NOUVEAU
    ├── ArenaService               (files, matchmaking, instances) ★ NOUVEAU
    ├── TournamentService          (bracket du samedi)             ★ NOUVEAU
    ├── ClanService                (guildes, coffre)               ★ NOUVEAU
    └── WarService                 (guerre 3 fronts)               ★ NOUVEAU

StarterPlayer/StarterPlayerScripts/
├── Main                           (bootstrap client)
└── Controllers/
    ├── HUDController, EggShopController, InventoryController
    ├── BasePanelController, StealAlertController, NotificationController
    ├── SoundController, EffectController
    ├── ArenaController            (files, préparation, résultats)  ★ NOUVEAU
    ├── CombatController           (HP, jauges, boutons E/F)        ★ NOUVEAU
    ├── ClanController             (écran de clan, chat)            ★ NOUVEAU
    └── SpectateController         (caméra gradins)                 ★ NOUVEAU

Workspace/
├── Map_Monde1/  Map_Monde2/  Map_Monde3/  Map_Monde4/
├── Map_Colisee/                  (position Y=1000)
├── ArenaInstances/               (matches isolés, Y=2000, nettoyés après match)
├── Effects/  Placeholders/

ServerStorage/
├── CreatureModels/               (1 Model par CRT_<id>, attribut string "CreatureId")
├── EggModels/  BaseKit/  ArenaKit/ (gradins, écran, torches)
```

## G2. Schéma de données joueur (DefaultProfile V2)

```lua
return {
    Money = 0, Clicks = 0, Rebirths = 0, Playtime = 0, Level = 1,
    WorldUnlocked = 1,

    Creatures = {},
    -- { {Uid="abc", Id="tralalero", Tier=1, PlacedSlot=nil, InPvPTeam=nil}, ... }

    Base = { Plot = nil, Slots = 3, Turret = 0, Alarm = 0, Generator = 0,
             Trap = 0, Vault = 0, TrainingRing = 0, Decor = {} },

    ShieldEndsAt = 0, VulnerableEndsAt = 0, LastStealAttempt = 0,

    PvP = {
        Elo1v1 = 1000, Elo2v2 = 1000,
        ArenaTokens = 0,
        Season = { Id = 1, PeakElo = 1000, Wins = 0, Losses = 0,
                   UltimatesUsed = 0, BestRank = 0 },
        Loadouts = { A = {nil,nil,nil}, B = nil },   -- 3 Uids par loadout
        Tournament = { Entered = false, Wins = 0, Titles = {} },
    },

    Clan = { Id = nil, Donated = 0, Role = nil, WarPoints = 0 },

    Quests = { List = {}, ResetAt = 0, Streak = 0, LastDailyClaim = 0 },
    Stats = { Steals = 0, Defends = 0, Fusions = 0, EggsOpened = 0,
              Earned = 0, ArenaWins = 0, ArenaLosses = 0 },
    Purchases = { Gamepasses = {}, DevProducts = {} },
    Codes = {}, Settings = { Music = true, SFX = true },
}
```

## G3. Sécurité (NON NÉGOCIABLE)

- Toute logique gameplay = serveur. Le client ne fait que DEMANDER et AFFICHER.
- Chaque remote valide : cooldown, distance, propriété, économie (jamais d'argent négatif).
- Rate-limit : 10 requêtes/s par remote par joueur → warn → kick 60s → ban 24h.
- Détection vitesse : déplacement > 50 studs/frame → rollback position.
- **PvP : la simulation tourne à 100% serveur (10 Hz) ; les remotes d'action vérifient l'état des jauges avant application.**
- Logs serveur structurés de toutes les actions sensibles (vol, fusion, achat, matchs, guerre).

## G4. Remotes (liste contractuelle V2)

| Remote | Type | Validation serveur clé |
|---|---|---|
| ClickGain | Event | rate-limit 10/s |
| BuyEgg | Function | argent, inventaire < 150, quantity ∈ {1,10,50} |
| PlaceCreature / UnplaceCreature | Function | possession, slot libre/existant |
| SellCreature | Function | possession, prix = 40% du revenu × 100 |
| RequestFusion | Function | 3 identiques (Id + Tier), Tier < 5 |
| AttemptSteal | Function | cooldowns, bouclier cible OFF, niveau 5 + 1h, créature placée |
| HitThief | Function | distance < 12 studs, cible en état PORTAGE |
| ClaimDropped | Function | proximité, légitimité (propriétaire prioritaire 10s) |
| BuyUpgrade | Function | argent, niveau suivant existant |
| ToggleEmergencyShield | Function | possession du consommable |
| DoRebirth | Function | seuil atteint |
| ClaimQuest | Function | quête complétée non réclamée |
| RedeemCode | Function | code valide, 1 seule fois par compte |
| SyncProfile | Event | serveur → client (throttle 1/s + sur événement) |
| **JoinArenaQueue** | Function | niveau ≥ 5, pas de match en cours, loadout complet |
| **LeaveArenaQueue** | Function | en file uniquement |
| **SetLoadout** | Function | 3 Uids possédés, non volés, brainrots non engagés |
| **ActivateAbility** | Event | jauge pleine côté serveur, match actif |
| **SwitchCreature** | Event | cooldown 5s, remplaçant vivant |
| **TriggerUltimate** | Event | jauge de foule = 100% côté serveur |
| **SpectateMatch** | Function | match en cours, lecture seule |
| **CreateClan / JoinClan / LeaveClan** | Function | argent / invitation / pas de guerre active |
| **DonateClanChest** | Function | argent, pas de remboursement |
| **DeclareWar** | Function | rôle officier+, cooldown 24h, ≥ 5 membres actifs |
| **ReportWarFlag** | Function | drapeau ramené à SA base (distance vérifiée) |

---
## G5. CODE CRITIQUE COMPLET (à copier tel quel)

## G5.1 ReplicatedStorage/Config/CreatureConfig (ModuleScript)

```lua
local CreatureConfig = {}

CreatureConfig.Rarities = {
    {Id="Common",    Name="Commun",       Color=Color3.fromRGB(170,170,170), Weight=60,   SellMult=0.4,  BaseHP=300,  BaseATK=25},
    {Id="Rare",      Name="Rare",         Color=Color3.fromRGB(85,170,255),  Weight=25,   SellMult=0.4,  BaseHP=500,  BaseATK=40},
    {Id="Epic",      Name="Épique",       Color=Color3.fromRGB(170,85,255),  Weight=10,   SellMult=0.4,  BaseHP=850,  BaseATK=65},
    {Id="Legendary", Name="Légendaire",   Color=Color3.fromRGB(255,200,50),  Weight=4,    SellMult=0.45, BaseHP=1400, BaseATK=105},
    {Id="Mythic",    Name="Mythique",     Color=Color3.fromRGB(255,85,85),   Weight=0.9,  SellMult=0.5,  BaseHP=2400, BaseATK=175},
    {Id="God",       Name="Brainrot God", Color=Color3.fromRGB(255,170,0),   Weight=0.09, SellMult=0.55, BaseHP=4000, BaseATK=280},
    {Id="Secret",    Name="SECRET",       Color=Color3.fromRGB(120,60,200),  Weight=0.01, SellMult=0.6,  BaseHP=7000, BaseATK=480},
}

CreatureConfig.Tiers = {
    [1]={Name="Normal",       Mult=1,   PvpMult=1},
    [2]={Name="Doré",         Mult=3,   PvpMult=1.15},
    [3]={Name="Arc-en-ciel",  Mult=10,  PvpMult=1.30},
    [4]={Name="Galaxie",      Mult=40,  PvpMult=1.45},
    [5]={Name="Céleste",      Mult=150, PvpMult=1.60},
}

-- WorldMult appliqué aux stats PvP : M1=1, M2=2.5, M3=6, M4=15
CreatureConfig.Worlds = {
    [1]={Name="Brainrot Street",  Mult=1},
    [2]={Name="Dessert Kingdom",  Mult=2.5},
    [3]={Name="Sushi Abyss",      Mult=6},
    [4]={Name="Candy Space",      Mult=15},
}

CreatureConfig.Creatures = {
    -- MONDE 1 — BRAINROT STREET
    {id="noobini",           name="Noobini Pizzanini",        rarity="Common",    income=10,      world=1, ptype="Salty"},
    {id="tim_cheese",        name="Tim Cheese",               rarity="Common",    income=12,      world=1, ptype="Salty"},
    {id="fluriflura",        name="FluriFlura",               rarity="Common",    income=15,      world=1, ptype="Fruity"},
    {id="pipi_kiwi",         name="Pipi Kiwi",                rarity="Common",    income=18,      world=1, ptype="Fruity"},
    {id="talpa",             name="Talpa Di Fero",            rarity="Common",    income=22,      world=1, ptype="Salty"},
    {id="trippi",            name="Trippi Troppi",            rarity="Rare",      income=65,      world=1, ptype="Salty"},
    {id="tung_tung",         name="Tung Tung Tung Sahur",     rarity="Rare",      income=80,      world=1, ptype="Salty"},
    {id="boneca",            name="Boneca Ambalabu",          rarity="Rare",      income=95,      world=1, ptype="Salty"},
    {id="footera",           name="Gangster Footera",         rarity="Rare",      income=110,     world=1, ptype="Salty"},
    {id="chim_banana",       name="Chimpanzini Bananini",     rarity="Rare",      income=130,     world=1, ptype="Fruity"},
    {id="cappuccino",        name="Cappuccino Assassino",     rarity="Epic",      income=400,     world=1, ptype="Salty"},
    {id="patapim",           name="Brr Brr Patapim",          rarity="Epic",      income=480,     world=1, ptype="Fruity"},
    {id="blueberrini",       name="Blueberrinni Octopusini",  rarity="Epic",      income=550,     world=1, ptype="Fruity"},
    {id="strawberelli",      name="Strawberelli Flamingelli", rarity="Epic",      income=620,     world=1, ptype="Fruity"},
    {id="burbaloni",         name="Burbaloni Loliloli",       rarity="Legendary", income=2500,    world=1, ptype="Salty"},
    {id="bombombini",        name="Bombombini Gusini",        rarity="Legendary", income=3000,    world=1, ptype="Salty"},
    {id="frigo_camelo",      name="Frigo Camelo",             rarity="Legendary", income=3600,    world=1, ptype="Salty"},
    {id="tukanno",           name="Tukanno Bananno",          rarity="Legendary", income=4200,    world=1, ptype="Fruity"},
    {id="bombardiro",        name="Bombardiro Crocodilo",     rarity="Mythic",    income=15000,   world=1, ptype="Salty"},
    {id="lirili",            name="Lirili Larila",            rarity="Mythic",    income=18000,   world=1, ptype="Fruity"},
    {id="glorbo",            name="Glorbo Fruttodrillo",      rarity="Mythic",    income=22000,   world=1, ptype="Fruity"},
    {id="gorillo",           name="Gorillo Watermelondrillo", rarity="Mythic",    income=26000,   world=1, ptype="Fruity"},
    {id="tralalero",         name="Tralalero Tralala",        rarity="God",       income=90000,   world=1, ptype="Salty"},
    {id="vaca",              name="La Vaca Saturno Saturnita",rarity="God",       income=110000,  world=1, ptype="Salty"},
    {id="sammyni",           name="Sammyni Spyderini",        rarity="God",       income=130000,  world=1, ptype="Salty"},
    {id="girafa",            name="Girafa Celestre",          rarity="God",       income=150000,  world=1, ptype="Fruity"},
    {id="los_tralaleritos",  name="Los Tralaleritos",         rarity="Secret",    income=600000,  world=1, ptype="Salty"},
    {id="chicleteira",       name="Chicleteira Bicicleteira", rarity="Secret",    income=800000,  world=1, ptype="Sweet"},
    {id="la_grande",         name="La Grande Combinazione",   rarity="Secret",    income=1000000, world=1, ptype="Salty"},
    {id="garama",            name="Garama and Madundung",     rarity="Secret",    income=1500000, world=1, ptype="Salty"},
    -- MONDE 2 — DESSERT KINGDOM
    {id="biscottino",          name="Biscottino Ballerino",       rarity="Rare",      income=8000,     world=2, ptype="Sweet"},
    {id="gelato_gangsterino",  name="Gelato Gangsterino",         rarity="Rare",      income=12000,    world=2, ptype="Sweet"},
    {id="tiramisu_tornado",    name="Tiramisù Tornado",           rarity="Epic",      income=30000,    world=2, ptype="Sweet"},
    {id="macaroni_mago",       name="Macaroni Mago",              rarity="Epic",      income=45000,    world=2, ptype="Sweet"},
    {id="donut_drago",         name="Donut Drago",                rarity="Legendary", income=150000,   world=2, ptype="Sweet"},
    {id="croissant_crusherino",name="Croissant Crusherino",       rarity="Legendary", income=220000,   world=2, ptype="Sweet"},
    {id="gateau_guardiano",    name="Gateau Guardiano",           rarity="Mythic",    income=900000,   world=2, ptype="Sweet"},
    {id="millefeuille_celestre",name="Millefeuille Célestre",     rarity="Secret",    income=6000000,  world=2, ptype="Sweet"},
    -- MONDE 3 — SUSHI ABYSS
    {id="onigirino_orcano",  name="Onigirino Orcano",           rarity="Rare",      income=150000,   world=3, ptype="Salty"},
    {id="maki_rayona",       name="Maki Rayona",                rarity="Rare",      income=220000,   world=3, ptype="Fruity"},
    {id="nigiri_anguilla",   name="Nigiri Anguilla",            rarity="Epic",      income=500000,   world=3, ptype="Salty"},
    {id="tempura_titano",    name="Tempura Titano",             rarity="Epic",      income=750000,   world=3, ptype="Salty"},
    {id="ramen_krakeno",     name="Ramen Krakeno",              rarity="Legendary", income=2500000,  world=3, ptype="Salty"},
    {id="unagi_imperatore",  name="Unagi Imperatore",           rarity="Legendary", income=4000000,  world=3, ptype="Salty"},
    {id="wasabi_wraitho",    name="Wasabi Wraitho",             rarity="Mythic",    income=15000000, world=3, ptype="Salty"},
    {id="sushi_shogun",      name="Sushi Shogun Supremo",       rarity="Secret",    income=80000000, world=3, ptype="Salty"},
    -- MONDE 4 — CANDY SPACE
    {id="bonbonni_bourdonna",  name="Bonbonni Bourdonna",        rarity="Rare",      income=3000000,   world=4, ptype="Sweet"},
    {id="chamallow_astronauta",name="Chamallow Astronauta",      rarity="Rare",      income=5000000,   world=4, ptype="Sweet"},
    {id="sucetta_satellita",   name="Sucetta Satellita",         rarity="Epic",      income=12000000,  world=4, ptype="Sweet"},
    {id="gommosa_galattica",   name="Gommosa Galattica",         rarity="Epic",      income=20000000,  world=4, ptype="Sweet"},
    {id="cotone_cosmico",      name="Cotone Cosmico",            rarity="Legendary", income=60000000,  world=4, ptype="Sweet"},
    {id="caramel_cometa",      name="Caramel Cometa",            rarity="Legendary", income=100000000, world=4, ptype="Fruity"},
    {id="gravita_grandosa",    name="Gravita Grandosa",          rarity="Mythic",    income=500000000, world=4, ptype="Sweet"},
    {id="ourson_galattico",    name="Ourson Galattico",          rarity="Secret",    income=3000000000,world=4, ptype="Sweet"},
}

function CreatureConfig:Get(id)
    for _,c in ipairs(self.Creatures) do if c.id == id then return c end end
end
function CreatureConfig:GetRarity(rarityId)
    for _,r in ipairs(self.Rarities) do if r.Id == rarityId then return r end end
end
-- Stats PvP normalisées (mode classé) ou brutes (mode libre)
function CreatureConfig:GetCombatStats(id, tier, ranked)
    local c = self:Get(id); if not c then return nil end
    local r = self:GetRarity(c.rarity)
    local w = self.Worlds[c.world] or self.Worlds[1]
    local t = self.Tiers[tier] or self.Tiers[1]
    local mult = ranked and t.PvpMult or t.Mult
    return {
        HP  = math.floor(r.BaseHP  * w.Mult * mult),
        ATK = math.floor(r.BaseATK * w.Mult * mult),
        Type = c.ptype,
    }
end
return CreatureConfig
```

## G5.2 ReplicatedStorage/Config/EggConfig (ModuleScript)

```lua
local EggConfig = {}
EggConfig.Eggs = {
    {id="egg_basic",  name="Œuf Street Basic", price=100,          world=1,
     pool={"noobini","tim_cheese","fluriflura","pipi_kiwi","talpa","trippi"},
     odds={Common=85,Rare=15}},
    {id="egg_street", name="Œuf Street",        price=8500,        world=1,
     pool={"noobini","trippi","tung_tung","boneca","footera","chim_banana","cappuccino","patapim"},
     odds={Common=10,Rare=55,Epic=33,Legendary=2}},
    {id="egg_golden", name="Œuf Golden",        price=150000,      world=1,
     pool={"chim_banana","cappuccino","patapim","blueberrini","strawberelli","burbaloni","bombombini","frigo_camelo","tukanno"},
     odds={Rare=20,Epic=55,Legendary=22,Mythic=3}},
    {id="egg_mythic", name="Œuf Mythic",        price=5000000,     world=1,
     pool={"burbaloni","bombombini","frigo_camelo","tukanno","bombardiro","lirili","glorbo","gorillo"},
     odds={Epic=25,Legendary=50,Mythic=22,God=3}},
    {id="egg_secret", name="Œuf Interdit",      price=250000000,   world=1,
     pool={"gorillo","tralalero","vaca","sammyni","girafa","los_tralaleritos","chicleteira","la_grande","garama"},
     odds={Legendary=30,Mythic=35,God=34.5,Secret=0.5}},
    {id="egg_dessert",name="Œuf Dessert",       price=25000000,    world=2,
     pool={"biscottino","gelato_gangsterino","tiramisu_tornado","macaroni_mago","donut_drago","croissant_crusherino","gateau_guardiano","millefeuille_celestre"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
    {id="egg_abyss",  name="Œuf Abyss",         price=2000000000,  world=3,
     pool={"onigirino_orcano","maki_rayona","nigiri_anguilla","tempura_titano","ramen_krakeno","unagi_imperatore","wasabi_wraitho","sushi_shogun"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
    {id="egg_cosmic", name="Œuf Cosmic",        price=200000000000,world=4,
     pool={"bonbonni_bourdonna","chamallow_astronauta","sucetta_satellita","gommosa_galattica","cotone_cosmico","caramel_cometa","gravita_grandosa","ourson_galattico"},
     odds={Rare=55,Epic=33,Legendary=10,Mythic=1.9,Secret=0.1}},
}
function EggConfig:Get(id)
    for _,e in ipairs(self.Eggs) do if e.id == id then return e end end
end
return EggConfig
```

## G5.3 ReplicatedStorage/Config/CombatConfig (ModuleScript)

```lua
local CombatConfig = {}

CombatConfig.TypeCycle = { Salty="Sweet", Sweet="Fruity", Fruity="Salty" } -- qui bat qui
CombatConfig.TypeBonus = 0.20      -- +20% dégâts sur le type battu
CombatConfig.AutoAttackInterval = 1.5
CombatConfig.Variance = 0.10       -- ±10% dégâts
CombatConfig.AbilityChargeTime = 8      -- s pour remplir la jauge
CombatConfig.SwitchCooldown = 5
CombatConfig.BenchRegen = 0.02           -- +2%/s sur le banc
CombatConfig.CrowdPerHitDealt = 0.04     -- jauge de foule
CombatConfig.CrowdPerHitTaken = 0.02
CombatConfig.UltimateMultiplier = 3
CombatConfig.MatchTimeout = 90
CombatConfig.InvulnAfterSwitch = 0.5

-- Capacités : kind = Burst | Heal | Shield | Control
-- power : Burst = mult dégâts | Heal = %HP | Shield = nb coups | Control = durée stun
-- cdPlus : cooldown additionnel
CombatConfig.Abilities = {
    -- Monde 1
    noobini={name="Pizza Slash",kind="Burst",power=3,cdPlus=0},
    tim_cheese={name="Cheese Melt",kind="Heal",power=0.4,cdPlus=0},
    fluriflura={name="Pollen Dodo",kind="Control",power=2,cdPlus=0},
    pipi_kiwi={name="Kiwi Splash",kind="Burst",power=3,cdPlus=0,atkDown=0.10,duration=3},
    talpa={name="Tunnel Trap",kind="Control",power=2,cdPlus=0},
    trippi={name="Shrimp Punch",kind="Burst",power=3,cdPlus=0},
    tung_tung={name="Bam Bam Bam",kind="Burst",power=3,cdPlus=0,shake=true},
    boneca={name="Tire Bounce",kind="Shield",power=2,cdPlus=0},
    footera={name="Drive-By",kind="Burst",power=3,cdPlus=0},
    chim_banana={name="Banana Split",kind="Heal",power=0.4,cdPlus=0},
    cappuccino={name="Espresso Rush",kind="Burst",power=3,cdPlus=0,speedUp=0.3,duration=5},
    patapim={name="Brr Frost",kind="Control",power=2,cdPlus=0},
    blueberrini={name="Ink Blast",kind="Burst",power=3,cdPlus=0,blind=0.15,duration=3},
    strawberelli={name="Flambée",kind="Burst",power=3,cdPlus=0},
    burbaloni={name="Loli Lasso",kind="Control",power=2,cdPlus=0},
    bombombini={name="Bomb Barrage",kind="Burst",power=3.5,cdPlus=2},
    frigo_camelo={name="Frigorification",kind="Control",power=2.5,cdPlus=0},
    tukanno={name="Beak Barrage",kind="Burst",power=3,cdPlus=0},
    bombardiro={name="Bombardement",kind="Burst",power=4,cdPlus=2},
    lirili={name="Cactus Spikes",kind="Shield",power=2,cdPlus=0,reflect=0.25,duration=5},
    glorbo={name="Juice Flood",kind="Heal",power=0.4,cdPlus=0,cleanse=true},
    gorillo={name="Melon Slam",kind="Burst",power=3.5,cdPlus=0},
    tralalero={name="TRALALERO !",kind="Burst",power=4,cdPlus=0,crowdBoost=0.25},
    vaca={name="Saturn Rings",kind="Shield",power=3,cdPlus=0},
    sammyni={name="Spider Web",kind="Control",power=2.5,cdPlus=0},
    girafa={name="Neck Whip",kind="Burst",power=3.5,cdPlus=0},
    los_tralaleritos={name="Chorus Attack",kind="Burst",power=4.5,cdPlus=3},
    chicleteira={name="Gum Trap",kind="Control",power=3,cdPlus=0},
    la_grande={name="La Combinazione",kind="Heal",power=0.5,cdPlus=0,atkUp=0.2,duration=5},
    garama={name="Madundung Quake",kind="Burst",power=5,cdPlus=4},
    -- Monde 2
    biscottino={name="Grand Jeté",kind="Burst",power=3,cdPlus=0},
    gelato_gangsterino={name="Cold Deal",kind="Control",power=2,cdPlus=0},
    tiramisu_tornado={name="Tempête de Cacao",kind="Burst",power=3,cdPlus=0,blind=0.15,duration=3},
    macaroni_mago={name="Abracadolce",kind="Control",power=2,cdPlus=0},
    donut_drago={name="Souffle Sucre",kind="Burst",power=3.5,cdPlus=0},
    croissant_crusherino={name="Croque Suprême",kind="Burst",power=3.5,cdPlus=0},
    gateau_guardiano={name="Mur de Crème",kind="Shield",power=3,cdPlus=0},
    millefeuille_celestre={name="Feuilleton Divin",kind="Burst",power=4.5,cdPlus=3},
    -- Monde 3
    onigirino_orcano={name="Orca Bite",kind="Burst",power=3,cdPlus=0},
    maki_rayona={name="Glide Sting",kind="Burst",power=3,cdPlus=0,atkDown=0.10,duration=3},
    nigiri_anguilla={name="Électro-Shock",kind="Control",power=2,cdPlus=0},
    tempura_titano={name="Friture Impact",kind="Burst",power=3.5,cdPlus=0},
    ramen_krakeno={name="Sauce Piquante",kind="Burst",power=3.5,cdPlus=0},
    unagi_imperatore={name="Décret Impérial",kind="Heal",power=0.4,cdPlus=0,speedUp=0.15,duration=4},
    wasabi_wraitho={name="Sinus Inferno",kind="Control",power=2.5,cdPlus=0},
    sushi_shogun={name="Iai Sushi",kind="Burst",power=5,cdPlus=4},
    -- Monde 4
    bonbonni_bourdonna={name="Buzz Dash",kind="Burst",power=3,cdPlus=0},
    chamallow_astronauta={name="Moon Bounce",kind="Shield",power=2,cdPlus=0},
    sucetta_satellita={name="Satellite Lock",kind="Control",power=2,cdPlus=0},
    gommosa_galattica={name="Wobble Quake",kind="Burst",power=3,cdPlus=0},
    cotone_cosmico={name="Douce Nuée",kind="Heal",power=0.5,cdPlus=0},
    caramel_cometa={name="Comet Crash",kind="Burst",power=3.5,cdPlus=0},
    gravita_grandosa={name="Puits de Gravité",kind="Control",power=2.5,cdPlus=0},
    ourson_galattico={name="Calin Cosmique",kind="Burst",power=5,cdPlus=4},
}

-- Ultime : type → effet bonus
CombatConfig.UltimateBonus = {
    Salty = {atkDown=0.25, duration=5},
    Sweet = {healTeam=0.30},
    Fruity= {stun=2.5},
}

function CombatConfig:GetAbility(creatureId)
    return self.Abilities[creatureId] or {name="Charge",kind="Burst",power=3,cdPlus=0}
end
return CombatConfig
```

## G5.4 Shared/EloUtil (ModuleScript)

```lua
local EloUtil = {}
EloUtil.__index = EloUtil

local K = 32
function EloUtil.Calculate(ra, rb, scoreA)   -- scoreA : 1 = victoire, 0 = défaite, 0.5 = nul
    local ea = 1 / (1 + 10 ^ ((rb - ra) / 400))
    local eb = 1 / (1 + 10 ^ ((ra - rb) / 400))
    return ra + K * (scoreA - ea), rb + K * ((1 - scoreA) - eb)
end

function EloUtil.GetRank(elo)
    if elo >= 2000 then return "BrainrotMaster", 8 end
    if elo >= 1800 then return "Diamant", 7 end
    if elo >= 1600 then return "Platine", 6 end
    if elo >= 1400 then return "Or", 5 end
    if elo >= 1200 then return "Argent", 4 end
    if elo >= 1000 then return "Bronze", 3 end
    return "Bois", 2
end

function EloUtil.SoftReset(elo)  -- fin de saison : ramené à 25% de la distance vers 1200
    return elo - 0.25 * (elo - 1200)
end
return EloUtil
```

## G5.5 ServerScriptService/Services/ArenaService (spécification d'implémentation)

```lua
-- ArenaService : files + matchmaking + instances de match
-- State : queues = { [format] = { {player, elo, joinTime}, ... } }, matches = {}
-- JoinArenaQueue(player, format) :
--   VÉRIF : Level>=5, pas de match actif, Loadout A complet (3 créatures possédées)
--   → ajouter à la file avec l'Elo du format, lancer MatchmakingTick si file length ≥ 1
-- MatchmakingTick (toutes les 5s) :
--   trier par elo ; pour chaque paire |elo1-elo2| <= range (150 + 50 par tranche de
--   20s d'attente, max 400) → créer match ; sinon si attente > 30s → proposer bot
--   (elo = joueur - 100, refusable = retour file prioritaire)
-- CreateMatch(p1, p2, format, ranked) :
--   1. réserver une arène dans Workspace/ArenaInstances (clone du template fosse,
--      position Y=2000, offset X aléatoire de 500 pour isolation)
--   2. marquer les 6 créatures "engagées" (InPvTTeam = matchId → invulnérables au vol)
--   3. construire state = {
--        players = {A={userId, models, hp, bench, switchCd, crowd, abilityCharge},
--                   B={...}},
--        seed = math.random(1, 2^31), tick = 0, ranked = ranked, timeout = 90
--      }
--   4. téléporter les 2 joueurs en loges, lancer CombatService:Start(state)
-- EndMatch(state, winner) :
--   → EloUtil.Calculate si ranked ; tokens (25/8 + 2/min) ; stats ; quests update
--   → écran de résultat via SyncProfile + RemoteEvent MatchEnded
--   → nettoyer l'instance, désengager les créatures, téléport retour hall
--   → 3 défaites consécutives → flag "nextMatchBot"
-- SpectateMatch(player, matchId) : téléport gradins, SpectateController ON (lecture)
```

## G5.6 ServerScriptService/Services/CombatService (spécification — cœur PvP)

```lua
-- CombatService : simulation server-authoritative à 10 Hz (RunService.Heartbeat × 0.1)
-- Start(state) : boucle task.spawn :
--   toutes les 0.1s :
--     tick += 0.1
--     pour chaque joueur : abilityCharge += 0.1/8 ; bench regen ; switchCd -= 0.1
--     auto-attaque : si tick - lastAttack >= 1.5 - speedMod → résoudre le coup :
--       dmg = ATK × typeMultiplier(attacker.Type, defender.Type) × (1 + variance)
--       variance = (seed → SharedRandom:NextNumber(-0.10, 0.10))  [seed partagé client]
--       appliquer au bouclier si actif (décrémenter hits) sinon aux HP
--       crowd += 4% (attaquant) / 2% (défenseur) ; push HP/jauges via RemoteEvent (10 Hz)
--     mort : HP<=0 → ragdoll 1.5s → switch auto suivant ou victoire si équipe vide
--     timeout : tick >= 90 → vainqueur = total HP% le plus élevé
-- ActivateAbility(player) :
--   VÉRIF SERVEUR : abilityCharge >= 1 (sinon ignore), pas stunned
--   → appliquer selon kind (Burst/Heal/Shield/Control + options atkDown/reflect/...)
--   → abilityCharge = 0 ; log MacroWatch (timing)
-- SwitchCreature(player, slot) : VÉRIF switchCd <= 0 et bench[slot].hp > 0
-- TriggerUltimate(player) : VÉRIF crowd >= 1 → FreezeMatch 3s (cinématique,
--   visible spectateurs) → dmg 3×ATK + UltimateBonus[type] → crowd = 0
-- Tous les pushs client passent par 1 seul RemoteEvent "CombatSync" (10 Hz) :
--   {hpA, hpB, activeA, activeB, chargeA, chargeB, crowdA, crowdB, switchCd,
--    events={...}}  (events = liste des animations à jouer ce tick)
```

## G5.7 ServerScriptService/Services/StealService (complément V2)

```lua
-- Identique V1 (machine à états A4) + 2 ajouts :
-- 1. AttemptSteal VÉRIF supplémentaire : creature.InPvTTeam == nil
--    (les brainrots engagés en arène sont invulnérables)
-- 2. Guerre de clans : StealService expose StealFlag(thief, targetClan)
--    (mêmes règles que le vol, le drapeau ne compte pas dans le cooldown,
--    rapporte 50 points de guerre via WarService:ReportFlagStolen)
```

## G5.8 Idles des créatures (Roblox, PAS d'animation Blender)

Pour chaque modèle placé : TweenService en boucle — balancement rotation Z ±8° (1.2s, Sine) + flottement Y ±0.2 pour les volants (vaca, girafa, garama, millefeuille_celestre, ourson_galattico, cotone_cosmico…). Tier ≥ 3 : ParticleEmitter d'aura. Secret : Trail + PointLight violette #3A0CA3. **En arène : idle "combat" = rotation vers l'adversaire + bob rapide 0.4s.**

---
# PARTIE H — PLAN DE PRODUCTION A→Z (19 ÉTAPES)

> **Méthode :** l'IA MCP exécute le prompt de chaque étape, PUIS l'humain valide le critère ✅ avant de passer à la suivante. Placeholder = géométrie simple qui FONCTIONNE. Un système = un test. Jamais 2 systèmes d'avance.

## H1. Workflow MCP

```text
[1] Blender MCP ──→ génère les modèles 3D → export FBX D:/SABL_Assets/
        │
[2] Import FBX ──→ Roblox Asset Manager (semi-manuel) → ServerStorage/CreatureModels
        │
[3] Roblox Studio MCP ──→ construit les maps, insère les scripts, configure tout
        │
[4] Test in Studio ──→ l'humain reporte les bugs ──→ itération
```

## H2. Les 19 étapes

| # | Étape | Outil | Livrable | Validation ✅ |
|---|---|---|---|---|
| 0 | Setup MCP + projet | Humain | Studio + 2 MCP installés, place créée, API Services ON, dossier `D:/SABL_Assets/` | Les deux MCP répondent |
| 1 | Arborescence + map blanche M1 | Studio MCP | Prompt D1.6 + arborescence G1 | On court du hub à chaque plot |
| 2 | Config + DataService | Studio MCP | Modules G5.1/G5.2 + DefaultProfile G2 + DataService | Play → argent persiste après rejoin |
| 3 | Clics + œufs + UI | Studio MCP | ClickGain, EggService, HUD, boutique d'œufs | 100 œufs → distribution ≈ odds ±5% |
| 4 | Placement + revenus + fusion | Studio MCP | PlacementService, IncomeService, FusionService | Revenu/s = calcul manuel ; 3 noobini → Doré ×3 |
| 5 | Vol + défense | Studio MCP | StealService + ShieldService (A4) | Poursuite à 2 joueurs OK, débutant protégé |
| 6 | Batch Blender A | Blender MCP | 5 communs + egg_basic (fiches B5) | Importés, placés, idles OK |
| 7 | Batchs Blender B→D | Blender MCP | 25 brainrots M1 restants + 4 œufs | 30 modèles vivants en jeu |
| 8 | Map détaillée M1 | Blender + Studio MCP | Props ruelles D1.4, graffitis, skyline | Une chase hub→plot = FUN (rampes/trampolines) |
| 9 | Rebirth + upgrades | Studio MCP | RebirthService, UpgradeConfig, anneau d'entraînement | Rebirth 1 → ×2 vérifié |
| 10 | Rétention | Studio MCP | QuestService, EventService, streak | Frénésie se déclenche, quêtes claimables |
| 11 | Monétisation | Studio MCP | MonetizationService, 9 produits C6 | Achat test, bonus appliqués |
| 12 | Annonces + leaderboards | Studio MCP | AnnouncementService, 2 classements hub | Annonce Secret visible par tous |
| **13** | **Colisée + combat PvP** | **Studio MCP** | Map D5.6, ArenaService G5.5, CombatService G5.6, UI combat E4 | **Match 1v1 complet vs bot : capacités, switch, ultime, résultat** |
| **14** | **Elo + saisons + tournoi** | **Studio MCP** | EloUtil G5.4, rangs E7, boutique tokens E8, TournamentService E9 | Elo varie ±32 ; badge affiché ; bracket jouable |
| **15** | **Clans + guerres** | **Studio MCP** | ClanService F1-F2, WarService F3, écran clan | Guerre simulée complète (2 testeurs + bots) |
| **16** | **Mondes 2-4** | **Blender + Studio MCP** | Maps D2/D3/D4 + 24 brainrots B6 + 3 œufs + portails | Chaque monde visitable, courants/bulles/gravité OK |
| 17 | Playtests & équilibrage | Humain + IA | 3 sessions testeurs, ajustements | Compris en 60s ; PvP fun à 2 skill levels |
| 18 | Publication | Humain | Icône, thumbnails, description, codes | Jeu public 🚀 |

## H3. Prompts détaillés des étapes nouvelles (13 à 16)

### ÉTAPE 13 — Colisée + combat

```text
Prompt A (map) : "Exécute le prompt D5.6 du document : Workspace/Map_Colisee (coque r=90,
fosse r=30 avec 2 cercles d'apparition, gradins 24 segments, écran géant SurfaceGui,
hall r=45 avec 3 leaderboards et 4 loges, 60 NPC spectateurs, 4 braseros). Y=1000."

Prompt B (services) : "Crée ArenaService (G5.5 : files 1v1/2v2, matchmaking Elo ±150
élargi, bots si >30s, isolation Y=2000, créatures marquées InPvTeam invulnérables au vol)
et CombatService (G5.6 : simulation 10 Hz server-authoritative, auto-attaque 1.5s, jauges
capacité 8s, switch cooldown 5s, jauge de foule, ultime 3×ATK + bonus type, timeout 90s,
push unique CombatSync 10 Hz). Remotes JoinArenaQueue, ActivateAbility, SwitchCreature,
TriggerUltimate, SpectateMatch selon G4."

Prompt C (UI) : "Crée ArenaController + CombatController : écran de préparation (sélection
3 brainrots, types adverses affichés E11), écran de combat (2 barres HP, 2 jauges capacité,
jauge de foule dorée, boutons ACTIVER/SWITCH×2/ULTIME ≥44px), écran de résultat (HP restants,
dégâts, Elo avant/après, tokens). Sons E7 via SoundController."
```

### ÉTAPE 14 — Elo + saisons + tournoi

```text
"Crée Shared/EloUtil (G5.4). Ajoute les rangs E7 (badges UI + au-dessus du perso), la
saison mensuelle (reset soupe, récompenses par rang atteint, statue du champion au Colisée),
la boutique du Colisée E8 (7 articles, monnaie tokens), le TournamentService E9 (inscription
samedi 17h30, bracket 8/16, 1v1 normalisé, paris 50 tokens, récompenses champion = God garanti
+ titre 7 jours). Panneaux Elo du hall alimentés par OrderedDataStore."
```

### ÉTAPE 15 — Clans + guerres

```text
"Crée ClanService (F1-F2 : création 500K, 20 membres, rôles, coffre 5 niveaux, tag coloré,
chat) et WarService (F3 : appariement Elo, 3 fronts — 5 duels programmés, vol de drapeau
50 pts via StealService:StealFlag, boss de guerre cumulatif — cérémonie jeudi 20h, récompenses,
anti-abus F4). Remote CreateClan/JoinClan/LeaveClan/DonateClanChest/DeclareWar/ReportWarFlag."
```

### ÉTAPE 16 — Mondes 2-4

```text
Prompt A (maps) : "Duplique Map_Monde1 vers Map_Monde2/3/4 et applique les rethèmes D2.6,
D3.6, D4.6 (palettes, rivière chocolat, courant marin + colonnes de bulles, gravité faible
+ tapis roulants + astéroïdes). Portails hub M1 → conditions rebirth 3/5/10 (RebirthService)."

Prompt B (créatures) : "Génère les 24 modèles B6 (batchs Blender E/F/G/H : 6 par batch)
puis importe-les dans ServerStorage/CreatureModels avec attributs CreatureId. Ajoute
egg_dessert/egg_abyss/egg_cosmic à EggConfig (G5.2) et étends la boutique d'œufs
(onglets par monde C6). Zones uniques : Cascade Caramel, Grotte du poisson-lanterne,
mini-obbys astéroïdes (E8/D2-D4)."
```

## H4. Batchs Blender (ordre optimal)

| Batch | Contenu | Étape |
|---|---|---|
| A | 5 communs M1 + egg_basic | 6 |
| B | 5 rares M1 + egg_street | 7 |
| C | 4 épiques M1 + egg_golden | 7 |
| D | 4 légendaires + 4 mythiques M1 + egg_mythic | 7 |
| E | 4 gods + 4 secrets M1 + egg_secret | 7 |
| F | Kit base (piédestaux, tourelle, alarme…) + props ruelles | 8 |
| G | 24 créatures mondes 2-4 + 3 œufs + props thématiques | 16 |
| H | Colisée (coque, gradins, écran, torches, NPC spectateurs) | 13 |

## H5. Les règles d'or de la production

1. Un système = un test à chaque étape. Jamais 2 systèmes d'avance.
2. Playtest chaque soir : 2-3 amis/testeurs (surtout pour le PvP dès l'étape 13).
3. Placeholders d'abord, la beauté ensuite : des cubes gris qui marchent > de beaux modèles buggés.
4. La config d'abord : tous les chiffres → modules Config AVANT les scripts qui les utilisent.
5. Sauvegarde `.rbxl` quotidienne (Fichier → Enregistrer sur fichier).
6. PvP : valider le FUN du combat (étape 13) AVANT d'investir dans le Colisée final.
7. Les mondes 2-4 partagent les scripts M1 : seule la map change — ne pas dupliquer le code.

---
# PARTIE I — CHECKLIST DE PUBLICATION + CODES DE LANCEMENT

## I1. Checklist technique

- [ ] DataStores testés (rejoin = progression intacte, 2 comptes simultanés)
- [ ] Rate-limit + validations serveur sur TOUS les remotes (G4 — y compris ActivateAbility/SwitchCreature/TriggerUltimate)
- [ ] Probabilités affichées dans l'UI des œufs (conformité Roblox)
- [ ] Mobile : HUD lisible en 720p, boutons ≥ 44px (boutons de combat ≥ 44px, ULTIME ≥ 56px)
- [ ] Bouclier débutant fonctionnel (compte niveau 1 ne peut rien subir)
- [ ] Interaction vol = ProximityPrompt "E" (PC + mobile)
- [ ] Match PvP complet testé : capacité → switch → ultime → timeout → déconnexion volontaire = défaite sans perte
- [ ] 3 défaites consécutives → bot de garde-fou (invisible)
- [ ] La déconnexion en plein match NE DÉTRUIT JAMAIS de créature (double-check CombatService + DataService)
- [ ] Performance : 60 FPS PC / 30 FPS mobile sur les 5 maps (StreamingEnabled ON, meshes fusionnés par zone)
- [ ] Instances d'arène nettoyées après chaque match (vérifier Workspace/ArenaInstances vide après 10 matchs)
- [ ] Guerre de clans : impossible de marquer avec un compte < 30 min de jeu de guerre

## I2. Checklist gameplay PvP

- [ ] Le triangle des types est AFFICHÉ pendant la préparation du match (E11.2)
- [ ] Aucun gamepass n'augmente ATK/HP en classé (E11.3)
- [ ] Bots plafonnés à 45% de l'Elo du joueur (E11.4)
- [ ] Elo : victoire/défaite = ±32 max, vérifié sur 10 matchs
- [ ] Le mode "Arène Libre" est clairement étiqueté "stats brutes, pas d'Elo"

## I3. Codes de lancement (via RedeemCode)

| Code | Effet |
|---|---|
| `RELEASE` | 10 000 💰 |
| `TUNGXTUNG` | 1 egg_street |
| `LEGENDS` | 30 min ×2 revenus |
| `COLISEE` | 150 tokens arène (code de lancement du PvP) |
| `FAMILY` | 1 rare garanti + pose de clan 24h |

## I4. Marketing de lancement

- **Icône 512×512 :** Tralalero en gros plan + éclat doré + texte "STEAL A BRAINROT: LEGENDS" lisible en miniature.
- **3 thumbnails :** (1) poursuite de vol avec le dôme bleu en arrière-plan, (2) affrontement au Colisée avec l'ultime doré, (3) base remplie de brainrots Galaxie.
- **Titre :** "Steal a Brainrot Legends ⚔️PVP ARENA [NEW]" (mots-clés vol + brainrot + pvp).
- **Description :** pitch 2 lignes + "⚔️ NOUVEAU : Colisée PvP, clans et guerres !" + les codes I3.
- **Publication :** un MARDI ou JEUDI entre 16h-18h (pic d'audience Europe/US).
- **Mise à jour PvP post-lancement :** garder le tournoi à bracket "double élimination" et les saisons thématiques en réserve (roadmap publique = rétention).

## I5. Roadmap post-lancement (teaser à mettre en description)

| Semaine | Contenu |
|---|---|
| S1 | Corrections + équilibrage œufs/vol selon données |
| S2 | Trading sécurisé (interface à double confirmation) |
| S3 | 2e saison arène + skin saisonnier + 1 brainrot God inédit |
| S4 | Mode 3v3 en arène ( étude de faisabilité d'abord) |
| S5+ | Monde 5 (thème au choix du créateur) + boss raid 8 joueurs |

---

# 📌 COMMENT UTILISER CE DOCUMENT

1. **Copie** l'intégralité du fichier `GAME_MASTER_V2.md`.
2. **Donne-le** à ton IA avec MCP Blender + Roblox Studio avec le prompt d'exécution (en tête de document) :
   > "Lis ce document maître et suis le plan de production de la PARTIE H, en commençant par l'ÉTAPE 0 puis l'ÉTAPE 1. Valide chaque étape avec moi avant de continuer."
3. **Valide** chaque étape avec le critère ✅ de H2 — ne laisse jamais l'IA avancer 2 systèmes d'un coup.
4. **Itère :** si un prompt MCP échoue, note le message d'erreur exact et redemande une réécriture au format de ton MCP.

## ⚠️ 5 conseils pour réussir

1. **Ne saute aucune étape** — si l'IA veut tout faire d'un coup, freine-la.
2. **Teste le PvP tôt avec de vrais humains** (étape 13) : si le combat n'est pas fun en placeholder gris, il ne le sera jamais en beau.
3. **Sauvegarde ton `.rbxl` chaque jour** — un crash sans backup = des jours perdus.
4. **Garde les odds du doc** : l'équilibrage est calibré sur le parcours C1 ; change un seul curseur à la fois.
5. **La règle des 60 secondes :** un nouveau joueur doit avoir cliqué, ouvert un œuf ET compris qu'on peut voler en 60 secondes. Si ce n'est pas le cas, simplifie l'onboarding, pas le jeu.
