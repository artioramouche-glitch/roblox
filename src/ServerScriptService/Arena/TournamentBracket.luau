--!strict
--[[ TournamentBracket
     Rôle    : Tournoi du Samedi (E9) : inscriptions, tableaux de 8 ou 16 par Elo avec passages directs pour les
               mieux classés, progression, paris sur la finale et récompenses du meilleur tour atteint.
     Doc     : GAME_MASTER_V2 E9, E6, E10 ; PROMPT_EXECUTION_SABL_V4 §31.14 lot E ; décisions 95, 128 à 132
     Étape   : 14, lot E
     Dépend  : Config.ArenaConfig (Tournament, TournamentAt, RewardWorld)
     Exposé  : New(now) ; Register(t, userId, elo, now) ; Withdraw(t, userId) ; Draw(t, now) ; Pending(t) ;
               Start(t, matchId) ; Report(t, matchId, winner) ; WinnerOf(match, result) ; Bet(t, userId, pick,
               tokens) -> mise à débiter ; Results(t, index, now)
     Limite  : ni Instance ni horloge propre : TournamentService (session locale) envoie chaque tableau sur un
               serveur de tournoi, lance les matchs (1v1 classés : Elo par ArenaRewards), débite les mises et verse
               les récompenses. Un tableau inachevé à 18:30 n'est pas traité ici.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ArenaConfig"))

local TOUR = ArenaConfig.Tournament
local DAY = 86400

local TournamentBracket = {}

-- Placement classique : 1 contre 16, 8 contre 9… ; les deux premiers ne se croisent qu'en finale.
local function seedOrder(size: number): {number}
    local order = {1}
    while #order < size do
        local count = #order * 2
        local nextOrder = {}
        for _, seed in ipairs(order) do
            table.insert(nextOrder, seed)
            table.insert(nextOrder, count + 1 - seed)
        end
        order = nextOrder
    end
    return order
end

function TournamentBracket.New(now: number): any
    local _, registration, bracketAt, finish = ArenaConfig.TournamentAt(now)
    return {
        RegistrationAt = registration, BracketAt = bracketAt, EndAt = finish, Phase = "Registration",
        Entrants = {}, Count = 0, Brackets = {}, Matches = {}, ByUser = {},
    }
end

-- E9 : inscription le samedi de 17:30 à 17:45 (Paris), Elo ≥ 1100, une seule fois.
function TournamentBracket.Register(t: any, userId: any, elo: any, now: number): (boolean, string?)
    if type(userId) ~= "number" or type(elo) ~= "number" or elo ~= elo then return false, "BAD_INPUT" end
    if t.Phase ~= "Registration" or now < t.RegistrationAt or now >= t.BracketAt then
        return false, "REGISTRATION_CLOSED"
    end
    if elo < TOUR.MinElo then return false, "ELO_TOO_LOW" end
    for _, entrant: any in ipairs(t.Entrants) do
        if entrant.UserId == userId then return false, "ALREADY_REGISTERED" end
    end
    t.Count += 1
    table.insert(t.Entrants, {UserId = userId, Elo = elo, Order = t.Count})
    return true, nil
end

function TournamentBracket.Withdraw(t: any, userId: any): boolean
    if t.Phase ~= "Registration" then return false end
    for i, entrant: any in ipairs(t.Entrants) do
        if entrant.UserId == userId then
            table.remove(t.Entrants, i)
            return true
        end
    end
    return false
end

-- Passages directs et tours joués : un match à une seule place occupée est gagné d'office.
local function resolve(t: any, bracket: any)
    for round = 1, bracket.Rounds do
        for slot, match in ipairs(bracket.Matches[round]) do
            if not match.Done then
                if round > 1 then
                    local left, right = bracket.Matches[round - 1][2 * slot - 1], bracket.Matches[round - 1][2 * slot]
                    if not (left.Done and right.Done) then continue end
                    match.A, match.SeedA = left.Winner, left.WinnerSeed
                    match.B, match.SeedB = right.Winner, right.WinnerSeed
                end
                if match.A == nil or match.B == nil then
                    match.Done, match.Bye = true, true
                    match.Winner = if match.A ~= nil then match.A else match.B
                    match.WinnerSeed = if match.A ~= nil then match.SeedA
                        elseif match.B ~= nil then match.SeedB else nil
                end
            end
        end
    end
    local final = bracket.Matches[bracket.Rounds][1]
    if final.Done then bracket.Champion, bracket.Done = final.Winner, true end
end

local function build(t: any, index: number, players: {any})
    local size = TOUR.Sizes[#TOUR.Sizes]
    for _, candidate: number in ipairs(TOUR.Sizes :: {number}) do
        if candidate >= #players then
            size = candidate
            break
        end
    end
    local rounds, span = 0, 1
    while span < size do span, rounds = span * 2, rounds + 1 end
    local bracket = {Index = index, Size = size, Rounds = rounds, Players = {}, Seed = {}, Lost = {}, Bets = {},
        Matches = {}, Champion = nil, Done = false}
    for seed, entrant in ipairs(players) do
        bracket.Players[seed], bracket.Seed[entrant.UserId] = entrant.UserId, seed
        t.ByUser[entrant.UserId] = bracket
    end
    local order = seedOrder(size)
    for round = 1, rounds do
        bracket.Matches[round] = {}
        for slot = 1, size // (2 ^ round) do
            local match: any = {Id = index .. "-" .. round .. "-" .. slot, Bracket = index, Round = round,
                Slot = slot, Done = false, Started = false}
            if round == 1 then
                match.SeedA, match.SeedB = order[2 * slot - 1], order[2 * slot]
                match.A, match.B = bracket.Players[match.SeedA], bracket.Players[match.SeedB]
            end
            bracket.Matches[round][slot] = match
            t.Matches[match.Id] = match
        end
    end
    t.Brackets[index] = bracket
    resolve(t, bracket)
end

-- E9 / Q1 (A) : à 17:45, tableaux de 16 remplis par ordre d'Elo, le dernier de 8 ou 16 places ; sous 4 inscrits,
-- le tournoi est annulé ; un dernier tableau de moins de 4 joueurs partage les inscrits avec le précédent.
function TournamentBracket.Draw(t: any, now: number): (boolean, string?)
    if t.Phase ~= "Registration" then return false, "ALREADY_DRAWN" end
    if now < t.BracketAt then return false, "TOO_EARLY" end
    local entrants = table.clone(t.Entrants)
    if #entrants < TOUR.MinPlayers then
        t.Phase = "Cancelled"
        return true, nil
    end
    table.sort(entrants, function(a: any, b: any): boolean
        if a.Elo ~= b.Elo then return a.Elo > b.Elo end
        return a.Order < b.Order
    end)
    local maxSize = TOUR.Sizes[#TOUR.Sizes]
    local counts: {number} = {}
    local remaining = #entrants
    while remaining > 0 do
        local take = math.min(maxSize, remaining)
        table.insert(counts, take)
        remaining -= take
    end
    if #counts >= 2 and counts[#counts] < TOUR.MinPlayers then
        local total = counts[#counts] + counts[#counts - 1]
        counts[#counts - 1], counts[#counts] = math.ceil(total / 2), math.floor(total / 2)
    end
    local first = 1
    for index, count in ipairs(counts) do
        build(t, index, table.move(entrants, first, first + count - 1, 1, {}))
        first += count
    end
    t.Phase = "Running"
    return true, nil
end

-- Matchs prêts à jouer (deux joueurs connus, pas encore lancés).
function TournamentBracket.Pending(t: any): {any}
    local out = {}
    for _, bracket in ipairs(t.Brackets) do
        for _, round in ipairs(bracket.Matches) do
            for _, match in ipairs(round) do
                if not match.Done and not match.Started and match.A ~= nil and match.B ~= nil then
                    table.insert(out, match)
                end
            end
        end
    end
    return out
end

local function playable(t: any, matchId: any): (any, string?)
    local match = t.Matches[matchId]
    if not match then return nil, "UNKNOWN_MATCH" end
    if match.Done then return nil, "ALREADY_REPORTED" end
    if match.A == nil or match.B == nil then return nil, "NOT_READY" end
    return match, nil
end

-- Lance un match : pour la finale, les paris se ferment.
function TournamentBracket.Start(t: any, matchId: any): (boolean, string?)
    local match, why = playable(t, matchId)
    if not match then return false, why end
    match.Started = true
    return true, nil
end

-- Vainqueur d'un match à partir du bilan du moteur (côté A = match.A) ; un nul fait passer le mieux classé.
function TournamentBracket.WinnerOf(match: any, result: any): number
    if result.Winner == "A" then return match.A end
    if result.Winner == "B" then return match.B end
    return if match.SeedA < match.SeedB then match.A else match.B
end

function TournamentBracket.Report(t: any, matchId: any, winner: any): (boolean, string?)
    local match, why = playable(t, matchId)
    if not match then return false, why end
    if winner ~= match.A and winner ~= match.B then return false, "BAD_WINNER" end
    local bracket = t.Brackets[match.Bracket]
    match.Done, match.Started, match.Winner = true, true, winner
    match.WinnerSeed = if winner == match.A then match.SeedA else match.SeedB
    bracket.Lost[if winner == match.A then match.B else match.A] = match.Round
    resolve(t, bracket)
    local allDone = true
    for _, other in ipairs(t.Brackets) do allDone = allDone and other.Done end
    if allDone then t.Phase = "Done" end
    return true, nil
end

-- E9 / Q3 (A) : un éliminé du tableau parie une fois 50 tokens sur l'un des deux finalistes, avant la finale.
function TournamentBracket.Bet(t: any, userId: any, pick: any, tokens: any): (number?, string?)
    local bracket = t.ByUser[userId]
    if not bracket then return nil, "NOT_ENTRANT" end
    if not bracket.Lost[userId] then return nil, "NOT_ELIMINATED" end
    local final = bracket.Matches[bracket.Rounds][1]
    if final.Done or final.Started or final.A == nil or final.B == nil then return nil, "BETS_CLOSED" end
    if bracket.Bets[userId] then return nil, "ALREADY_BET" end
    if pick ~= final.A and pick ~= final.B then return nil, "BAD_PICK" end
    if type(tokens) ~= "number" or tokens < TOUR.Bet then return nil, "NOT_ENOUGH_TOKENS" end
    bracket.Bets[userId] = {Pick = pick, Stake = TOUR.Bet}
    return TOUR.Bet, nil
end

-- E9 / Q2 (A) : seule la récompense du meilleur tour atteint ; paris : mise × 2 si le favori l'emporte, 0 sinon.
function TournamentBracket.Results(t: any, index: number, now: number): (any, string?)
    local bracket = t.Brackets[index]
    if not bracket or not bracket.Done then return nil, "NOT_FINISHED" end
    local stages = {[bracket.Rounds] = "Finalist", [bracket.Rounds - 1] = "Top4", [bracket.Rounds - 2] = "Top8"}
    local out = {}
    for _, userId in ipairs(bracket.Players) do
        local stage = if userId == bracket.Champion then "Champion" else stages[bracket.Lost[userId] or 0]
        local reward = if stage then TOUR.Rewards[stage] else nil
        local row: any = {UserId = userId, Stage = stage, ArenaTokens = reward and reward.ArenaTokens or 0}
        if reward then
            row.Eggs = reward.Eggs
            if reward.Rarity then row.Rarity, row.World = reward.Rarity, ArenaConfig.RewardWorld end
            if reward.Title then row.Title = {Name = reward.Title, Until = now + reward.TitleDays * DAY} end
        end
        local bet = bracket.Bets[userId]
        if bet then row.BetPayout = if bet.Pick == bracket.Champion then bet.Stake * TOUR.BetPayout else 0 end
        table.insert(out, row)
    end
    return out, nil
end

return table.freeze(TournamentBracket)
