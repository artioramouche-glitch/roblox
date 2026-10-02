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
check("G2 : Quests.Streak = 0 et LastDailyClaim = 0", P.Quests.Streak == 0 and P.Quests.LastDailyClaim == 0)
-- Le lot A ne bouge pas : mêmes 8 quêtes, même rythme.
check("Lot A intact : 8 quêtes, 3 par jour, jour de 86400 s", #Q.Quests == 8 and Q.PerDay == 3
    and Q.DaySeconds == 86400 and Q.ArenaOpen == false)

local summary = ("[QUEST CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
