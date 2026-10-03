--!nonstrict
--[[ TestArenaShop
     Rôle    : vérifier la boutique du Colisée : prix débités, livraison unique, refus sans effet, boost, anneau.
     Doc     : GAME_MASTER_V2 E8, A5, C7 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot D (« tokens débités, article livré,
               pas de double livraison ») ; décisions 94, 97, 132
     Étape   : 14, lot D
     Dépend  : ServerScriptService.Arena.ArenaShop, SeasonRules ; ReplicatedStorage.Config (ArenaConfig,
               DefaultProfile)
     Exposé  : exécution manuelle ; écrit seulement dans des copies locales du profil G2
     Limite  : l'ouverture de l'œuf Colisée (EggService) et l'effet du boost sur les revenus se testent en Play.
]]
local arena = assert(game:GetService("ServerScriptService"):FindFirstChild("Arena"), "Arena absent")
local Shop = require(assert(arena:FindFirstChild("ArenaShop"), "ArenaShop absent"))
local Season = require(assert(arena:FindFirstChild("SeasonRules"), "SeasonRules absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local A = require(assert(config:FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local Default = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local NOW = 1790000000
local function rich(tokens)
    local p = copy(Default)
    p.PvP.ArenaTokens = tokens
    return p
end
local function buy(p, key, now)
    local before = p.PvP.ArenaTokens
    local receipt, why = Shop.Buy(p, key, now or NOW)
    return receipt, why, before - p.PvP.ArenaTokens
end

-- E8 : les 11 articles, chacun à son prix.
local p = rich(100000)
local allOk, total = true, 0
for _, item in ipairs(A.Shop) do
    local receipt, why, paid = buy(p, item.Key)
    allOk = allOk and receipt ~= nil and why == nil and paid == item.Price and receipt.Price == item.Price
    total += paid
end
check(("E8 : les 11 articles s'achètent à leur prix (%d tokens au total)"):format(total), allOk and total == 5150
    and p.PvP.ArenaTokens == 100000 - 5150)

-- Livraisons.
p = rich(1000)
local egg, _, paidEgg = buy(p, "EggColisee")
check("Œuf Colisée : 500 tokens, œuf egg_golden à ouvrir par EggService (décision 94)", paidEgg == 500
    and egg.Egg == "egg_golden" and p.PvP.ArenaTokens == 500)
p = rich(5000)
local _, _, paidSkin = buy(p, "SkinChampion")
local beforeTwice = copy(p)
local again, whyAgain = buy(p, "SkinChampion")
check("Cosmétique : livré une fois ; 2e achat refusé (ALREADY_OWNED) sans débit ni changement", paidSkin == 1200
    and p.PvP.Cosmetics.SkinChampion == true and again == nil and whyAgain == "ALREADY_OWNED" and same(p, beforeTwice))
buy(p, "TrailFire")
buy(p, "PoseDance2")
check("Trails et poses : possédés chacun à part", p.PvP.Cosmetics.TrailFire and p.PvP.Cosmetics.PoseDance2
    and not p.PvP.Cosmetics.TrailGalaxy)
local hadB = p.PvP.Loadouts.B
local _, _, paidB = buy(p, "LoadoutB")
local _, whyB = buy(p, "LoadoutB")
check("2e loadout : l'équipe B naît vide (800) ; un seul achat", hadB == nil and paidB == 800
    and type(p.PvP.Loadouts.B) == "table" and #p.PvP.Loadouts.B == 0 and whyB == "ALREADY_OWNED")

-- Décision 97 : boost +20 % pendant 30 min, prolongé par un rachat.
p = rich(1000)
local before = Shop.IncomeMultiplier(p, NOW)
buy(p, "IncomeBoost", NOW)
local first = p.Boosts.ShopIncome
buy(p, "IncomeBoost", NOW + 600)
check("Boost : ×1,2 pendant 30 min ; un rachat ajoute 30 min au reste", before == 1 and first == NOW + 1800
    and p.Boosts.ShopIncome == NOW + 3600 and Shop.IncomeMultiplier(p, NOW + 3599) == 1.2
    and Shop.IncomeMultiplier(p, NOW + 3600) == 1)
buy(p, "IncomeBoost", NOW + 10000)
check("Boost expiré puis racheté : repart de l'achat", p.Boosts.ShopIncome == NOW + 11800)

-- E8 / A5 : anneau d'entraînement jusqu'au niveau 3 par la boutique.
p = rich(5000)
local levels = {}
for _ = 1, 4 do
    local _, why = buy(p, "TrainingRing")
    table.insert(levels, why or tostring(p.Base.TrainingRing))
end
check("Anneau : 1, 2, 3, puis MAX_LEVEL sans débit", table.concat(levels, ",") == "1,2,3,MAX_LEVEL"
    and p.PvP.ArenaTokens == 5000 - 3 * 600)
p = rich(5000)
p.Base.TrainingRing = 4
local _, whyRing = buy(p, "TrainingRing")
check("Anneau déjà au niveau 4 (écran de base) : MAX_LEVEL", whyRing == "MAX_LEVEL" and p.Base.TrainingRing == 4)

-- Refus sans effet.
p = rich(499)
local snapshot = copy(p)
local poor, whyPoor = buy(p, "EggColisee")
check("499 tokens pour 500 : NOT_ENOUGH_TOKENS, profil intact", poor == nil and whyPoor == "NOT_ENOUGH_TOKENS"
    and same(p, snapshot))
local unknown = true
for _, key in ipairs({"Boss", "", 12, false}) do
    local receipt, why = Shop.Buy(rich(9999), key, NOW)
    unknown = unknown and receipt == nil and why == "UNKNOWN_ITEM"
end
local _, whyNil = Shop.Buy(rich(9999), nil, NOW)
local _, whyBad = Shop.Buy({}, "EggColisee", NOW)
check("Article inconnu (UNKNOWN_ITEM) ; profil invalide (BAD_INPUT)", unknown and whyNil == "UNKNOWN_ITEM"
    and whyBad == "BAD_INPUT")

-- Le skin gagné en saison (top 1) n'est pas revendu.
p = rich(5000)
p.PvP.Elo1v1 = 2100
p.PvP.Season = {Id = 2026 * 12 + 8, PeakElo = 2150, Wins = 30, Losses = 3, UltimatesUsed = 0, BestRank = 8}
Season.Apply(p, Season.Close(p, 1790805600 + 86400, true))
local _, whySeason = buy(p, "SkinChampion")
check("Skin Champion gagné en saison : ALREADY_OWNED en boutique", whySeason == "ALREADY_OWNED"
    and p.PvP.ArenaTokens == 5000)

local summary = ("[ARENA SHOP TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
