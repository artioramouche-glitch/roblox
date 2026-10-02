--!strict
--[[ WorldConfig
     Rôle    : chiffres des mécaniques propres aux mondes 2 à 4 (rivière, chantilly, cascade, forêt, douche ; courant,
               bulles, grotte, faille ; gravité faible, tapis, astéroïdes, navette).
     Doc     : GAME_MASTER_V2 D2, D3, D4 ; PROMPT_EXECUTION_SABL_V4 §31.16 ; Q1-Q3 de l'étape 16 (02/10 : A, A, A) et
               lectures déclarées (forêt, douche, faille, grotte)
     Étape   : 16 (configuration seule)
     Dépend  : Shared/SlotRandom (heure de la douche, arbre de la forêt, astéroïdes à cache)
     Exposé  : configuration immuable ; Dessert, Abyss, Candy ; RiverSpeedMult(carrying), JumpHeightRatio(jumpMult,
               gravityScale), ShowerAt(now), ForestTree(now), AsteroidCaches(now)
     Limite  : module absent de G1, comme EconomyConfig ; écart déclaré. Les mondes, leurs œufs, leurs créatures,
               leur multiplicateur (B4) et le rebirth qui les ouvre (C3) restent dans CreatureConfig, EggConfig et
               RebirthConfig. La grotte dépend du combat (étape 13). Hasard fixé par heure (SlotRandom) : le même
               arbre et les mêmes astéroïdes sur tous les serveurs.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SlotRandom = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SlotRandom"))

local WorldConfig = {}

local HOUR = 3600

-- MONDE 2 — DESSERT KINGDOM (D2).
WorldConfig.Dessert = table.freeze({
    -- D2.3 : traverser = −30 % de vitesse pendant 3 s ; Q1 (option A) : seulement un voleur qui porte un brainrot.
    River = table.freeze({SpeedMult = 0.70, Seconds = 3, ThievesOnly = true, Width = 25, Bridges = 3}),
    -- D2.3 : 8 dômes, sauts +30 % de hauteur.
    Chantilly = table.freeze({Domes = 8, JumpHeightMult = 1.30}),
    -- D2.2 : +10 % de revenus tant qu'on y reste, 2 min au plus, puis 10 min d'attente.
    Cascade = table.freeze({Radius = 15, IncomeBonus = 0.10, MaxSeconds = 2 * 60, CooldownSeconds = 10 * 60}),
    -- D2.2 (lu) : chaque heure, un des 12 arbres cache un egg_dessert pour le premier qui le trouve sur le serveur.
    Forest = table.freeze({Trees = 12, Period = HOUR, Egg = "egg_dessert"}),
    -- D2.2 (lu) : une fois par heure, à une minute tirée comme les Confettis, 30 s de clics ×5.
    Shower = table.freeze({Period = HOUR, Duration = 30, ClickMult = 5}),
})

-- MONDE 3 — SUSHI ABYSS (D3).
WorldConfig.Abyss = table.freeze({
    -- D3.3 : couloir est → ouest, large de 30, pousse de 12 studs/s.
    Current = table.freeze({Push = 12, Width = 30, Direction = "West"}),
    -- D3.3 : 4 colonnes r = 3, hautes de 40, montée à 20 studs/s.
    BubbleColumns = table.freeze({Count = 4, Radius = 3, Height = 40, Speed = 20}),
    -- D3.2 / D3.3 : mini-donjon 30 × 30 en solo, 10 vagues, 1 egg_abyss, 1 h d'attente.
    Cave = table.freeze({Size = 30, Solo = true, Waves = 10, Egg = "egg_abyss", Cooldown = HOUR}),
    -- D3.2 / D3.3 (lu) : courant ×2 (24 studs/s), 2 plots premium à +5 % de revenus.
    Rift = table.freeze({CurrentMult = 2, PremiumPlots = 2, PremiumIncomeBonus = 0.05}),
})

-- MONDE 4 — CANDY SPACE (D4).
WorldConfig.Candy = table.freeze({
    -- D4.3 / Q2 (option A) : 6 bulles r = 15 ; sauts ×2 en hauteur par la gravité divisée par 2, saut inchangé.
    LowGravity = table.freeze({Zones = 6, Radius = 15, JumpHeightMult = 2, GravityScale = 0.5, JumpPowerMult = 1}),
    -- D4.3 : 4 boucles larges de 20, +8 studs/s.
    Conveyors = table.freeze({Loops = 4, Width = 20, Speed = 8}),
    -- D4.2 / D4.3 / Q3 (option A) : 20 astéroïdes à r = 200 ; 3 caches par heure, obby de 60 s, 20 tokens arène,
    -- chaque joueur une fois par cache et par heure.
    Asteroids = table.freeze({Count = 20, Ring = 200, CachesPerHour = 3, ObbySeconds = 60, ArenaTokens = 20,
        Period = HOUR, OncePerPlayerPerCache = true}),
    -- D4.1 : navette cosmétique, un tour toutes les 5 min.
    ShuttlePeriod = 5 * 60,
})

-- Q1 : multiplicateur de vitesse dans la rivière de chocolat (seul un voleur qui porte est ralenti).
function WorldConfig.RiverSpeedMult(carrying: boolean): number
    return if carrying then WorldConfig.Dessert.River.SpeedMult else 1
end

-- Hauteur d'un saut relative à la normale : (multiplicateur du saut)² ÷ (échelle de gravité), puisque h = v² / 2g.
function WorldConfig.JumpHeightRatio(jumpMult: number, gravityScale: number): number
    return jumpMult * jumpMult / gravityScale
end

-- Douche de pépites en cours ou prochaine : active ?, début, fin.
function WorldConfig.ShowerAt(now: number): (boolean, number, number)
    local shower = WorldConfig.Dessert.Shower
    return SlotRandom.Window(now, shower.Period, shower.Duration)
end

-- Arbre (1 à 12) qui cache l'œuf pendant l'heure en cours.
function WorldConfig.ForestTree(now: number): number
    local forest = WorldConfig.Dessert.Forest
    return SlotRandom.Pick(math.floor(now / forest.Period), 1, forest.Trees)[1]
end

-- Les 3 astéroïdes (numéros de 1 à 20, distincts) qui cachent un mini-portail pendant l'heure en cours. Les tranches
-- sont décalées pour que le tirage ne suive pas celui de l'arbre de la forêt sur la même heure.
local ASTEROID_SLOT_OFFSET = 1000003
function WorldConfig.AsteroidCaches(now: number): {number}
    local a = WorldConfig.Candy.Asteroids
    return SlotRandom.Pick(math.floor(now / a.Period) + ASTEROID_SLOT_OFFSET, a.CachesPerHour, a.Count)
end

return table.freeze(WorldConfig)
