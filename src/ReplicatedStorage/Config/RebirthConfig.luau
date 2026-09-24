--!strict
--[[ RebirthConfig
     Rôle    : les paliers de rebirth C3 : coût, mondes débloqués, récompenses, multiplicateur de revenu.
     Doc     : GAME_MASTER_V2 C3, C2 ; PROMPT_EXECUTION_SABL_V4 §31.9 lot C ; décisions 32, 35 et 36
     Étape   : 9, lot C
     Dépend  : aucun
     Exposé  : configuration immuable ; IncomeMultiplier, Get(rebirth) -> palier, CostOf(rebirth),
               WorldFor(rebirths), LuckBonus(rebirths)
     Limite  : R6 à R9 intercalés géométriquement entre R5 et R10, puis ×50 par palier au-delà de R10
               (décision 35). « +10 % chance » est enregistré ici, appliqué aux œufs avec la chance des
               événements (étape 10) ; l'aura dorée de R10 et les titres de R15+ viendront avec leurs
               systèmes cosmétiques (décision 36).
]]
local RebirthConfig = {}

RebirthConfig.IncomeMultiplier = 2 -- C2 et C3 : ×2 par rebirth, cumulable avec tout C2

-- C3 : chaque palier coûte le seuil d'argent à atteindre ; l'argent repart ensuite de 0 (Q1).
RebirthConfig.Tiers = table.freeze({
    table.freeze({Rebirth = 1, Cost = 1e6, Luck = 0.10}),
    table.freeze({Rebirth = 2, Cost = 50e6, ArenaTokens = 500}),
    table.freeze({Rebirth = 3, Cost = 2.5e9, World = 2}),
    table.freeze({Rebirth = 4, Cost = 100e9, ArenaTokens = 2000}),
    table.freeze({Rebirth = 5, Cost = 500e9, World = 3}),
    table.freeze({Rebirth = 6, Cost = 1.44e12}), -- décision 35 : ×2,885 par palier entre R5 et R10
    table.freeze({Rebirth = 7, Cost = 4.16e12}),
    table.freeze({Rebirth = 8, Cost = 12.0e12}),
    table.freeze({Rebirth = 9, Cost = 34.7e12}),
    table.freeze({Rebirth = 10, Cost = 100e12, World = 4, Aura = true}),
})
RebirthConfig.BeyondMultiplier = 50 -- C3 : « 15+ : ×50 à chaque palier », appliqué dès R11 (décision 35)

local LAST = RebirthConfig.Tiers[#RebirthConfig.Tiers]

local function isRebirth(value: any): boolean
    return type(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value < math.huge
end

-- Palier du rebirth numéro `rebirth` ; au-delà du dernier palier écrit, seul le coût progresse.
function RebirthConfig.Get(rebirth: any): any
    if not isRebirth(rebirth) then return nil end
    return RebirthConfig.Tiers[rebirth] or {Rebirth = rebirth, Cost = RebirthConfig.CostOf(rebirth)}
end

function RebirthConfig.CostOf(rebirth: any): number?
    if not isRebirth(rebirth) then return nil end
    local tier = RebirthConfig.Tiers[rebirth]
    if tier then return tier.Cost end
    return LAST.Cost * RebirthConfig.BeyondMultiplier ^ (rebirth - LAST.Rebirth)
end

-- Monde le plus avancé débloqué après `rebirths` rebirths (le monde 1 est toujours ouvert).
function RebirthConfig.WorldFor(rebirths: any): number
    local world = 1
    for _, tier in ipairs(RebirthConfig.Tiers) do
        if type(rebirths) == "number" and tier.Rebirth <= rebirths and tier.World then
            world = math.max(world, tier.World)
        end
    end
    return world
end

-- C3 : bonus de chance cumulé des paliers atteints (appliqué aux œufs à l'étape 10).
function RebirthConfig.LuckBonus(rebirths: any): number
    local bonus = 0
    for _, tier in ipairs(RebirthConfig.Tiers) do
        if type(rebirths) == "number" and tier.Rebirth <= rebirths and tier.Luck then bonus += tier.Luck end
    end
    return bonus
end

return table.freeze(RebirthConfig)
