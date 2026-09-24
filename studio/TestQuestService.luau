--!nonstrict
--[[ TestQuestService
     Rôle    : prouver les quêtes quotidiennes : les 8 de C5, 3 tirées par joueur et par jour parmi celles qu'il peut
               réussir, reset à 00 h 00 UTC, progression par les compteurs du profil, réclamation unique, test d'abus.
     Doc     : GAME_MASTER_V2 C5, G2, G4 (ClaimQuest), A4 ; PROMPT_EXECUTION_SABL_V4 §18.4, §31.10 ; décision 57
     Étape   : 10, lot A
     Dépend  : Play serveur avec un joueur connecté ; Config.QuestConfig, Shared.TableUtil, Migrations, RemoteGuard,
               Services.QuestService, Services.DataService (lecture seule du profil vivant) ; lancé par
               ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; profils, horloge et joueurs factices, le profil vivant n'est que lu. Le journal [QUEST] des
               tirages et réclamations factices est capté ici : rien ne sort sous l'identifiant du testeur
     Limite  : l'horloge est injectée : le passage de 00 h 00 UTC se prouve sans attendre minuit. La réclamation passe
               par RemoteGuard, qui n'admet qu'un vrai joueur : le joueur connecté y sert de clé à un profil factice.
]]
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local QuestConfig = require(ReplicatedStorage.Config.QuestConfig)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local Migrations = require(Server.Data.Migrations)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local QuestService = require(Server.Services.QuestService)
local DataService = require(Server.Services.DataService)

local DAY = QuestConfig.DaySeconds
local FIRST_DAY = 20000 -- jour UTC fixe de l'horloge injectée
local NOON = FIRST_DAY * DAY + DAY / 2
local MIDNIGHT = (FIRST_DAY + 1) * DAY
local FAR_DAYS = 60 -- jours tirés pour voir toutes les quêtes possibles d'un joueur

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Journal des services factices capté ; une fuite dans la sortie se verrait quand même (jours factices 200xx, le
-- vrai jour UTC étant 207xx en 2026).
local logged, leaked = {}, 0
local leakWatch = LogService.MessageOut:Connect(function(message)
    if message:find("[QUEST] CLAIM", 1, true) or (message:find("[QUEST] DRAW", 1, true)
        and message:match("day=200%d%d%s") ~= nil) then
        leaked += 1
    end
end)

-- ── C5 : les chiffres ────────────────────────────────────────────────────
local C5 = { -- recopié de C5 : objectif, argent, tokens
    clicks = {200, 2500, 0}, eggs = {5, 10000, 0}, fusions = {3, 25000, 0}, steal = {1, 50000, 0},
    defend = {2, 30000, 0}, arena_win = {1, 0, 40}, abilities = {5, 0, 25}, playtime = {1200, 100000, 0},
}
local matching = 0
for _, quest in ipairs(QuestConfig.Quests) do
    local spec = C5[quest.Id]
    if spec and quest.Target == spec[1] and (quest.Money or 0) == spec[2] and (quest.ArenaTokens or 0) == spec[3] then
        matching += 1
    end
end
check(("C5 : %d quetes sur 8 conformes (objectif et recompense), 3 par jour, quetes PvP fermees avant l'etape 13")
    :format(matching), matching == 8 and #QuestConfig.Quests == 8 and QuestConfig.PerDay == 3
    and QuestConfig.ArenaOpen == false)
check("C5 : reset a 00 h 00 UTC (jour compte sur l'horloge UTC, minuit suivant midi)",
    QuestConfig.NextReset(NOON) == MIDNIGHT and QuestConfig.DayIndex(MIDNIGHT - 1) == FIRST_DAY
    and QuestConfig.DayIndex(MIDNIGHT) == FIRST_DAY + 1)

-- ── Monde factice ────────────────────────────────────────────────────────
local clock = {now = NOON, guard = 0}
local function makeWorld()
    local world = {profiles = {}}
    local fake = {}
    function fake:Get(t) local s = world.profiles[t] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(t, cb)
        local current = world.profiles[t]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(cb, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        world.profiles[t] = reconciled
        return true, result
    end
    fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return clock.guard end})
    world.data = fake
    world.service = QuestService.new({Data = fake, Clock = function() return clock.now end,
        ListPlayers = function()
            local list = {}
            for p in pairs(world.profiles) do table.insert(list, p) end
            return list
        end,
        Remote = Instance.new("RemoteFunction"), Log = function(line) table.insert(logged, line) end})
    world.service:Init()
    return world
end
local function newProfile(level, playtime)
    local profile = Migrations:Create()
    profile.Level, profile.Playtime = level, playtime
    return profile
end
local function ids(list)
    local out = {}
    for _, entry in ipairs(list) do table.insert(out, entry.Id) end
    return out
end
local NEWBIE_POOL = {clicks = true, eggs = true, fusions = true, playtime = true}

-- ── Décision 57 : le tirage ──────────────────────────────────────────────
local world = makeWorld()
local newbie = {Name = "Debutant", UserId = 1001}
local veteran = {Name = "Veteran", UserId = 1002}
world.profiles[newbie] = newProfile(1, 0)
world.profiles[veteran] = newProfile(5, 3600)
world.profiles[newbie].Stats.EggsOpened = 7
world.service:Step(NOON)
local drawn = world.profiles[newbie].Quests
local inPool, distinct, seen = true, true, {}
for _, entry in ipairs(drawn.List) do
    if not NEWBIE_POOL[entry.Id] then inPool = false end
    if seen[entry.Id] then distinct = false end
    seen[entry.Id] = true
end
local eggsEntry = nil
for _, entry in ipairs(drawn.List) do if entry.Id == "eggs" then eggsEntry = entry end end
check(("Debutant protege (A4) : %s, 3 quetes distinctes parmi clics, oeufs, fusion et 20 min ; reset a minuit UTC")
    :format(table.concat(ids(drawn.List), ", ")),
    #drawn.List == 3 and inPool and distinct and drawn.ResetAt == MIDNIGHT
    and (eggsEntry == nil or eggsEntry.Base == 7) and drawn.List[1].Claimed == false)

local counts, pvp = {}, 0
for day = 0, FAR_DAYS - 1 do
    for _, target in ipairs({newbie, veteran}) do
        local profile = world.profiles[target]
        profile.Quests.ResetAt = 0 -- chaque tour est un nouveau jour
        world.service:Refresh(target, (FIRST_DAY + day) * DAY + 60)
        for _, entry in ipairs(world.profiles[target].Quests.List) do
            local quest = QuestConfig.Get(entry.Id)
            if quest.Arena then pvp += 1 end
            counts[target] = counts[target] or {}
            counts[target][entry.Id] = (counts[target][entry.Id] or 0) + 1
        end
    end
end
local newbieSteal = (counts[newbie].steal or 0) + (counts[newbie].defend or 0)
local veteranSteal = (counts[veteran].steal or 0) + (counts[veteran].defend or 0)
check(("Sur %d jours : aucune quete PvP ; vol et defense %d fois pour le veteran, %d pour le debutant protege")
    :format(FAR_DAYS, veteranSteal, newbieSteal), pvp == 0 and veteranSteal > 0 and newbieSteal == 0)

local again = makeWorld()
again.profiles[newbie] = newProfile(1, 0)
again.service:Refresh(newbie, NOON)
local sameDay = table.concat(ids(again.profiles[newbie].Quests.List), ",")
local refused, code = again.service:Refresh(newbie, NOON + 3600)
local firstWorld = makeWorld()
firstWorld.profiles[newbie] = newProfile(1, 0)
firstWorld.service:Refresh(newbie, NOON)
check(("Tirage fixe pour le jour : meme joueur, meme jour, memes quetes (%s) ; une heure plus tard, rien ne change (%s)")
    :format(sameDay, tostring(code)),
    sameDay == table.concat(ids(firstWorld.profiles[newbie].Quests.List), ",") and refused == false and code == "FRESH"
    and table.concat(ids(again.profiles[newbie].Quests.List), ",") == sameDay)

-- ── C5 : 00 h 00 UTC ─────────────────────────────────────────────────────
local reset = makeWorld()
reset.profiles[veteran] = newProfile(5, 3600)
reset.service:Step(NOON)
local before = table.concat(ids(reset.profiles[veteran].Quests.List), ",")
reset.profiles[veteran].Clicks = 500
reset.service:Step(MIDNIGHT - 1)
local stillSame = reset.profiles[veteran].Quests.ResetAt == MIDNIGHT
reset.service:Step(MIDNIGHT)
local renewed = reset.profiles[veteran].Quests
local clicksBase = nil
for _, entry in ipairs(renewed.List) do if entry.Id == "clicks" then clicksBase = entry.Base end end
check(("Reset : a 23:59:59 rien ne change ; a 00:00:00 UTC, nouveau tirage (%s -> %s) et compteurs relus")
    :format(before, table.concat(ids(renewed.List), ",")),
    stillSame and renewed.ResetAt == MIDNIGHT + DAY and #renewed.List == 3 and (clicksBase == nil or clicksBase == 500))

-- ── G4 : réclamer (joueur connecté comme clé d'un profil factice) ────────
local claims = makeWorld()
local mine = newProfile(5, 3600)
mine.Clicks, mine.Money = 250, 1000
mine.Quests.List = {
    {Id = "clicks", Base = 100, Claimed = false}, {Id = "eggs", Base = 0, Claimed = false},
    {Id = "arena_win", Base = 0, Claimed = false},
}
mine.Quests.ResetAt = MIDNIGHT
claims.profiles[player] = mine
local function claim(questId)
    clock.guard += 1
    return claims.service:Claim(player, questId)
end
local progress = claims.service:Progress(claims.profiles[player], claims.profiles[player].Quests.List[1])
local okEarly, codeEarly = claim("clicks")
claims.profiles[player].Clicks = 300
local okClaim, result = claim("clicks")
local after = claims.data:Get(player)
local okTwice, codeTwice = claim("clicks")
check(("Cliquer 200x : %d/200, refusee (%s) ; a 200, +%d 💰 verses une fois ; deuxieme reclamation %s")
    :format(progress, tostring(codeEarly), result and result.Money or -1, tostring(codeTwice)),
    progress == 150 and okEarly == false and codeEarly == "QUEST_NOT_DONE" and okClaim == true and result.Money == 2500
    and after.Money == 3500 and after.Stats.Earned == 2500 and after.Quests.List[1].Claimed == true
    and okTwice == false and codeTwice == "ALREADY_CLAIMED" and claims.data:Get(player).Money == 3500)

claims.profiles[player].Stats.ArenaWins = 1
local okTokens, tokens = claim("arena_win")
check(("Quete PvP (point d'extension de l'etape 13) : +%d tokens d'arene, argent inchange")
    :format(tokens and tokens.ArenaTokens or -1),
    okTokens == true and tokens.ArenaTokens == 40 and claims.data:Get(player).PvP.ArenaTokens == 40
    and claims.data:Get(player).Money == 3500)

-- §18.4 : paramètres absurdes, quête hors du jour, jour passé, spam.
local snapshot = TableUtil.DeepCopy(claims.profiles[player])
local codes = {}
for _, value in ipairs({"fusions", "inconnue", -1, {}, string.rep("x", 10000)}) do
    local _, codeBad = claim(value)
    table.insert(codes, tostring(codeBad))
end
local _, codeNil = claim(nil)
table.insert(codes, tostring(codeNil))
local unchanged = TableUtil.DeepCopy(claims.profiles[player])
local same = unchanged.Money == snapshot.Money and unchanged.PvP.ArenaTokens == snapshot.PvP.ArenaTokens
check(("§18.4 : hors du jour, inconnue, -1, table, chaine geante, nil -> %s ; profil intact"):format(table.concat(codes, "/")),
    table.concat(codes, "/") == "QUEST_GONE/BAD_QUEST/BAD_QUEST/BAD_QUEST/BAD_QUEST/BAD_QUEST" and same)
claims.profiles[player].Clicks = 1000
clock.now = MIDNIGHT
local okLate, codeLate = claim("eggs")
clock.now = NOON
check(("Apres minuit UTC, les quetes de la veille ne se reclament plus (%s)"):format(tostring(codeLate)),
    okLate == false and codeLate == "QUEST_GONE")
local limited = 0
for _ = 1, 30 do
    local _, codeSpam = claims.service:Claim(player, "eggs")
    if codeSpam == "RATE_LIMIT" then limited += 1 end
end
check(("§18.4 : spam de 30 reclamations dans la meme seconde, %d RATE_LIMIT"):format(limited), limited >= 20)

-- ── Le service vivant et le journal ──────────────────────────────────────
local live = DataService:Get(player)
local liveQuests = live and live.Quests
local liveOk = liveQuests ~= nil and #liveQuests.List == 3 and liveQuests.ResetAt == QuestConfig.NextReset(os.time())
local liveIds = liveQuests and table.concat(ids(liveQuests.List), ", ") or "?"
local remote = ReplicatedStorage.Remotes:FindFirstChild("ClaimQuest")
check(("QuestService vivant : quetes du jour du testeur %s, reset au prochain minuit UTC ; remote ClaimQuest present")
    :format(liveIds), liveOk and remote ~= nil and remote:IsA("RemoteFunction"))
task.wait(0.2) -- laisse passer les messages différés avant de couper la veille
leakWatch:Disconnect()
local draws, claimLines = 0, 0
for _, line in ipairs(logged) do
    if line:match("^%[QUEST%] DRAW user=%d+ day=%d+ quests=") then draws += 1 end
    if line:match("^%[QUEST%] CLAIM user=%d+ quest=") then claimLines += 1 end
end
check(("G3 : %d tirages et %d reclamations journalises par la batterie, %d dans la sortie"):format(draws, claimLines, leaked),
    draws > 0 and claimLines == 2 and leaked == 0)

table.insert(T.lines, ("[QUEST TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
