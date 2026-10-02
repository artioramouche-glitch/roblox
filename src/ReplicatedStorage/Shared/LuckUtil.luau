--!strict
--[[ LuckUtil
     Rôle    : odds d'un œuf sous un multiplicateur de chance, partagées pour que le tirage et l'affichage concordent.
     Doc     : GAME_MASTER_V2 B2 (odds), C4 (Frénésie, Week-end Chance), C3 (+10 % chance) ; décision 59 ;
               PROMPT_EXECUTION_SABL_V4 §24 (probabilités affichées)
     Étape   : 10, lot C (calcul seul, branché dans EggService et la boutique en session locale)
     Dépend  : Config.CreatureConfig (ordre des raretés), Config.EventConfig (plafond)
     Exposé  : Apply(odds, multiplier) → nouvelle table d'odds (somme inchangée) ; Rarest(odds)
     Limite  : utilitaire de calcul, sans autorité (Loi 2) : le serveur tire avec ces odds, le client affiche les
               mêmes. La table reçue n'est jamais modifiée. Module absent de G1, comme EconomyUtil ; écart déclaré.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local config = ReplicatedStorage:WaitForChild("Config")
local CreatureConfig = require(config:WaitForChild("CreatureConfig"))
local EventConfig = require(config:WaitForChild("EventConfig"))

local LuckUtil = {}

-- Palier le plus rare présent dans l'œuf (poids > 0), dans l'ordre de CreatureConfig.Rarities.
function LuckUtil.Rarest(odds: {[string]: number}): string?
    local rarest = nil
    for _, rarity in ipairs(CreatureConfig.Rarities) do
        local weight = odds[rarity.Id]
        if type(weight) == "number" and weight > 0 then rarest = rarity.Id end
    end
    return rarest
end

-- Décision 59 : seul le palier le plus rare est multiplié, sans dépasser LuckCap (ni descendre) ; les autres
-- paliers se partagent le reste au prorata de leurs poids. Un multiplicateur ≤ 1 ou invalide ne change rien.
function LuckUtil.Apply(odds: {[string]: number}, multiplier: any): {[string]: number}
    local result: {[string]: number} = {}
    local total = 0
    for rarity, weight in pairs(odds) do
        result[rarity] = weight
        total += weight
    end
    local rarest = LuckUtil.Rarest(odds)
    if type(multiplier) ~= "number" or not (multiplier > 1) or not rarest then return result end
    local before = odds[rarest]
    local rest = total - before
    if rest <= 0 then return result end
    local after = math.max(before, math.min(before * multiplier, EventConfig.LuckCap))
    local scale = (total - after) / rest
    for rarity, weight in pairs(odds) do
        result[rarity] = if rarity == rarest then after else weight * scale
    end
    return result
end

return table.freeze(LuckUtil)
