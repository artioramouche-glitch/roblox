--!nonstrict
--[[ TestWorldConfig
     Rôle    : vérifier WorldConfig (mécaniques des mondes 2 à 4), Shared/SlotRandom, et leur cohérence avec les
               mondes déjà configurés (œufs, rebirths, multiplicateurs).
     Doc     : GAME_MASTER_V2 D2, D3, D4, B2, B4, C3 ; PROMPT_EXECUTION_SABL_V4 §31.16 ; Q1-Q3 de l'étape 16
     Étape   : 16 (configuration)
     Dépend  : ReplicatedStorage.Config.WorldConfig, EggConfig, RebirthConfig, CreatureConfig ;
               ReplicatedStorage.Shared.SlotRandom
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; les poussées, la gravité et les zones se testent en Play sur les
               maps des mondes 2 à 4.
]]
local RS = game:GetService("ReplicatedStorage")
local config = assert(RS:FindFirstChild("Config"), "Config absent")
local shared = assert(RS:FindFirstChild("Shared"), "Shared absent")
local W = require(assert(config:FindFirstChild("WorldConfig"), "WorldConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local R = require(assert(config:FindFirstChild("RebirthConfig"), "RebirthConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local Slot = require(assert(shared:FindFirstChild("SlotRandom"), "SlotRandom absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- D2, recopié ici.
local d = W.Dessert
check("D2.3 / Q1 : rivière −30 % pendant 3 s, voleurs seulement, large de 25, 3 ponts", d.River.SpeedMult == 0.70
    and d.River.Seconds == 3 and d.River.ThievesOnly and d.River.Width == 25 and d.River.Bridges == 3)
check("Q1 : un voleur qui porte ×0,7, les autres ×1", W.RiverSpeedMult(true) == 0.70 and W.RiverSpeedMult(false) == 1)
check("D2.3 : 8 dômes de chantilly, sauts +30 %", d.Chantilly.Domes == 8 and d.Chantilly.JumpHeightMult == 1.30)
check("D2.2 : cascade r = 15, +10 %, 2 min au plus, 10 min d'attente", d.Cascade.Radius == 15
    and d.Cascade.IncomeBonus == 0.10 and d.Cascade.MaxSeconds == 120 and d.Cascade.CooldownSeconds == 600)
check("D2.2 : forêt de 12 arbres, un egg_dessert par heure", d.Forest.Trees == 12 and d.Forest.Period == 3600
    and d.Forest.Egg == "egg_dessert")
check("D2.2 : douche 1 fois par heure, 30 s, clics ×5", d.Shower.Period == 3600 and d.Shower.Duration == 30
    and d.Shower.ClickMult == 5)

-- D3, recopié ici.
local a = W.Abyss
check("D3.3 : courant de 12 studs/s vers l'ouest, large de 30", a.Current.Push == 12 and a.Current.Width == 30
    and a.Current.Direction == "West")
check("D3.3 : 4 colonnes r = 3, h = 40, 20 studs/s", a.BubbleColumns.Count == 4 and a.BubbleColumns.Radius == 3
    and a.BubbleColumns.Height == 40 and a.BubbleColumns.Speed == 20)
check("D3 : grotte 30 × 30 en solo, 10 vagues, egg_abyss, 1 h", a.Cave.Size == 30 and a.Cave.Solo
    and a.Cave.Waves == 10 and a.Cave.Egg == "egg_abyss" and a.Cave.Cooldown == 3600)
check("D3 : faille, courant ×2 (24 studs/s), 2 plots premium +5 %", a.Rift.CurrentMult == 2
    and a.Current.Push * a.Rift.CurrentMult == 24 and a.Rift.PremiumPlots == 2 and a.Rift.PremiumIncomeBonus == 0.05)

-- D4, recopié ici.
local c = W.Candy
check("D4.3 / Q2 : 6 bulles r = 15, gravité ×0,5, saut inchangé", c.LowGravity.Zones == 6 and c.LowGravity.Radius == 15
    and c.LowGravity.GravityScale == 0.5 and c.LowGravity.JumpPowerMult == 1 and c.LowGravity.JumpHeightMult == 2)
check("Q2 : la configuration donne bien des sauts ×2",
    W.JumpHeightRatio(c.LowGravity.JumpPowerMult, c.LowGravity.GravityScale) == c.LowGravity.JumpHeightMult)
check("Q2 : la recette « JumpPower ×2 + Gravity 100 » aurait donné ≈ ×7,8",
    math.abs(W.JumpHeightRatio(2, 100 / 196.2) - 7.848) < 0.001)
check("D4.3 : 4 tapis larges de 20, +8 studs/s", c.Conveyors.Loops == 4 and c.Conveyors.Width == 20
    and c.Conveyors.Speed == 8)
check("D4 / Q3 : 20 astéroïdes à r = 200, 3 caches par heure, obby 60 s, 20 tokens, une fois par joueur et cache",
    c.Asteroids.Count == 20 and c.Asteroids.Ring == 200 and c.Asteroids.CachesPerHour == 3
    and c.Asteroids.ObbySeconds == 60 and c.Asteroids.ArenaTokens == 20 and c.Asteroids.OncePerPlayerPerCache)
check("D4.1 : navette toutes les 5 min", c.ShuttlePeriod == 300)

-- Cohérence avec les mondes déjà configurés (B2, B4, C3).
local eggWorlds = E:Get("egg_dessert").world == 2 and E:Get("egg_abyss").world == 3 and E:Get("egg_cosmic").world == 4
check("B2 : œufs de monde dans le bon monde", eggWorlds)
check("C3 : mondes 2, 3, 4 ouverts aux rebirths 3, 5, 10", R.WorldFor(2) == 1 and R.WorldFor(3) == 2
    and R.WorldFor(4) == 2 and R.WorldFor(5) == 3 and R.WorldFor(9) == 3 and R.WorldFor(10) == 4)
check("B4 : multiplicateurs ×2,5, ×6, ×15", C.Worlds[2].Mult == 2.5 and C.Worlds[3].Mult == 6 and C.Worlds[4].Mult == 15)

-- Douche : une par heure, 30 s, à la minute, entière dans son heure (720 heures).
local H = 3600
local base = 1790899200 -- vendredi 2 octobre 2026, 0:00 UTC
local showerOk = true
for hour = 0, 719 do
    local slotStart = base + hour * H
    local _, start, finish = W.ShowerAt(slotStart)
    showerOk = showerOk and start >= slotStart and finish <= slotStart + H and finish - start == 30
        and start % 60 == 0 and (W.ShowerAt(start)) and not (W.ShowerAt(finish))
end
check("Douche : 720 heures, une pluie de 30 s par heure, à la minute", showerOk)

-- Forêt et astéroïdes : fixes dans l'heure, répartis entre les heures.
local trees, forestStable = {}, true
local hits, astStable, astValid, sameAsLast = {}, true, true, 0
local last = nil
for hour = 0, 1999 do
    local t0, t1 = base + hour * H, base + hour * H + H - 1
    local tree = W.ForestTree(t0)
    forestStable = forestStable and tree == W.ForestTree(t1) and tree >= 1 and tree <= 12
    trees[tree] = (trees[tree] or 0) + 1
    local caches, again = W.AsteroidCaches(t0), W.AsteroidCaches(t1)
    local seen = {}
    astValid = astValid and #caches == 3
    for i, k in ipairs(caches) do
        astValid = astValid and k >= 1 and k <= 20 and not seen[k]
        seen[k] = true
        astStable = astStable and again[i] == k
        hits[k] = (hits[k] or 0) + 1
    end
    local key = table.concat(caches, ",")
    if key == last then sameAsLast += 1 end
    last = key
end
local treeMin, treeMax = math.huge, 0
for i = 1, 12 do treeMin, treeMax = math.min(treeMin, trees[i] or 0), math.max(treeMax, trees[i] or 0) end
local astMin, astMax = math.huge, 0
for i = 1, 20 do astMin, astMax = math.min(astMin, hits[i] or 0), math.max(astMax, hits[i] or 0) end
check("Forêt : un arbre de 1 à 12, le même toute l'heure", forestStable)
check(("Forêt : 12 arbres tirés sur 2 000 h (de %d à %d fois, ≈ 167 attendu)"):format(treeMin, treeMax),
    treeMin > 110 and treeMax < 230)
check("Astéroïdes : 3 numéros distincts de 1 à 20, les mêmes toute l'heure", astValid and astStable)
check(("Astéroïdes : répartis sur 2 000 h (de %d à %d fois, ≈ 300 attendu)"):format(astMin, astMax),
    astMin > 220 and astMax < 380)
check(("Astéroïdes : %d heures de suite identiques (hasard ≈ 2)"):format(sameAsLast), sameAsLast < 20)
local all = Slot.Pick(42, 25, 20)
local distinct, seenAll = #all == 20, {}
for _, k in ipairs(all) do distinct = distinct and not seenAll[k]; seenAll[k] = true end
check("SlotRandom.Pick : plus de numéros demandés que possibles → les 20, sans doublon", distinct)

local summary = ("[WORLD CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
