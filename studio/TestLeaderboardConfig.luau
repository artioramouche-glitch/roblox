--!nonstrict
--[[ TestLeaderboardConfig
     Rôle    : vérifier les 2 classements du hub et l'encodage de leurs scores pour OrderedDataStore.
     Doc     : GAME_MASTER_V2 D1.3 Z1, G2 (Stats) ; PROMPT_EXECUTION_SABL_V4 §31.12 lot B ; Q3 de l'étape 12
     Étape   : 12, lot B (configuration)
     Dépend  : ReplicatedStorage.Config.LeaderboardConfig, DefaultProfile
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration et l'encodage ; l'écriture dans le classement et les panneaux se
               testent en Play.
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local L = require(assert(config:FindFirstChild("LeaderboardConfig"), "LeaderboardConfig absent"))
local P = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Q3, recopiée ici.
local earned, steals = L.Get("Earned"), L.Get("Steals")
check("2 classements : Revenus et Vols (D1.3 Z1)", #L.Boards == 2 and earned and earned.Label == "Revenus"
    and steals and steals.Label == "Vols")
check("Q3 : Revenus = Stats.Earned, Vols = Stats.Steals", earned.Stat == "Stats.Earned" and steals.Stat == "Stats.Steals")
check("Q3 : 10 lignes, toutes les 60 s", L.Rows == 10 and L.RefreshSeconds == 60)
check("Les deux compteurs existent dans le profil G2", P.Stats.Earned == 0 and P.Stats.Steals == 0)
check("Get : clé inconnue → nil", L.Get("Money") == nil and L.Get(nil) == nil)

-- Encodage : entier ≥ 0, sous 2^53, ordre conservé, décodé à 10^-12 près.
local LIMIT = 2 ^ 53
local integers, ordered, precise, last = true, true, true, -1
local value = 1
while value < 1e300 do
    local code = L.Encode(earned, value)
    integers = integers and code % 1 == 0 and code >= 0 and code < LIMIT
    ordered = ordered and code >= last
    last = code
    precise = precise and math.abs(L.Decode(earned, code) - value) <= value * 1e-12 + 1e-9
    value *= 1.37
end
check("Revenus : entiers ≥ 0 sous 2^53 de 1 à 10^300", integers)
check("Revenus : l'ordre des scores suit l'ordre des valeurs", ordered)
check("Revenus : décodé à 10^-12 près", precise)
check("Revenus : plus grand nombre Luau encore sous 2^53", L.Encode(earned, 1.7e308) < LIMIT)
local distinct = true
for v = 1, 2000 do distinct = distinct and L.Encode(earned, v + 1) > L.Encode(earned, v) end
check("Revenus : deux totaux entiers voisins jamais à égalité jusqu'à 2 000", distinct
    and L.Encode(earned, 1e12 + 1) > L.Encode(earned, 1e12))
check("Revenus : 0, négatif, NaN, infini ou texte → 0", L.Encode(earned, 0) == 0 and L.Encode(earned, -5) == 0
    and L.Encode(earned, 0 / 0) == 0 and L.Encode(earned, math.huge) == 0 and L.Encode(earned, "9") == 0)
check("Vols : entier brut", L.Encode(steals, 5) == 5 and L.Encode(steals, 5.7) == 5 and L.Decode(steals, 5) == 5
    and L.Encode(steals, -1) == 0)

local summary = ("[LEADERBOARD CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
