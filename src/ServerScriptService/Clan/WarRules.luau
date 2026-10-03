--!strict
--[[ WarRules
     Rôle    : guerre de territoire : déclaration (F4), appariement par somme des Elo, points des 3 fronts avec
               l'anti-abus des 30 min, cérémonie du jeudi (récompenses, MVP) versée une seule fois.
     Doc     : GAME_MASTER_V2 F3, F4, E6 ; PROMPT_EXECUTION_SABL_V4 §31.15 lots D-G ; décisions 100 à 104, 133 à 137
     Étape   : 15, lots D à G
     Dépend  : Config.ClanConfig (War, AntiAbuse, WarAt, points des fronts, CanScore, Winner)
     Exposé  : Strength(members, now) -> (somme Elo, actifs) ; Declare(clan, actorId, active, now) ;
               Pair(entries) -> (paires, sans adversaire) ; Start(clanA, clanB, keyA, keyB, now) -> guerre ;
               Duel(war, winner, loser) ; Flag(war, side, userId, play) ; BossHit(war, side, userId, damage) ;
               Totals(war) ; Ceremony(war, clanA, clanB, now) -> bilan | (nil, raison)
     Limite  : aucune Instance : WarService (session locale) mesure le temps de jeu de guerre, lance les duels
               (CombatEngine), signale les drapeaux (StealService:StealFlag, G5.7) et les dégâts du boss, puis
               verse le bilan. Les clans sont les enregistrements de ClanRules.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClanConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClanConfig"))

local WAR = ClanConfig.War
local ABUSE = ClanConfig.AntiAbuse
local DAY = 86400
local MAX_FLAGS = WAR.Steal.Max // WAR.Steal.PerFlag

local WarRules = {}

-- F3 / F4 / Q1 (A) : force d'un clan = somme des Elo 1v1 de ses membres actifs (vus dans les 7 derniers jours).
-- members = {{Elo = n, LastSeen = t}, …}
function WarRules.Strength(members: any, now: number): (number, number)
    local sum, active = 0, 0
    for _, m in ipairs(members) do
        if type(m.LastSeen) == "number" and now - m.LastSeen <= ABUSE.ActiveWindow then
            sum += m.Elo or 0
            active += 1
        end
    end
    return sum, active
end

-- F4 : un officier (ou le chef) déclare ; une guerre à la fois ; 24 h de pause après la précédente ; 5 membres
-- actifs au moins ; on déclare pour la prochaine guerre, pas pendant une guerre en cours.
function WarRules.Declare(clan: any, actorId: any, active: number, now: number): (boolean, string?)
    local member = clan.Members[actorId]
    if not member or not (ClanConfig.Roles :: any)[member.Role].CanDeclareWar then return false, "NOT_ALLOWED" end
    if clan.WarActive then return false, "WAR_ACTIVE" end
    if now < (clan.LastWarEnd or 0) + ABUSE.CooldownAfterWar then return false, "COOLDOWN" end
    if active < ABUSE.MinActiveMembers then return false, "TOO_FEW_ACTIVE" end
    local running, start = ClanConfig.WarAt(now)
    if running then return false, "WAR_RUNNING" end
    if clan.DeclaredFor == start then return false, "ALREADY_DECLARED" end
    clan.DeclaredFor = start
    return true, nil
end

-- Q1 (A) : au dimanche 20:00, les clans déclarés sont triés par force et appariés voisins ; le dernier d'un nombre
-- impair reste sans adversaire et redéclare la semaine suivante. entries = {{Key = …, Strength = n}, …}
function WarRules.Pair(entries: any): ({any}, any)
    local sorted = table.clone(entries)
    table.sort(sorted, function(a: any, b: any): boolean
        if a.Strength ~= b.Strength then return a.Strength > b.Strength end
        return tostring(a.Key) < tostring(b.Key)
    end)
    local pairs_ = {}
    for i = 1, #sorted - 1, 2 do table.insert(pairs_, {A = sorted[i].Key, B = sorted[i + 1].Key}) end
    return pairs_, if #sorted % 2 == 1 then sorted[#sorted].Key else nil
end

-- Ouvre la guerre entre deux clans appariés : ni départ ni exclusion jusqu'à la cérémonie (§31.15).
function WarRules.Start(clanA: any, clanB: any, keyA: any, keyB: any, now: number): any
    local _, start, finish = ClanConfig.WarAt(now)
    local war = {
        Keys = {A = keyA, B = keyB}, StartAt = start, EndAt = finish, Closed = false, Seq = 0,
        Sides = {A = {Duels = 0, Flags = 0, BossDamage = 0, ArenaPoints = 0},
            B = {Duels = 0, Flags = 0, BossDamage = 0, ArenaPoints = 0}},
        Members = {},
    }
    clanA.WarActive, clanB.WarActive = war, war
    clanA.DeclaredFor, clanB.DeclaredFor = nil, nil
    return war
end

local function record(war: any, side: string, userId: any): any
    local m = war.Members[userId]
    if not m then
        m = {Side = side, Arena = 0, Flags = 0, BossDamage = 0, Reached = {}}
        war.Members[userId] = m
    end
    return m
end

local function reached(war: any, m: any, front: string)
    war.Seq += 1
    m.Reached[front] = war.Seq
end

-- Front 1 : un duel de guerre (75 au vainqueur, 15 au vaincu), 5 duels par clan ; un combattant sans ses 30 min
-- de jeu de guerre ne marque pas, mais son duel compte (F4). winner / loser = {Side, UserId, Play}
function WarRules.Duel(war: any, winner: any, loser: any): (boolean, string?)
    if war.Closed then return false, "WAR_OVER" end
    if (winner.Side ~= "A" and winner.Side ~= "B") or loser.Side == winner.Side
        or (loser.Side ~= "A" and loser.Side ~= "B") then
        return false, "BAD_INPUT"
    end
    if war.Sides.A.Duels >= WAR.Arena.Duels or war.Sides.B.Duels >= WAR.Arena.Duels then return false, "DUELS_DONE" end
    war.Sides.A.Duels += 1
    war.Sides.B.Duels += 1
    for _, fighter in ipairs({{winner, WAR.Arena.Win}, {loser, WAR.Arena.Loss}}) do
        local who, points = fighter[1], fighter[2]
        if ClanConfig.CanScore("Arena", who.Play) then
            local m = record(war, who.Side, who.UserId)
            m.Arena += points
            war.Sides[who.Side].ArenaPoints += points
            reached(war, m, "Arena")
        end
    end
    return true, nil
end

-- Front 2 : 50 points par drapeau rapporté, 10 drapeaux au plus par clan ; 30 min de jeu de guerre (F4).
function WarRules.Flag(war: any, side: any, userId: any, play: any): (boolean, string?)
    if war.Closed then return false, "WAR_OVER" end
    if side ~= "A" and side ~= "B" then return false, "BAD_INPUT" end
    if not ClanConfig.CanScore("Steal", play) then return false, "NOT_ENOUGH_PLAY" end
    if war.Sides[side].Flags >= MAX_FLAGS then return false, "FRONT_FULL" end
    war.Sides[side].Flags += 1
    local m = record(war, side, userId)
    m.Flags += 1
    reached(war, m, "Steal")
    return true, nil
end

-- Front 3 : dégâts au boss de guerre, sans condition de temps de jeu (F4 ne vise que les fronts 1 et 2).
function WarRules.BossHit(war: any, side: any, userId: any, damage: any): (boolean, string?)
    if war.Closed then return false, "WAR_OVER" end
    if side ~= "A" and side ~= "B" then return false, "BAD_INPUT" end
    if type(damage) ~= "number" or not (damage > 0) or damage == math.huge then return false, "BAD_INPUT" end
    war.Sides[side].BossDamage += damage
    local m = record(war, side, userId)
    m.BossDamage += damage
    reached(war, m, "Boss")
    return true, nil
end

function WarRules.Totals(war: any): any
    local bossA, bossB = ClanConfig.BossFrontPoints(war.Sides.A.BossDamage, war.Sides.B.BossDamage)
    local out = {}
    for side, boss in pairs({A = bossA, B = bossB}) do
        local s = war.Sides[side]
        local steal = ClanConfig.StealFrontPoints(s.Flags)
        out[side] = {Arena = s.ArenaPoints, Steal = steal, Boss = boss, Total = s.ArenaPoints + steal + boss}
    end
    return out
end

-- Points d'un membre : duels, drapeaux, et sa part des points Boss de son clan (au prorata de ses dégâts).
local function memberPoints(war: any, totals: any, m: any): number
    local side = war.Sides[m.Side]
    local boss = if side.BossDamage > 0 then totals[m.Side].Boss * m.BossDamage / side.BossDamage else 0
    return m.Arena + m.Flags * WAR.Steal.PerFlag + math.floor(boss + 0.5)
end

-- Q2 (A) : un MVP par front, tous clans confondus ; égalité → le premier à avoir atteint ce score.
local function mvp(war: any, field: string, front: string): any
    local best, bestValue, bestSeq = nil, 0, math.huge
    for userId, m in pairs(war.Members) do
        local value, seq = m[field], m.Reached[front] or math.huge
        if value > bestValue or (value == bestValue and value > 0 and seq < bestSeq) then
            best, bestValue, bestSeq = userId, value, seq
        end
    end
    return best
end

-- F3 : cérémonie du jeudi 20:00, une seule fois. Membres présents dans chaque clan à ce moment : gagnant 400
-- tokens + 250 K 💰 (+ 1 egg_mythic s'il a marqué), perdant 100 + 50 K ; égalité : les deux comme le gagnant.
function WarRules.Ceremony(war: any, clanA: any, clanB: any, now: number): (any, string?)
    if war.Closed then return nil, "ALREADY_DONE" end
    if now < war.EndAt then return nil, "TOO_EARLY" end
    local totals = WarRules.Totals(war)
    local winner = ClanConfig.Winner(totals.A.Total, totals.B.Total)
    local rewards = {}
    local sides: {[string]: any} = {A = clanA, B = clanB}
    for side, clan in pairs(sides) do
        local wins = winner == side or (winner == "Tie" and WAR.Rewards.TieGivesWinner)
        local reward = if wins then WAR.Rewards.Winner else WAR.Rewards.Loser
        for userId in pairs(clan.Members) do
            local m = war.Members[userId]
            local scored = m ~= nil and m.Side == side and memberPoints(war, totals, m) >= 1
            rewards[userId] = {Side = side, ArenaTokens = reward.ArenaTokens, Money = reward.Money,
                Eggs = if scored then reward.ScorerEggs else nil,
                Points = if m and m.Side == side then memberPoints(war, totals, m) else 0}
        end
        clan.WarActive, clan.LastWarEnd = nil, war.EndAt
    end
    local until_ = now + WAR.Rewards.MvpPoseDays * DAY
    local mvps = {}
    for _, front in ipairs({{"Arena", "Arena"}, {"Flags", "Steal"}, {"BossDamage", "Boss"}}) do
        local userId = mvp(war, front[1], front[2])
        if userId then table.insert(mvps, {Front = front[2], UserId = userId, Until = until_}) end
    end
    war.Closed = true
    return {Winner = winner, Totals = totals, Rewards = rewards, Mvps = mvps}, nil
end

return table.freeze(WarRules)
