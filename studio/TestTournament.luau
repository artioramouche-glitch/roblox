--!nonstrict
--[[ TestTournament
     Rôle    : vérifier le Tournoi du Samedi : inscriptions, tableaux, placement, passages directs, progression,
               paris, récompenses, et un tableau de 16 joué en entier par le moteur de combat.
     Doc     : GAME_MASTER_V2 E9, E6 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot E (« bracket 8 joueurs : 3 tours, un seul
               champion » ; pari 50 tokens double ou rien ; Elo ≥ 1100) ; décisions 95, 128 à 132
     Étape   : 14, lot E
     Dépend  : ServerScriptService.Arena.TournamentBracket ; ServerScriptService.Combat.CombatEngine, CombatBot ;
               ReplicatedStorage.Config (ArenaConfig, CreatureConfig)
     Exposé  : exécution manuelle ; aucune écriture de données
     Limite  : les serveurs de tournoi, l'écran géant et le versement des récompenses se testent en Play.
               Samedi de référence : 3 octobre 2026, inscription à 17:30 Paris (TestArenaConfig).
]]
local SSS = game:GetService("ServerScriptService")
local TB = require(assert(assert(SSS:FindFirstChild("Arena"), "Arena absent"):FindFirstChild("TournamentBracket"),
    "TournamentBracket absent"))
local combat = assert(SSS:FindFirstChild("Combat"), "Combat absent")
local Engine = require(assert(combat:FindFirstChild("CombatEngine"), "CombatEngine absent"))
local Bot = require(assert(combat:FindFirstChild("CombatBot"), "CombatBot absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local A = require(assert(config:FindFirstChild("ArenaConfig"), "ArenaConfig absent"))
local C = require(assert(config:FindFirstChild("CreatureConfig"), "CreatureConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local REG = 1791041400 -- samedi 3 octobre 2026, 17:30 à Paris
local DRAW, DAY = REG + 15 * 60, 86400

local function fill(n)
    local t = TB.New(REG - 3600)
    for i = 1, n do TB.Register(t, i, 2000 - i * 10, REG + i) end
    TB.Draw(t, DRAW)
    return t
end
local function shape(t)
    local out = {}
    for _, bracket in ipairs(t.Brackets) do table.insert(out, #bracket.Players .. "/" .. bracket.Size) end
    return table.concat(out, ",")
end
local function pendingSeeds(t)
    local out = {}
    for _, m in ipairs(TB.Pending(t)) do table.insert(out, m.Round .. ":" .. m.SeedA .. "-" .. m.SeedB) end
    return table.concat(out, ",")
end
-- Joue tous les matchs prêts en donnant la victoire au mieux classé, sauf `upsets[id] = true`.
local function playAll(t, upsets)
    local played = 0
    while true do
        local ready = TB.Pending(t)
        if #ready == 0 then return played end
        for _, m in ipairs(ready) do
            local better = if m.SeedA < m.SeedB then m.A else m.B
            local worse = if better == m.A then m.B else m.A
            TB.Report(t, m.Id, if upsets and upsets[m.Id] then worse else better)
            played += 1
        end
    end
end

-- E9 : inscriptions.
local t = TB.New(REG - 3600)
local _, early = TB.Register(t, 1, 1500, REG - 1)
local ok1 = TB.Register(t, 1, 1500, REG)
local _, low = TB.Register(t, 2, 1099, REG + 10)
local ok3 = TB.Register(t, 3, 1100, REG + 10)
local _, dup = TB.Register(t, 1, 1500, REG + 20)
local _, late = TB.Register(t, 4, 1500, DRAW)
local _, bad = TB.Register(t, "5", 1500, REG + 30)
check("Inscription de 17:30 à 17:45 (REGISTRATION_CLOSED avant et après), une fois (ALREADY_REGISTERED)",
    early == "REGISTRATION_CLOSED" and ok1 and dup == "ALREADY_REGISTERED" and late == "REGISTRATION_CLOSED"
    and bad == "BAD_INPUT")
check("§31.14 : Elo ≥ 1100 requis (1099 refusé, 1100 accepté)", low == "ELO_TOO_LOW" and ok3)
check("Désinscription avant le tirage seulement", TB.Withdraw(t, 3) == true and TB.Withdraw(t, 3) == false
    and #t.Entrants == 1)
local _, tooEarly = TB.Draw(t, DRAW - 1)
TB.Draw(t, DRAW)
local _, drawnTwice = TB.Draw(t, DRAW + 1)
check("Tirage à 17:45 (TOO_EARLY avant) ; un seul inscrit : tournoi annulé (Q1 A : moins de 4)",
    tooEarly == "TOO_EARLY" and t.Phase == "Cancelled" and drawnTwice == "ALREADY_DRAWN")
check("3 inscrits : annulé ; 4 : un tableau de 8 places", fill(3).Phase == "Cancelled" and shape(fill(4)) == "4/8"
    and fill(4).Phase == "Running")
local drawn = fill(8)
check("Plus de désinscription après le tirage", TB.Withdraw(drawn, 1) == false and #drawn.Entrants == 8
    and #drawn.Brackets[1].Players == 8)

-- Q1 (A) : tableaux.
check("8 → 8/8 ; 11 → 16 places ; 16 → 16/16", shape(fill(8)) == "8/8" and shape(fill(11)) == "11/16"
    and shape(fill(16)) == "16/16")
check("17 → 9 + 8 ; 20 → 16 + 4 ; 33 → 16 + 9 + 8 (jamais de tableau sous 4 joueurs)", shape(fill(17)) == "9/16,8/8"
    and shape(fill(20)) == "16/16,4/8" and shape(fill(33)) == "16/16,9/16,8/8")
local big = fill(33)
check("Les 16 meilleurs Elo dans le 1er tableau, tête de série 1 = meilleur Elo", big.Brackets[1].Players[1] == 1
    and big.Brackets[1].Players[16] == 16 and big.Brackets[2].Players[1] == 17)

-- Placement et passages directs.
check("Tableau de 8 : 1-8, 4-5, 2-7, 3-6", pendingSeeds(fill(8)) == "1:1-8,1:4-5,1:2-7,1:3-6")
check("11 dans 16 : les 5 premiers passent directement ; 3 matchs au 1er tour (8-9, 7-10, 6-11), 4-5 déjà prêt",
    pendingSeeds(fill(11)) == "1:8-9,1:7-10,1:6-11,2:4-5")
check("4 dans 8 : tout le 1er tour en passages directs, demi-finales 1-4 et 2-3", pendingSeeds(fill(4)) == "2:1-4,2:2-3")

-- §31.14 : tableau de 8, 3 tours, un seul champion.
t = fill(8)
local final = t.Brackets[1].Matches[3][1]
local _, notReady = TB.Report(t, final.Id, 1)
local played = playAll(t)
local bracket = t.Brackets[1]
check("Tableau de 8 : 3 tours, 7 matchs, un seul champion (le n° 1), tournoi fini", played == 7 and bracket.Rounds == 3
    and bracket.Champion == 1 and bracket.Done and t.Phase == "Done" and notReady == "NOT_READY")
local _, twice = TB.Report(t, final.Id, 1)
local _, unknown = TB.Report(t, "9-9-9", 1)
local t2 = fill(8)
local first = TB.Pending(t2)[1]
local _, wrong = TB.Report(t2, first.Id, 999)
check("Résultat refusé : déjà donné, match inconnu, vainqueur hors du match", twice == "ALREADY_REPORTED"
    and unknown == "UNKNOWN_MATCH" and wrong == "BAD_WINNER")
check("Tableau de 16 : 4 tours, 15 matchs", playAll(fill(16)) == 15 and fill(16).Brackets[1].Rounds == 4)

-- Q2 (A) : récompense du seul meilleur tour atteint.
local rows = TB.Results(t, 1, DRAW + 3600)
local byUser, tokens = {}, 0
for _, row in ipairs(rows) do
    byUser[row.UserId] = row
    tokens += row.ArenaTokens
end
local champ, second = byUser[1], byUser[2]
check("Champion : 3 000 tokens, 1 God du monde 1, titre « Champion de la Semaine » pendant 7 jours",
    champ.Stage == "Champion" and champ.ArenaTokens == 3000 and champ.Rarity == "God" and champ.World == 1
    and champ.Title.Name == "Champion de la Semaine" and champ.Title.Until == DRAW + 3600 + 7 * DAY)
check("Finaliste 1 500 + 2 œufs ; demi-finalistes 800 + 1 œuf ; quarts 300 ; sans cumul (7 300 au total)",
    second.Stage == "Finalist" and second.ArenaTokens == 1500 and second.Eggs.egg_mythic == 2
    and byUser[3].Stage == "Top4" and byUser[4].ArenaTokens == 800 and byUser[4].Eggs.egg_mythic == 1
    and byUser[5].Stage == "Top8" and byUser[8].ArenaTokens == 300 and byUser[8].Eggs == nil and tokens == 7300)
local t16 = fill(16)
playAll(t16)
local rows16 = TB.Results(t16, 1, DRAW)
local none = 0
for _, row in ipairs(rows16) do if row.Stage == nil and row.ArenaTokens == 0 then none += 1 end end
check("Tableau de 16 : les 8 perdants du 1er tour ne gagnent rien", none == 8)
local _, notFinished = TB.Results(fill(8), 1, DRAW)
check("Pas de récompense avant la fin (NOT_FINISHED)", notFinished == "NOT_FINISHED")

-- Q3 (A) : pari des éliminés sur la finale, 50 tokens, double ou rien.
t = fill(8)
for _, m in ipairs(TB.Pending(t)) do TB.Report(t, m.Id, if m.SeedA < m.SeedB then m.A else m.B) end
local _, tooSoon = TB.Bet(t, 8, 1, 500)
for _, m in ipairs(TB.Pending(t)) do TB.Report(t, m.Id, if m.SeedA < m.SeedB then m.A else m.B) end
local stake = TB.Bet(t, 8, 1, 500)
local _, already = TB.Bet(t, 8, 2, 500)
local stake2 = TB.Bet(t, 7, 2, 50)
local _, pickBad = TB.Bet(t, 6, 3, 500)
local _, finalist = TB.Bet(t, 1, 2, 500)
local _, stranger = TB.Bet(t, 99, 1, 500)
local _, poor = TB.Bet(t, 5, 1, 49)
check("Pari fermé tant que la finale n'est pas connue (BETS_CLOSED)", tooSoon == "BETS_CLOSED")
check("Un éliminé mise 50 une fois sur un finaliste ; refus : 2e pari, non-finaliste, finaliste, inconnu, 49 tokens",
    stake == 50 and already == "ALREADY_BET" and stake2 == 50 and pickBad == "BAD_PICK" and finalist == "NOT_ELIMINATED"
    and stranger == "NOT_ENTRANT" and poor == "NOT_ENOUGH_TOKENS")
local finalMatch = TB.Pending(t)[1]
TB.Start(t, finalMatch.Id)
local _, closed = TB.Bet(t, 6, 1, 500)
TB.Report(t, finalMatch.Id, 1)
rows = TB.Results(t, 1, DRAW)
local payout = {}
for _, row in ipairs(rows) do payout[row.UserId] = row.BetPayout end
check("Finale lancée : paris fermés ; gagné → 100, perdu → 0, sans pari → rien", closed == "BETS_CLOSED"
    and payout[8] == 100 and payout[7] == 0 and payout[6] == nil and A.Tournament.BetPayout == 2)

-- Nul au temps limite : le mieux classé passe.
local m = {A = 11, B = 22, SeedA = 6, SeedB = 3}
check("Vainqueur d'après le moteur : côté A, côté B ; nul → meilleure tête de série", TB.WinnerOf(m, {Winner = "A"}) == 11
    and TB.WinnerOf(m, {Winner = "B"}) == 22 and TB.WinnerOf(m, {Winner = "Draw"}) == 22)

-- Tableau de 16 joué par le moteur et les bots.
local world1 = {}
for _, c in ipairs(C.Creatures) do if c.world == 1 then table.insert(world1, c.id) end end
math.randomseed(14)
local teams = {}
for user = 1, 16 do
    teams[user] = {}
    for slot = 1, 3 do
        local id = world1[math.random(1, #world1)]
        local s = C:GetCombatStats(id, 1, true)
        teams[user][slot] = {Id = id, HP = s.HP, ATK = s.ATK, Type = s.Type}
    end
end
t = fill(16)
local matches, seconds = 0, 0
while #TB.Pending(t) > 0 do
    for _, match in ipairs(TB.Pending(t)) do
        TB.Start(t, match.Id)
        local fight = Engine.New(teams[match.A], teams[match.B], math.random(0, 2 ^ 31 - 1))
        local brains = {A = Bot.NewBrain("Normal", 0), B = Bot.NewBrain("Normal", 0)}
        while not fight.Over do
            Bot.Decide(brains.A, fight, "A")
            Bot.Decide(brains.B, fight, "B")
            Engine.Step(fight)
            Engine.Snapshot(fight)
        end
        TB.Report(t, match.Id, TB.WinnerOf(match, Engine.Result(fight)))
        matches += 1
        seconds += fight.Clock / 10
    end
end
local losses = 0
for _, round in pairs(t.Brackets[1].Lost) do losses += 1 end
check(("Tableau de 16 joué par le moteur : 15 matchs (%.0f s de combat), un champion, 15 éliminés une fois"):format(
    seconds), matches == 15 and t.Brackets[1].Champion ~= nil and losses == 15 and t.Phase == "Done")

local summary = ("[TOURNAMENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
