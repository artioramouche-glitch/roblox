--!strict
--[[ WeightedRandom
     Rôle    : tirer une clé selon des poids non négatifs, uniquement côté serveur ou Édition.
     Doc     : PROMPT_EXECUTION_SABL_V4 §16.10 ; GAME_MASTER_V2 B2
     Étape   : 2, lot C1
     Dépend  : RunService ; générateur Random fourni par l'appelant serveur
     Exposé  : pick(entries, rng) -> key ; erreurs explicites si entrée invalide
]]
local RunService = game:GetService("RunService")
local WeightedRandom = {}
export type Entry = {key: any, weight: number}

local function validate(entries: {Entry}): number
    assert(type(entries) == "table", "Expected an array of entries")
    local count, length, maximum = 0, #entries, 0
    assert(length > 0, "Entries must not be empty")
    for index, entry in pairs(entries) do
        assert(type(index) == "number" and index % 1 == 0 and index >= 1 and index <= length,
            "Entries must be a dense array")
        count += 1
        assert(type(entry) == "table" and entry.key ~= nil, "Entry must have a non-nil key")
        local weight = entry.weight
        assert(type(weight) == "number" and weight == weight and weight >= 0 and weight < math.huge,
            "Weight must be finite and non-negative")
        maximum = math.max(maximum, weight)
    end
    assert(count == length, "Entries must be a dense array")
    assert(maximum > 0, "At least one weight must be positive")
    return maximum
end

function WeightedRandom.pick(entries: {Entry}, rng: Random): any
    assert(not RunService:IsClient(), "Weighted draws must run on the server")
    assert(typeof(rng) == "Random", "Expected a Random generator")
    local maximum = validate(entries)
    -- Normaliser temporairement évite le dépassement de capacité de la somme.
    -- Les poids de configuration ne sont jamais modifiés.
    local total = 0
    for _, entry in ipairs(entries) do total += entry.weight / maximum end
    local roll = rng:NextNumber(0, total)
    local accumulated, lastPositiveKey = 0, nil
    for _, entry in ipairs(entries) do
        if entry.weight > 0 then
            accumulated += entry.weight / maximum
            lastPositiveKey = entry.key
            if roll < accumulated then return entry.key end
        end
    end
    -- Arrondi flottant à la borne supérieure : jamais de candidat de poids nul.
    return lastPositiveKey
end

return WeightedRandom
