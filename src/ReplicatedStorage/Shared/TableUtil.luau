--!strict
--[[ TableUtil
     Rôle    : copier les tables simples, leurs clés et leurs liens internes.
     Doc     : GAME_MASTER_V2 G1 ; utilitaire partagé étape 2
     Étape   : 2, lot C1
     Dépend  : aucun ; Migrations reste inchangé
     Exposé  : DeepCopy(value) ; les valeurs non-table sont conservées telles quelles
]]
local TableUtil = {}

local function copyValue(value: any, copies: {[any]: any}): any
    if type(value) ~= "table" then return value end
    assert(getmetatable(value) == nil, "DeepCopy supports tables without metatables only")
    if copies[value] ~= nil then return copies[value] end
    local result: {[any]: any} = {}
    copies[value] = result
    for key, child in pairs(value) do
        result[copyValue(key, copies)] = copyValue(child, copies)
    end
    return result
end

function TableUtil.DeepCopy<T>(value: T): T
    return copyValue(value, {})
end

return TableUtil
