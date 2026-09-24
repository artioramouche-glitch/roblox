--!strict
--[[ EconomyUtil
     Rôle    : formules de revenu et de vente, partagées pour éviter toute divergence.
     Doc     : GAME_MASTER_V2 B1 (revenus), B3 (tiers), C2 (multiplicateurs), G4 (vente)
     Étape   : 4, lot A ; générateur et décos (C2) à l'étape 9, lot B ; ×2 lu dans RebirthConfig au lot C
     Dépend  : Config.CreatureConfig, Config.UpgradeConfig, Config.RebirthConfig
     Exposé  : GetTierMultiplier, GetCreatureIncome, GetSellPrice, GetGlobalMultiplier,
               GetTotalIncome
     Limite  : utilitaire de calcul, sans autorité. Seul le serveur crédite ou débite ;
               le client s'en sert uniquement pour afficher les mêmes nombres (Loi 2).
               Les familles de C2 se multiplient entre elles ; à l'intérieur d'une famille
               (les 12 décos), les pourcentages s'additionnent.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local CreatureConfig = require(config:WaitForChild("CreatureConfig"))
local UpgradeConfig = require(config:WaitForChild("UpgradeConfig"))
local RebirthConfig = require(config:WaitForChild("RebirthConfig"))

local SELL_UNITS = 100 -- G4 : « prix = 40 % du revenu × 100 », les 40 % venant de SellMult
local REBIRTH_MULTIPLIER = RebirthConfig.IncomeMultiplier -- C2 et C3 : ×2 par rebirth

local EconomyUtil = {}

-- B3, colonne « Mult revenu » : jamais la colonne PvP (piège §31.4).
function EconomyUtil.GetTierMultiplier(tier: any): number
    local entry = CreatureConfig.Tiers[tier]
    if not entry then return 0 end
    return entry.Mult
end

-- Revenu d'un exemplaire, hors multiplicateurs globaux : B1 × TierMult B3.
function EconomyUtil.GetCreatureIncome(id: any, tier: any): number
    local creature = CreatureConfig:Get(id)
    if not creature then return 0 end
    local multiplier = EconomyUtil.GetTierMultiplier(tier)
    if multiplier == 0 then return 0 end
    return creature.income * multiplier
end

-- G4 + G5.1 : le taux de vente vient de SellMult, qui vaut 0.4 pour un Commun.
function EconomyUtil.GetSellPrice(id: any, tier: any): number
    local creature = CreatureConfig:Get(id)
    if not creature then return 0 end
    local rarity = CreatureConfig:GetRarity(creature.rarity)
    if not rarity then return 0 end
    local income = EconomyUtil.GetCreatureIncome(id, tier)
    if income == 0 then return 0 end
    -- Arrondi au plus proche, jamais vers le bas : les taux 0.45 et 0.55 ne sont pas
    -- représentables en binaire, et math.floor ferait perdre une unité au joueur.
    return math.round(income * SELL_UNITS * rarity.SellMult)
end

-- Nombre de décos possédées : seules les entrées textuelles comptent.
local function decorCount(base: any): number
    if type(base) ~= "table" or type(base.Decor) ~= "table" then return 0 end
    local count = 0
    for _, id in ipairs(base.Decor) do
        if type(id) == "string" then count += 1 end
    end
    return count
end

-- C2 : les multiplicateurs cumulables. Les systèmes absents valent 1 et sont
-- ajoutés ici avec leur étape (VIP 11, confettis 10, clan 15).
function EconomyUtil.GetGlobalMultiplier(profile: any): number
    if type(profile) ~= "table" then return 1 end
    local rebirths = profile.Rebirths
    local multiplier = 1
    if type(rebirths) == "number" and rebirths == rebirths and rebirths >= 0
        and rebirths % 1 == 0 and rebirths <= 64 then
        multiplier = REBIRTH_MULTIPLIER ^ rebirths
    end
    local base = profile.Base
    local generator = type(base) == "table" and base.Generator or 0
    -- Étape 9 : générateur (Q3, jusqu'à +50 %) et décos (+2 % chacune, +24 % au maximum).
    multiplier *= 1 + UpgradeConfig.GeneratorIncomeBonus(generator)
    multiplier *= 1 + UpgradeConfig.DecorIncomeBonus(decorCount(base))
    return multiplier
end

-- Revenu par seconde de la base : seules les créatures posées sur un piédestal produisent.
function EconomyUtil.GetTotalIncome(profile: any): number
    if type(profile) ~= "table" or type(profile.Creatures) ~= "table" then return 0 end
    local sum = 0
    for _, creature in ipairs(profile.Creatures) do
        if type(creature) == "table" and creature.PlacedSlot ~= nil then
            sum += EconomyUtil.GetCreatureIncome(creature.Id, creature.Tier)
        end
    end
    return math.floor(sum * EconomyUtil.GetGlobalMultiplier(profile))
end

return EconomyUtil
