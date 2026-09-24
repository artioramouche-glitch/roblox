--!strict
--[[ EconomyConfig
     Rôle    : centraliser les chiffres de l'économie de base, hors bestiaire.
     Doc     : GAME_MASTER_V2 C1 (clic), G4 (plafond, quantités), G1 (boucle 1 s), B3 (fusion)
     Étape   : 3, lot A
     Dépend  : aucun
     Exposé  : configuration immuable ; IsValidQuantity(quantity)
     Limite  : module absent de G1, ajouté pour respecter la Loi 4 ; écart déclaré.
]]
local EconomyConfig = {
    ClickGain = 5,
    InventoryMax = 150,
    EggQuantities = table.freeze({1, 10, 50}),
    IncomeTickSeconds = 1,
    FusionCount = 3,
    MaxPendingIncomeTicks = 60,
}

function EconomyConfig.IsValidQuantity(quantity: any): boolean
    if type(quantity) ~= "number" or quantity ~= quantity or quantity % 1 ~= 0 then return false end
    for _, allowed in ipairs(EconomyConfig.EggQuantities) do
        if quantity == allowed then return true end
    end
    return false
end

return table.freeze(EconomyConfig)
