--!nonstrict
--[[ TestSeasonRules
     Rôle    : vérifier la clôture de saison : reset souple des deux Elo, récompense du meilleur rang atteint,
               champion, saisons manquées, profil neuf, compteurs remis à zéro.
     Doc     : GAME_MASTER_V2 E6, E7, G5.4, G2 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot C (« 1600 → ~1500 ») ;
               décisions 95, 96, 131, 132
     Étape   : 14, lot C
     Dépend  : ServerScriptService.Arena.SeasonRules ; ReplicatedStorage.Config (ArenaConfig, DefaultProfile)
     Exposé  : exécution manuelle ; écrit seulement dans des copies locales du profil G2
     Limite  : la désignation du champion (classement de tous les serveurs) et la livraison des œufs se testent
               en Play. Instants de référence : ceux de TestArenaConfig (fuseau Europe/Paris de Python).
]]
local arena = assert(game:GetService("ServerScriptService"):FindFirstChild("Arena"), "Arena absent")
local Season = require(assert(arena:FindFirstChild("SeasonRules"), "SeasonRules absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local A = require(assert(config:FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local Default = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- Octobre 2026 à Paris : du 1er à 00:00 (1790805600) au 1er novembre à 00:00 (1793487600).
local OCT, SEPT, JULY = 2026 * 12 + 9, 2026 * 12 + 8, 2026 * 12 + 6
local NOW, OCT_END = 1790805600 + 86400, 1793487600
local function profile(id, elo1, elo2, peak, wins, losses)
    local p = copy(Default)
    p.PvP.Elo1v1, p.PvP.Elo2v2 = elo1, elo2
    p.PvP.Season = {Id = id, PeakElo = peak, Wins = wins, Losses = losses, UltimatesUsed = 4, BestRank = 6}
    return p
end

-- §31.14 / G5.4 : reset souple.
local p = profile(SEPT, 1600, 1400, 1650, 10, 5)
local before = copy(p)
local s = Season.Close(p, NOW)
check("Close ne modifie pas le profil", same(p, before))
check("§31.14 : Elo 1v1 1600 → 1500 ; 2v2 1400 → 1350 (25 % de la distance vers 1200)", s.Elo1v1After == 1500
    and s.Elo2v2After == 1350 and s.Elapsed == 1 and s.OldId == SEPT and s.NewId == OCT)
check("Nouvelle saison : compteurs à zéro, pic = Elo remis, rang Or", s.Season.Id == OCT and s.Season.PeakElo == 1500
    and s.Season.Wins == 0 and s.Season.Losses == 0 and s.Season.UltimatesUsed == 0 and s.Season.BestRank == 5)
local below = Season.Close(profile(SEPT, 900, 1000, 1000, 1, 0), NOW)
check("Sous 1200, l'Elo remonte d'autant : 900 → 975, 1000 → 1050", below.Elo1v1After == 975
    and below.Elo2v2After == 1050)
local _, whyNow = Season.Close(profile(OCT, 1600, 1000, 1600, 1, 0), NOW)
check("Saison en cours : rien à clore (SEASON_CURRENT)", whyNow == "SEASON_CURRENT")

-- E7 / décision 96 : récompense du meilleur rang atteint, rien sous Or.
local function tier(peak, played)
    local summary = Season.Close(profile(SEPT, 1200, 1000, peak, played and 1 or 0, 0), NOW)
    return summary.Tier, summary.Deliver
end
local t1, d1 = tier(1399, true)
local t2, d2 = tier(1450, true)
local t3, d3 = tier(1650, true)
local t4, d4 = tier(1850, true)
local t5, d5 = tier(2050, true)
check("Argent (pic 1399) : rien ; Or (1450) : 1 œuf Mythique", t1 == nil and next(d1) == nil and t2 == "Or"
    and d2.Eggs.egg_mythic == 1)
check("Platine (1650) : 2 œufs ; Diamant (1850) : 3 œufs", t3 == "Platine" and d3.Eggs.egg_mythic == 2
    and t4 == "Diamant" and d4.Eggs.egg_mythic == 3)
check("Brainrot Master (2050) : 1 God du monde 1, et rien d'autre", t5 == "BrainrotMaster" and d5.Rarity == "God"
    and d5.World == 1 and d5.Eggs == nil)
local t6, d6 = tier(1850, false)
check("Saison sans match : aucune récompense, même avec un haut pic", t6 == nil and next(d6) == nil)
local champ = Season.Close(profile(SEPT, 2100, 1000, 2150, 30, 3), NOW, true)
check("Top 1 (Brainrot God) : skin Champion, titre jusqu'à la fin de la saison suivante, statue ; pas le God de Master",
    champ.Tier == "BrainrotGod" and champ.Skin == "SkinChampion" and champ.Title.Name == "Brainrot God"
    and champ.Title.Until == OCT_END and champ.Deliver.Statue == true and champ.Deliver.Rarity == nil)

-- Saisons manquées et profil neuf.
local away = Season.Close(profile(JULY, 1600, 1600, 1700, 5, 0), NOW)
check("3 saisons écoulées : 3 resets (1600 → 1369), récompense de la seule saison jouée", away.Elapsed == 3
    and away.Elo1v1After == 1369 and away.Elo2v2After == 1369 and away.Tier == "Platine")
local fresh = copy(Default)
local dating = Season.Close(fresh, NOW)
check("Profil neuf (G2, Id 1) : seulement daté, Elo de départ 1000 gardé, aucune récompense", dating.Elapsed == 0
    and dating.Elo1v1After == 1000 and dating.Elo2v2After == 1000 and dating.Tier == nil and dating.Season.Id == OCT)
local _, whyAhead = Season.Close(profile(OCT + 1, 1600, 1000, 1600, 1, 0), NOW)
local _, whyBad = Season.Close({PvP = {}}, NOW)
check("Saison venue du futur (BAD_SEASON) ; profil sans saison (BAD_INPUT)", whyAhead == "BAD_SEASON"
    and whyBad == "BAD_INPUT")

-- Application au profil.
p = profile(SEPT, 2100, 1300, 2150, 30, 3)
local summary = Season.Close(p, NOW, true)
Season.Apply(p, summary)
check("Apply : Elo, saison, skin possédé, titre daté", p.PvP.Elo1v1 == 1875 and p.PvP.Elo2v2 == 1275
    and p.PvP.Season.Id == OCT and p.PvP.Season.Wins == 0 and p.PvP.Cosmetics.SkinChampion == true
    and p.PvP.SeasonTitle.Name == "Brainrot God" and p.PvP.SeasonTitle.Until == OCT_END)
local _, whyTwice = Season.Close(p, NOW, true)
check("Une saison ne se clôt qu'une fois", whyTwice == "SEASON_CURRENT")
check("Saison d'octobre 2026 lue dans ArenaConfig.SeasonAt (heure de Paris)", A.SeasonAt(NOW) == OCT)

local result = ("[SEASON RULES TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, result)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
