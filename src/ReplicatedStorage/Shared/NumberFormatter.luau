--!strict
--[[ NumberFormatter
     Rôle    : afficher les nombres finis avec les suffixes du prompt.
     Doc     : PROMPT_EXECUTION_SABL_V4 §16.9
     Étape   : 2, lot C1
     Dépend  : aucun
     Exposé  : format(number) -> string
]]
local NumberFormatter = {}
local SUFFIXES = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}

function NumberFormatter.format(n: number): string
    assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "Expected a finite number")
    if n == 0 then return "0" end
    if math.abs(n) < 1000 then return tostring(math.floor(n)) end
    -- Calculer chaque seuil directement évite l'accumulation des arrondis.
    local index = 1
    while index < #SUFFIXES and math.abs(n) >= 1000 ^ index do
        index += 1
    end
    local scaled = n / (1000 ^ (index - 1))
    local magnitude = math.abs(scaled)
    local pattern = magnitude >= 100 and "%.0f" or magnitude >= 10 and "%.1f" or "%.2f"
    return pattern:format(scaled) .. SUFFIXES[index]
end

return NumberFormatter
