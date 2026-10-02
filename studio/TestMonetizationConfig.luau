--!nonstrict
--[[ TestMonetizationConfig
     Rôle    : vérifier les 9 produits de C6 dans MonetizationConfig, leurs effets et les règles d'or C6 / E11.3.
     Doc     : GAME_MASTER_V2 C6, E11.3, A5 ; PROMPT_EXECUTION_SABL_V4 §31.11 lot A ; Q1-Q3 de l'étape 11
     Étape   : 11, lot A
     Dépend  : ReplicatedStorage.Config.MonetizationConfig, UpgradeConfig, CreatureConfig
     Exposé  : exécution manuelle ; aucune écriture de données, aucun achat
     Limite  : ne prouve que la configuration. Les identifiants réels (handoff H-4) ne sont pas exigés : le test
               vérifie leur cohérence et indique combien restent à coller.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local M = require(assert(config:FindFirstChild("MonetizationConfig"), "MonetizationConfig absent"))
local U = require(assert(config:FindFirstChild("UpgradeConfig"), "UpgradeConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
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
table.insert(T.lines, ("[INFO] identifiants à coller (H-4) : %d sur 11"):format(missing))

local summary = ("[MONETIZATION CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
