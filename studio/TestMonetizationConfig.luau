--!nonstrict
--[[ TestMonetizationConfig
     Rôle    : vérifier les 9 produits de C6 dans MonetizationConfig, leurs effets, la roulette et les règles d'or
               C6 / E11.3.
     Doc     : GAME_MASTER_V2 C6, E11.3, A5, C4 ; PROMPT_EXECUTION_SABL_V4 §31.11 lot A, §24 ; Q1-Q6 de l'étape 11
     Étape   : 11, lot A
     Dépend  : ReplicatedStorage.Config.MonetizationConfig, UpgradeConfig, CreatureConfig, EventConfig
     Exposé  : exécution manuelle ; aucune écriture de données, aucun achat
     Limite  : ne prouve que la configuration. Les identifiants réels (handoff H-4) ne sont pas exigés : le test
               vérifie leur cohérence et indique combien restent à coller.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local M = require(assert(config:FindFirstChild("MonetizationConfig"), "MonetizationConfig absent"))
local U = require(assert(config:FindFirstChild("UpgradeConfig"), "UpgradeConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local Ev = require(assert(config:FindFirstChild("EventConfig"), "EventConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Référence C6 et Q1-Q3 de l'étape 11, recopiée ici : jamais déduite de la configuration testée.
local expected = {
    VIP = {Kind = "Gamepass", Price = 199, IncomeBonus = 0.5, GoldTag = true, VipZone = true},
    Luck2x = {Kind = "Gamepass", Price = 149, LuckMult = 2},
    Speed2x = {Kind = "Gamepass", Price = 99, SpeedMult = 2},
    AutoCollect = {Kind = "Gamepass", Price = 249, VaultIncomeShare = 1},
    ExtraSlots = {Kind = "Gamepass", Price = 199, ExtraSlots = 5},
    Gladiator = {Kind = "Gamepass", Price = 179, ArenaTokenBonus = 0.25, VictoryEmote = true},
    EmergencyShield = {Kind = "Product", Price = 49, EmergencyShields = 1},
    StarterPack = {Kind = "Product", Price = 99, Money = 10000, Rarity = "Rare", EmergencyShields = 1, Once = true},
    Spins1 = {Kind = "Product", Price = 25, Spins = 1},
    Spins10 = {Kind = "Product", Price = 199, Spins = 10},
    Spins25 = {Kind = "Product", Price = 499, Spins = 25},
}
local IDENTITY = {Key = true, Name = true, Id = true}
local function sameEffects(item, wanted)
    for key, value in pairs(wanted) do
        if key ~= "Kind" and item[key] ~= value then return false end
    end
    for key in pairs(item) do
        if not IDENTITY[key] and wanted[key] == nil then return false end
    end
    return true
end

check("6 passes et 5 produits (9 produits C6, spins en 3 paquets)", #M.Gamepasses == 6 and #M.Products == 5)
local kinds = {Gamepass = M.Gamepasses, Product = M.Products}
local seen = 0
for kind, list in pairs(kinds) do
    for _, item in ipairs(list) do
        local wanted = expected[item.Key]
        seen += 1
        check(("%s : %s, prix et effets exacts"):format(item.Key, kind),
            wanted ~= nil and wanted.Kind == kind and sameEffects(item, wanted)
            and type(item.Name) == "string" and #item.Name > 0 and M.Get(item.Key) == item)
    end
end
check("Aucun produit attendu ne manque", seen == 11)

-- Règles d'or C6 et E11.3.
local COMBAT = {"ATK", "HP", "Attack", "Damage", "Health", "PvpMult", "CombatMult", "StatMult", "TierMult"}
local noCombat, noSecret, rarities = true, true, true
for _, list in pairs(kinds) do
    for _, item in ipairs(list) do
        for _, key in ipairs(COMBAT) do noCombat = noCombat and item[key] == nil end
        noSecret = noSecret and item.Rarity ~= "Secret"
        rarities = rarities and (item.Rarity == nil or C:GetRarity(item.Rarity) ~= nil)
    end
end
check("Aucun produit ne touche aux stats de combat (E11.3)", noCombat)
check("Aucun produit ne donne de Secret (C6)", noSecret)
check("Raretés offertes connues de CreatureConfig", rarities)
local gladiatorKeys = true
for key in pairs(M.Get("Gladiator")) do
    gladiatorKeys = gladiatorKeys and (IDENTITY[key] or key == "Price" or key == "ArenaTokenBonus"
        or key == "VictoryEmote")
end
check("Passe Gladiateur : tokens et emote seulement", gladiatorKeys)
check("Spins dans la fourchette 25-499 R$ de C6", M.Get("Spins1").Price == 25 and M.Get("Spins25").Price == 499
    and M.Get("Spins10").Price > 25 and M.Get("Spins10").Price < 499)
check("Bouclier d'urgence : 3 min", M.EmergencyShieldSeconds == 180)

-- Q1 et Q2 contre les configurations existantes.
check("Q1 : Auto-collect 100 % contre 50 % sans le passe", U.VaultIncomeShare == 0.5
    and M.Get("AutoCollect").VaultIncomeShare == 1)
local slots
for _, component in ipairs(U.Components) do
    if component.Key == "Slots" then slots = component end
end
check("Q2 : 25 piédestaux au maximum + 5 = 30", slots ~= nil and slots.Max == 25
    and slots.Max + M.Get("ExtraSlots").ExtraSlots == 30)

-- Identifiants : 0 tant que H-4 n'est pas fait, jamais pris pour un achat ; sinon uniques et retrouvés.
local idsValid, unique, found, missing, allSet = true, true, true, 0, true
for kind, list in pairs(kinds) do
    local ids = {}
    for _, item in ipairs(list) do
        idsValid = idsValid and type(item.Id) == "number" and item.Id >= 0 and item.Id % 1 == 0
        if item.Id > 0 then
            unique = unique and not ids[item.Id]
            ids[item.Id] = true
            found = found and M.GetByRobloxId(kind, item.Id) == item
        else
            missing += 1
            allSet = false
        end
    end
end
check("Identifiants entiers ≥ 0", idsValid)
check("Identifiants renseignés uniques et retrouvés", unique and found)
check("IsConfigured() suit les identifiants", M.IsConfigured() == allSet)
check("Un identifiant à 0, négatif ou d'un autre type ne donne aucun produit", M.GetByRobloxId("Gamepass", 0) == nil
    and M.GetByRobloxId("Product", 0) == nil and M.GetByRobloxId("Product", -5) == nil
    and M.GetByRobloxId("Badge", 1) == nil and M.GetByRobloxId("Product", "1") == nil)
check("Get : clé inconnue → nil", M.Get("Secret") == nil and M.Get(nil) == nil and M.Get(3) == nil)
check("Configuration gelée", table.isfrozen(M.Gamepasses) and table.isfrozen(M.Products)
    and table.isfrozen(M.Get("VIP")))
-- Roulette : Q4 (boosts et boucliers seulement), Q5 (durées additionnées), Q6 (multiplications).
local wheel = {
    {Key = "Income10", Boost = "Income", Seconds = 600, Weight = 35},
    {Key = "Luck10", Boost = "Luck", Seconds = 600, Weight = 25},
    {Key = "Shield", EmergencyShields = 1, Weight = 15},
    {Key = "Income30", Boost = "Income", Seconds = 1800, Weight = 15},
    {Key = "Luck30", Boost = "Luck", Seconds = 1800, Weight = 8},
    {Key = "Income120", Boost = "Income", Seconds = 7200, Weight = 2},
}
local wheelExact = #M.Roulette == #wheel
for index, wanted in ipairs(wheel) do
    local slot = M.Roulette[index]
    wheelExact = wheelExact and slot ~= nil
    if slot then
        for key, value in pairs(wanted) do wheelExact = wheelExact and slot[key] == value end
        for key in pairs(slot) do wheelExact = wheelExact and wanted[key] ~= nil end
    end
end
check("Roulette : 6 lots exacts (Q4)", wheelExact)
local weightSum, onePrize, wheelSafe = 0, true, true
for _, slot in ipairs(M.Roulette) do
    weightSum += slot.Weight
    local prizes = (slot.Boost ~= nil and 1 or 0) + (slot.EmergencyShields ~= nil and 1 or 0)
    onePrize = onePrize and prizes == 1 and (slot.Boost == nil or (M.Boosts[slot.Boost] ~= nil and slot.Seconds > 0))
    wheelSafe = wheelSafe and slot.Rarity == nil and slot.Egg == nil and slot.Money == nil
    for _, key in ipairs(COMBAT) do wheelSafe = wheelSafe and slot[key] == nil end
end
check("Roulette : chances affichables, somme = 100 (§24)", weightSum == 100)
check("Roulette : un seul lot par case, boost connu", onePrize)
check("Roulette : ni Secret, ni créature, ni œuf, ni stat de combat (C6)", wheelSafe)
check("Boosts : revenus ×2 et chance ×2", M.Boosts.Income.Mult == 2 and M.Boosts.Luck.Mult == 2)
check("Q5 : boost neuf → maintenant + durée", M.ExtendBoost(nil, 1000, 600) == 1600
    and M.ExtendBoost(0, 1000, 600) == 1600 and M.ExtendBoost("x", 1000, 600) == 1600)
check("Q5 : boost expiré → repart de maintenant", M.ExtendBoost(900, 1000, 600) == 1600
    and M.ExtendBoost(1000, 1000, 600) == 1600)
check("Q5 : boost actif → les durées s'additionnent", M.ExtendBoost(1300, 1000, 1800) == 3100)
check("BoostMultiplier : ×2 actif, ×1 à la fin pile, absent ou inconnu",
    M.BoostMultiplier("Income", 1600, 1000) == 2 and M.BoostMultiplier("Luck", 1001, 1000) == 2
    and M.BoostMultiplier("Income", 1000, 1000) == 1 and M.BoostMultiplier("Luck", nil, 1000) == 1
    and M.BoostMultiplier("ATK", 9999, 1000) == 1 and M.BoostMultiplier(nil, 9999, 1000) == 1
    and M.BoostMultiplier("Income", 0 / 0, 1000) == 1)
check("Q5 : deux boosts de revenus restent ×2", M.BoostMultiplier("Income", M.ExtendBoost(1600, 1000, 600), 1000) == 2)
check("Q6 : boost revenus × Confettis = ×4", M.BoostMultiplier("Income", 1600, 1000) * Ev.Confetti.IncomeMult == 4)

table.insert(T.lines, ("[INFO] identifiants à coller (H-4) : %d sur 11"):format(missing))

local summary = ("[MONETIZATION CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
