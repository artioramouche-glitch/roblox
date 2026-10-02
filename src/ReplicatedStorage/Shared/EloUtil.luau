local EloUtil = {}
EloUtil.__index = EloUtil

local K = 32
function EloUtil.Calculate(ra, rb, scoreA)   -- scoreA : 1 = victoire, 0 = défaite, 0.5 = nul
    local ea = 1 / (1 + 10 ^ ((rb - ra) / 400))
    local eb = 1 / (1 + 10 ^ ((ra - rb) / 400))
    return ra + K * (scoreA - ea), rb + K * ((1 - scoreA) - eb)
end

function EloUtil.GetRank(elo)
    if elo >= 2000 then return "BrainrotMaster", 8 end
    if elo >= 1800 then return "Diamant", 7 end
    if elo >= 1600 then return "Platine", 6 end
    if elo >= 1400 then return "Or", 5 end
    if elo >= 1200 then return "Argent", 4 end
    if elo >= 1000 then return "Bronze", 3 end
    return "Bois", 2
end

function EloUtil.SoftReset(elo)  -- fin de saison : ramené à 25% de la distance vers 1200
    return elo - 0.25 * (elo - 1200)
end
return EloUtil
