--!nonstrict
--[[ TestWarRules
     Rôle    : vérifier la guerre de territoire : force des clans, déclaration (F4), appariement (Q1 A), 3 fronts avec
               les 30 min de jeu, cérémonie unique, MVP (Q2 A), et une guerre complète dont les duels sont joués par
               le moteur de combat (critère H2 de l'étape 15).
     Doc     : GAME_MASTER_V2 F3, F4 ; PROMPT_EXECUTION_SABL_V4 §31.15 (tests « Vol de drapeau », « Compte < 30 min »,
               « Cérémonie », « Quitter en pleine guerre ») ; décisions 100 à 104, 133 à 137
     Étape   : 15, lots D à G
     Dépend  : ServerScriptService.Clan.WarRules, ClanRules ; ServerScriptService.Combat.CombatEngine, CombatBot ;
               ReplicatedStorage.Config (ClanConfig, CreatureConfig, DefaultProfile)
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : le drapeau (StealService:StealFlag), le boss de guerre et le versement des récompenses se testent en
               Play. Horaires tirés de ClanConfig.WarAt (dimanche 20:00 → jeudi 20:00, heure de Paris).
]]
local SSS = game:GetService("ServerScriptService")
local clanFolder = assert(SSS:FindFirstChild("Clan"), "Clan absent")
local W = require(assert(clanFolder:FindFirstChild("WarRules"), "WarRules absent"))
local R = require(assert(clanFolder:FindFirstChild("ClanRules"), "ClanRules absent"))
local combat = assert(SSS:FindFirstChild("Combat"), "Combat absent")
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
local Bot = require(assert(combat:FindFirstChild("CombatBot"), "CombatBot absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local CC = require(assert(config:FindFirstChild("ClanConfig"), "ClanConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
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
local DAY, MIN = 86400, 60
local _, START, FINISH = CC.WarAt(1791041400) -- samedi 3 octobre 2026 → guerre du dimanche 4 au jeudi 8
local BEFORE = START - 3600
-- Clan dont le chef est `first`, membres first+1 … first+n-1 (arrivées espacées), officier first+1.
local function clanWith(first, n)
    local p = copy(Default)
    p.Money = 1e6
    local clan = R.Create(p, first, "c" .. first, "Clan " .. first, "CL", 1, BEFORE - DAY)
    for userId = first + 1, first + n - 1 do
        R.Request(clan, userId, copy(Default), BEFORE - DAY)
        R.Accept(clan, first, userId, BEFORE - DAY + userId)
    end
    R.Promote(clan, first, first + 1)
    return clan
end
local PLAY = 40 * MIN

-- F3 / Q1 (A) : force = somme des Elo des membres actifs.
local sum, active = W.Strength({{Elo = 1200, LastSeen = BEFORE}, {Elo = 1300, LastSeen = BEFORE - 6 * DAY},
    {Elo = 1500, LastSeen = BEFORE - 8 * DAY}}, BEFORE)
check("Force : somme des Elo des membres vus dans les 7 jours (1200 + 1300 ; l'absent de 8 jours ignoré)", sum == 2500
    and active == 2)

-- F4 : déclaration.
local clan = clanWith(1, 6)
local _, member = W.Declare(clan, 4, 6, BEFORE)
local _, few = W.Declare(clan, 2, 4, BEFORE)
local ok = W.Declare(clan, 2, 6, BEFORE)
local _, twice = W.Declare(clan, 2, 6, BEFORE + 60)
local _, running = W.Declare(clanWith(1, 6), 1, 6, START + 3600)
check("Déclaration par un officier ou le chef ; refus : simple membre, moins de 5 actifs, déjà déclaré, guerre en cours",
    ok and member == "NOT_ALLOWED" and few == "TOO_FEW_ACTIVE" and twice == "ALREADY_DECLARED"
    and running == "WAR_RUNNING" and clan.DeclaredFor == START)
local tired = clanWith(1, 6)
tired.LastWarEnd = BEFORE - 23 * 3600
local _, cooldown = W.Declare(tired, 1, 6, BEFORE)
tired.LastWarEnd = BEFORE - 24 * 3600
check("F4 : 24 h de pause après une guerre (COOLDOWN à 23 h, permis à 24 h)", cooldown == "COOLDOWN"
    and W.Declare(tired, 1, 6, BEFORE))

-- Q1 (A) : appariement des forces voisines.
local pairs_, alone = W.Pair({{Key = "a", Strength = 24000}, {Key = "b", Strength = 8000}, {Key = "c", Strength = 23000},
    {Key = "d", Strength = 9000}, {Key = "e", Strength = 15000}})
check("Appariement : 24 000-23 000, 15 000-9 000 ; le plus faible d'un nombre impair attend", #pairs_ == 2
    and pairs_[1].A == "a" and pairs_[1].B == "c" and pairs_[2].A == "e" and pairs_[2].B == "d" and alone == "b")

-- Ouverture : plus de départ ni d'exclusion (§31.15).
local A, B = clanWith(1, 6), clanWith(11, 6)
W.Declare(A, 1, 6, BEFORE)
W.Declare(B, 11, 6, BEFORE)
local war = W.Start(A, B, "c1", "c11", START)
local _, leave = R.Leave(A, 3)
local _, kick = R.Kick(B, 11, 14)
check("§31.15 : quitter ou exclure en pleine guerre → WAR_ACTIVE", leave == "WAR_ACTIVE" and kick == "WAR_ACTIVE"
    and war.StartAt == START and war.EndAt == FINISH and A.DeclaredFor == nil)

-- Front 1 : duels.
W.Duel(war, {Side = "A", UserId = 1, Play = PLAY}, {Side = "B", UserId = 11, Play = PLAY})
check("Duel : 75 au vainqueur, 15 au vaincu", war.Members[1].Arena == 75 and war.Members[11].Arena == 15)
W.Duel(war, {Side = "A", UserId = 2, Play = 29 * MIN}, {Side = "B", UserId = 12, Play = PLAY})
check("F4 : moins de 30 min de jeu de guerre → le duel compte, mais 0 point", war.Members[2] == nil
    and war.Members[12].Arena == 15 and war.Sides.A.Duels == 2)
for i = 3, 5 do W.Duel(war, {Side = "A", UserId = i, Play = PLAY}, {Side = "B", UserId = 10 + i, Play = PLAY}) end
local _, sixth = W.Duel(war, {Side = "B", UserId = 16, Play = PLAY}, {Side = "A", UserId = 6, Play = PLAY})
local _, badDuel = W.Duel(war, {Side = "A", UserId = 1, Play = PLAY}, {Side = "A", UserId = 2, Play = PLAY})
check("5 duels par guerre (6e : DUELS_DONE) ; duel d'un même clan refusé", sixth == "DUELS_DONE"
    and badDuel == "BAD_INPUT" and W.Totals(war).A.Arena == 4 * 75 and W.Totals(war).B.Arena == 5 * 15)

-- Front 2 : drapeaux.
local _, short = W.Flag(war, "A", 6, 30 * MIN - 1)
local flags = 0
for _ = 1, 11 do if W.Flag(war, "B", 16, 30 * MIN) then flags += 1 end end
check("§31.15 : moins de 30 min de guerre → ne marque pas (NOT_ENOUGH_PLAY)", short == "NOT_ENOUGH_PLAY")
check("§31.15 : drapeau = 50 points, 10 au plus par clan (500)", flags == 10 and W.Totals(war).B.Steal == 500
    and war.Members[16].Flags == 10)

-- Front 3 : boss.
W.BossHit(war, "A", 6, 3000)
W.BossHit(war, "B", 13, 1000)
local _, badHit = W.BossHit(war, "A", 6, -5)
local totals = W.Totals(war)
check("Boss : pas de condition de temps de jeu ; 500 points au prorata des dégâts (375 / 125)", totals.A.Boss == 375
    and totals.B.Boss == 125 and badHit == "BAD_INPUT")
check("Totaux : A 300 + 0 + 375 = 675 ; B 75 + 500 + 125 = 700", totals.A.Total == 675 and totals.B.Total == 700)

-- F3 : cérémonie, une seule fois.
local _, early = W.Ceremony(war, A, B, FINISH - 1)
local result = W.Ceremony(war, A, B, FINISH)
local _, again = W.Ceremony(war, A, B, FINISH + 60)
local rw = result.Rewards
check("Cérémonie : pas avant jeudi 20:00 ; une seule fois (ALREADY_DONE)", early == "TOO_EARLY" and result ~= nil
    and again == "ALREADY_DONE")
check("Gagnant B : 400 tokens + 250 K 💰 à chaque membre, egg_mythic aux seuls marqueurs", result.Winner == "B"
    and rw[16].ArenaTokens == 400 and rw[16].Money == 250000 and rw[16].Eggs.egg_mythic == 1 and rw[13].Eggs ~= nil
    and rw[11].Eggs ~= nil and rw[14].Eggs ~= nil)
check("Perdant A : 100 tokens + 50 K 💰, aucun œuf ; le combattant à 29 min n'a rien marqué", rw[1].ArenaTokens == 100
    and rw[1].Money == 50000 and rw[1].Eggs == nil and rw[2].Points == 0)
check("Fin de guerre : départs permis, 24 h de pause avant de redéclarer", A.WarActive == nil and B.LastWarEnd == FINISH
    and R.Leave(A, 3) ~= nil and select(2, W.Declare(A, 1, 6, FINISH + 3600)) == "COOLDOWN"
    and W.Declare(A, 1, 6, FINISH + DAY) == true)

-- Q2 (A) : un MVP par front, tous clans confondus.
local mvp = {}
for _, m in ipairs(result.Mvps) do mvp[m.Front] = m end
check("Q2 (A) : MVP Duels = 1 (le premier à 75), Vol = 16, Boss = 6 ; pose de 7 jours", #result.Mvps == 3
    and mvp.Arena.UserId == 1 and mvp.Steal.UserId == 16 and mvp.Boss.UserId == 6
    and mvp.Boss.Until == FINISH + 7 * DAY)

-- Égalité et part du boss.
local X, Y = clanWith(1, 6), clanWith(11, 6)
local tie = W.Start(X, Y, "x", "y", START)
W.BossHit(tie, "A", 2, 1)
W.BossHit(tie, "B", 12, 1)
local tieResult = W.Ceremony(tie, X, Y, FINISH)
check("Égalité (250-250) : les deux clans reçoivent la récompense du gagnant", tieResult.Winner == "Tie"
    and tieResult.Rewards[1].ArenaTokens == 400 and tieResult.Rewards[11].ArenaTokens == 400
    and tieResult.Rewards[2].Eggs ~= nil and tieResult.Rewards[12].Eggs ~= nil)
check("Clan gagnant : pas d'œuf pour un membre qui n'a rien marqué", tieResult.Rewards[3].Eggs == nil
    and tieResult.Rewards[3].ArenaTokens == 400 and tieResult.Rewards[1].Eggs == nil)
X, Y = clanWith(1, 6), clanWith(11, 6)
local share = W.Start(X, Y, "x", "y", START)
W.BossHit(share, "A", 2, 990)
W.BossHit(share, "A", 3, 10)
W.BossHit(share, "B", 12, 1000)
local shareResult = W.Ceremony(share, X, Y, FINISH)
check("Part du boss : 10 dégâts sur 1 000 → 3 points sur 250, assez pour l'œuf", shareResult.Rewards[3].Points == 3
    and shareResult.Rewards[3].Eggs ~= nil)

-- Critère H2 : guerre complète, duels joués par le moteur et les bots.
local world1 = {}
for _, c in ipairs(C.Creatures) do if c.world == 1 then table.insert(world1, c.id) end end
math.randomseed(15)
local function team()
    local out = {}
    for slot = 1, 3 do
        local id = world1[math.random(1, #world1)]
        local s = C:GetCombatStats(id, 1, true)
        out[slot] = {Id = id, HP = s.HP, ATK = s.ATK, Type = s.Type}
    end
    return out
end
A, B = clanWith(1, 8), clanWith(11, 8)
war = W.Start(A, B, "c1", "c11", START)
for i = 1, 5 do
    local fight = Engine.New(team(), team(), math.random(0, 2 ^ 31 - 1))
    local brains = {A = Bot.NewBrain("Normal", 0), B = Bot.NewBrain("Normal", 0)}
    while not fight.Over do
        Bot.Decide(brains.A, fight, "A")
        Bot.Decide(brains.B, fight, "B")
        Engine.Step(fight)
        Engine.Snapshot(fight)
    end
    local a, b = {Side = "A", UserId = i, Play = PLAY}, {Side = "B", UserId = 10 + i, Play = PLAY}
    if fight.Winner == "B" then W.Duel(war, b, a) else W.Duel(war, a, b) end
end
for _ = 1, math.random(3, 12) do W.Flag(war, "A", math.random(1, 8), PLAY) end
for _ = 1, math.random(3, 12) do W.Flag(war, "B", math.random(11, 18), PLAY) end
for _ = 1, 40 do
    local side = if math.random() < 0.5 then "A" else "B"
    W.BossHit(war, side, if side == "A" then math.random(1, 8) else math.random(11, 18), math.random(50, 500))
end
totals = W.Totals(war)
result = W.Ceremony(war, A, B, FINISH)
local rewarded = 0
for _ in pairs(result.Rewards) do rewarded += 1 end
check(("Guerre simulée complète : %d-%d (duels %d-%d, drapeaux %d-%d, boss %d-%d), 16 membres récompensés"):format(
    totals.A.Total, totals.B.Total, totals.A.Arena, totals.B.Arena, totals.A.Steal, totals.B.Steal, totals.A.Boss,
    totals.B.Boss), war.Sides.A.Duels == 5 and totals.A.Arena + totals.B.Arena == 5 * 90
    and totals.A.Boss + totals.B.Boss == 500 and totals.A.Steal <= 500 and rewarded == 16 and war.Closed)

local summary = ("[WAR RULES TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
