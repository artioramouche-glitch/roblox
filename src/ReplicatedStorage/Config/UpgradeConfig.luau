--!strict
--[[ UpgradeConfig
     Rôle    : les composants de base A5 (niveaux, prix, disponibilité) et les bonus qu'ils donnent (C2).
     Doc     : GAME_MASTER_V2 A5, C2, G2 (Base) ; PROMPT_EXECUTION_SABL_V4 §31.9 lots A et D ;
               Q2 et Q3 de l'étape 9 tranchées par le Producer (option A)
     Étape   : 9, lot A ; Coffre-fort achetable au lot F1 (décision 44) ; Tourelle et Piège au lot F2 ;
               Alarme au lot F3
     Dépend  : aucun
     Exposé  : configuration immuable ; Components (ordre d'affichage), Decor, Get(key), NextPrice(key, level),
               GeneratorIncomeBonus(level), DecorIncomeBonus(count), TrainingMultiplier(level),
               VaultIncomeShare, VaultCapacitySeconds(level)
     Limite  : Q2, option A : les montants écrits dans A5 font foi, pas l'étiquette « courbe ×4 » ; entre eux,
               progression géométrique arrondie à 3 chiffres significatifs. Un composant n'est achetable
               (Available) que si son effet existe : tous le sont depuis le lot F3.
]]
local UpgradeConfig = {}

-- A5 : un composant va de Start à Max ; Prices[n] est le prix du niveau Start + n.
UpgradeConfig.Components = table.freeze({
    table.freeze({Key = "Slots", Label = "Piédestaux", Start = 3, Max = 25, Available = true,
        -- 5K (4e slot) → 50M (25e), ×1,55 par slot
        Prices = table.freeze({5000, 7750, 12000, 18600, 28900, 44800, 69500, 108000, 167000, 259000, 402000,
            623000, 965000, 1500000, 2320000, 3600000, 5580000, 8650000, 13400000, 20800000, 32200000, 50000000})}),
    table.freeze({Key = "Generator", Label = "Générateur de bouclier", Start = 0, Max = 3, Available = true,
        Prices = table.freeze({50000, 5000000, 500000000})}),
    table.freeze({Key = "Alarm", Label = "Alarme", Start = 0, Max = 3, Available = true,
        Prices = table.freeze({25000, 2000000, 200000000})}),
    table.freeze({Key = "Turret", Label = "Tourelle", Start = 0, Max = 5, Available = true,
        Prices = table.freeze({100000, 562000, 3160000, 17800000, 100000000})}), -- ×5,62 par niveau
    table.freeze({Key = "Trap", Label = "Piège à colle", Start = 0, Max = 3, Available = true,
        Prices = table.freeze({30000, 3000000, 300000000})}),
    table.freeze({Key = "Vault", Label = "Coffre-fort", Start = 0, Max = 5, Available = true,
        Prices = table.freeze({10000, 56200, 316000, 1780000, 10000000})}),
    table.freeze({Key = "TrainingRing", Label = "Anneau d'entraînement", Start = 0, Max = 5, Available = true,
        Prices = table.freeze({250000, 1410000, 7910000, 44500000, 250000000})}),
})

-- A5 : 12 décos, achetées dans l'ordre, de 1K à 1M (×1,87 par objet) ; noms déclarés, le doc n'en donne pas.
UpgradeConfig.Decor = table.freeze({
    Key = "Decor", Label = "Décos", Available = true,
    Items = table.freeze({
        table.freeze({Id = "pot_fleurs", Label = "Pot de fleurs", Price = 1000}),
        table.freeze({Id = "parasol", Label = "Parasol", Price = 1870}),
        table.freeze({Id = "nain", Label = "Nain de jardin", Price = 3510}),
        table.freeze({Id = "borne_incendie", Label = "Borne d'incendie", Price = 6580}),
        table.freeze({Id = "distributeur", Label = "Distributeur de soda", Price = 12300}),
        table.freeze({Id = "palmier", Label = "Palmier", Price = 23100}),
        table.freeze({Id = "jukebox", Label = "Juke-box", Price = 43300}),
        table.freeze({Id = "fontaine", Label = "Fontaine", Price = 81100}),
        table.freeze({Id = "statue", Label = "Statue dorée", Price = 152000}),
        table.freeze({Id = "enseigne", Label = "Enseigne néon", Price = 285000}),
        table.freeze({Id = "arche_ballons", Label = "Arche de ballons", Price = 534000}),
        table.freeze({Id = "trone", Label = "Trône de brainrot", Price = 1000000}),
    }),
})

-- C2 et Q3 (option A) : le générateur ajoute jusqu'à +50 % de revenu, au prorata de son niveau.
UpgradeConfig.GeneratorIncomeBonusMax = 0.50
UpgradeConfig.DecorIncomeBonusEach = 0.02 -- A5 : +2 % par déco ; C2 : +24 % au maximum
UpgradeConfig.TrainingBonusPerLevel = 0.02 -- A5 : +2 % des stats PvP par niveau d'anneau
-- Q6, option A (décision 44) : pendant l'absence, le coffre garde la moitié du revenu de la base,
-- jusqu'à 1, 2, 4, 8 puis 12 heures d'absence selon son niveau.
UpgradeConfig.VaultIncomeShare = 0.5
UpgradeConfig.VaultCapacityHours = table.freeze({1, 2, 4, 8, 12})
local SECONDS_PER_HOUR = 3600

local byKey: {[string]: any} = {}
for _, component in ipairs(UpgradeConfig.Components) do byKey[component.Key] = component end

function UpgradeConfig.Get(key: any): any
    return if type(key) == "string" then byKey[key] else nil
end

-- Prix pour passer du niveau `level` au suivant ; nil au maximum ou pour un niveau invalide.
function UpgradeConfig.NextPrice(key: any, level: any): number?
    local component = UpgradeConfig.Get(key)
    if not component or type(level) ~= "number" or level % 1 ~= 0 then return nil end
    if level < component.Start or level >= component.Max then return nil end
    return component.Prices[level - component.Start + 1]
end

local function clampLevel(level: any, max: number): number
    if type(level) ~= "number" or level ~= level or level < 0 then return 0 end
    return math.min(math.floor(level), max)
end

function UpgradeConfig.GeneratorIncomeBonus(level: any): number
    local generator = byKey.Generator
    return UpgradeConfig.GeneratorIncomeBonusMax * clampLevel(level, generator.Max) / generator.Max
end

function UpgradeConfig.DecorIncomeBonus(count: any): number
    return UpgradeConfig.DecorIncomeBonusEach * clampLevel(count, #UpgradeConfig.Decor.Items)
end

function UpgradeConfig.TrainingMultiplier(level: any): number
    return 1 + UpgradeConfig.TrainingBonusPerLevel * clampLevel(level, byKey.TrainingRing.Max)
end

-- Durée d'absence que couvre le coffre au niveau `level` ; 0 sans coffre.
function UpgradeConfig.VaultCapacitySeconds(level: any): number
    local hours = UpgradeConfig.VaultCapacityHours[clampLevel(level, byKey.Vault.Max)]
    return if hours then hours * SECONDS_PER_HOUR else 0
end

return table.freeze(UpgradeConfig)
