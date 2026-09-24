--!strict
--[[ CombatUtil
     Rôle    : stats PvP d'un brainrot possédé, anneau d'entraînement compris, partagées pour éviter toute divergence.
     Doc     : GAME_MASTER_V2 B4 (stats de combat), A5 (anneau d'entraînement), E11 ; PROMPT_EXECUTION_SABL_V4 §31.9
     Étape   : 9, lot D
     Dépend  : Config.CreatureConfig, Config.UpgradeConfig
     Exposé  : TrainingPercent(profile) -> 0 à 10, GetCreatureStats(creature, profile, ranked) -> {HP, ATK, Type, Training}
     Limite  : utilitaire de calcul, sans autorité : le combat de l'étape 13 le lira côté serveur, l'inventaire
               l'affiche. Seul un brainrot posé sur un socle profite de l'anneau (A5), la Réserve d'or jamais ;
               anneau à 0, les stats sont exactement celles de CreatureConfig:GetCombatStats (G5.1).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local CreatureConfig = require(config:WaitForChild("CreatureConfig"))
local UpgradeConfig = require(config:WaitForChild("UpgradeConfig"))

local PERCENT = 100

local CombatUtil = {}

-- A5 : +2 % par niveau d'anneau, compté en points entiers (0 à 10) pour ne pas cumuler d'arrondi binaire.
function CombatUtil.TrainingPercent(profile: any): number
    local base = type(profile) == "table" and profile.Base
    local level = if type(base) == "table" then base.TrainingRing else 0
    return math.round((UpgradeConfig.TrainingMultiplier(level) - 1) * PERCENT)
end

-- B4 puis l'anneau : stat × (100 + points) / 100, arrondi vers le bas comme G5.1, calcul exact sur des entiers.
function CombatUtil.GetCreatureStats(creature: any, profile: any, ranked: boolean?): any
    if type(creature) ~= "table" then return nil end
    local stats = CreatureConfig:GetCombatStats(creature.Id, creature.Tier, ranked == true)
    if not stats then return nil end
    local placed = creature.PlacedSlot ~= nil and not creature.Reserve
    local training = if placed then CombatUtil.TrainingPercent(profile) else 0
    return {
        HP = math.floor(stats.HP * (PERCENT + training) / PERCENT),
        ATK = math.floor(stats.ATK * (PERCENT + training) / PERCENT),
        Type = stats.Type,
        Training = training,
    }
end

return table.freeze(CombatUtil)
