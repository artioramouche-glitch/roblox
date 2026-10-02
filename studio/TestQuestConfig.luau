--!nonstrict
--[[ TestQuestConfig
     Rôle    : vérifier la série de 7 jours de QuestConfig contre C5 et la décision 58, sans toucher aux quêtes du lot A.
     Doc     : GAME_MASTER_V2 C5, G2 (Quests), B2 ; PROMPT_EXECUTION_SABL_V4 §31.10 lot B ; décision 58
     Étape   : 10, lot B (configuration)
     Dépend  : ReplicatedStorage.Config.QuestConfig, EggConfig, CreatureConfig et DefaultProfile
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : ne prouve que la configuration ; le versement, le reset sur jour manqué et la persistance relèvent du
               service et se testent en Play.
]]
local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
assert(config, "Config absent")
local Q = require(assert(config:FindFirstChild("QuestConfig"), "QuestConfig absent"))
local E = require(assert(config:FindFirstChild("EggConfig"), "EggConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local P = require(assert(config:FindFirstChild("DefaultProfile"), "DefaultProfile absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Référence décision 58 (option A du 24/09), recopiée ici : jamais déduite de la configuration testée.
local expected = {
    {Money = 10000},
    {Money = 25000},
    {Money = 50000},
    {Egg = "egg_street"},
    {Egg = "egg_street"},
    {Rarity = "Epic"},
    {Rarity = "Rare", Spins = 1},
}
local function sameValues(actual, wanted)
    if type(actual) ~= "table" then return false end
    for key, value in pairs(wanted) do
        if actual[key] ~= value then return false end
    end
    for key in pairs(actual) do if wanted[key] == nil then return false end end
    return true
end

check("Streak = 7 jours", type(Q.Streak) == "table" and #Q.Streak == 7)
for day, wanted in ipairs(expected) do
    local reward = Q.Streak and Q.Streak[day]
    check(("J%d exact (décision 58)"):format(day), sameValues(reward, wanted))
    local kinds = 0
    if reward then
        for _, key in ipairs({"Money", "Egg", "Rarity"}) do
            if reward[key] ~= nil then kinds += 1 end
        end
    end
    check(("J%d une seule récompense"):format(day), kinds == 1)
    check(("J%d StreakReward"):format(day), Q.StreakReward(day) == reward)
end
check("J4-J5 egg_street existe dans EggConfig", E:Get("egg_street") ~= nil)
check("J6 Epic existe dans CreatureConfig", C:GetRarity("Epic") ~= nil)
check("J7 Rare existe dans CreatureConfig", C:GetRarity("Rare") ~= nil)
local outside = true
for _, day in ipairs({0, 8, -1, 1.5, "1", false}) do
    outside = outside and Q.StreakReward(day) == nil
end
outside = outside and Q.StreakReward(nil) == nil and Q.StreakReward({}) == nil
check("StreakReward hors 1..7 = nil", outside)
check("Streak gelée", table.isfrozen(Q.Streak) and table.isfrozen(Q.Streak[7]))

-- Q2 du lot B (option A) : espèces du monde 1, listes recopiées de B1.
check("StreakWorld = 1", Q.StreakWorld == 1)
local function candidates(rarity)
    local ids = {}
    for _, creature in ipairs(C.Creatures) do
        if creature.world == Q.StreakWorld and creature.rarity == rarity then table.insert(ids, creature.id) end
    end
    table.sort(ids)
    return table.concat(ids, ",")
end
check("J6 : 4 Épiques du monde 1", candidates("Epic") == "blueberrini,cappuccino,patapim,strawberelli")
check("J7 : 5 Rares du monde 1", candidates("Rare") == "boneca,chim_banana,footera,trippi,tung_tung")

-- Q1 du lot B (option A) : jour suivant si réclamé hier, J7 → J1, jour manqué → J1, une fois par jour UTC.
local DAY = 86400
local D = 20000 -- jour UTC fixe
local function at(day, seconds) return day * DAY + seconds end
local cases = {
    {"première fois", 0, 0, at(D, 43200), true, 1, 1},
    {"réclamé hier, Streak 1", 1, at(D - 1, 43200), at(D, 43200), true, 2, 2},
    {"réclamé hier, Streak 6", 6, at(D - 1, 43200), at(D, 43200), true, 7, 7},
    {"après J7 : retour à J1", 7, at(D - 1, 43200), at(D, 43200), true, 1, 8},
    {"2e semaine, Streak 10", 10, at(D - 1, 43200), at(D, 43200), true, 4, 11},
    {"déjà réclamé ce jour", 3, at(D, 3600), at(D, 43200), false, 3, 3},
    {"déjà réclamé, Streak 7", 7, at(D, 3600), at(D, 43200), false, 7, 7},
    {"jour manqué", 5, at(D - 2, 43200), at(D, 43200), true, 1, 1},
    {"23:59:59 puis 00:00:00", 2, at(D - 1, DAY - 1), at(D, 0), true, 3, 3},
    {"00:00:00 puis 23:59:59", 2, at(D, 0), at(D, DAY - 1), false, 2, 2},
    {"réclamation datée du futur", 4, at(D + 1, 60), at(D, 43200), false, 4, 4},
}
for _, case in ipairs(cases) do
    local ok, day, streak = Q.StreakNext(case[2], case[3], case[4])
    check(("StreakNext %s → %s, J%d, Streak %d"):format(case[1], tostring(case[5]), case[6], case[7]),
        ok == case[5] and day == case[6] and streak == case[7])
end
check("G2 : Quests.Streak = 0 et LastDailyClaim = 0", P.Quests.Streak == 0 and P.Quests.LastDailyClaim == 0)
-- Le lot A ne bouge pas : mêmes 8 quêtes, même rythme.
check("Lot A intact : 8 quêtes, 3 par jour, jour de 86400 s", #Q.Quests == 8 and Q.PerDay == 3
    and Q.DaySeconds == 86400 and Q.ArenaOpen == false)

local summary = ("[QUEST CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
