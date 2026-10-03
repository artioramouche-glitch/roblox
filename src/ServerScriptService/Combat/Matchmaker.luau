--!strict
--[[ Matchmaker
     Rôle    : file d'attente d'un format d'arène : accès (niveau, match en cours, équipe A), appariement par Elo
               à marge croissante, bot proposé après 30 s, bots imposés des 3 premiers matchs et du garde-fou.
     Doc     : GAME_MASTER_V2 G5.5, E1, E2, E6, E11.4 ; PROMPT_EXECUTION_SABL_V4 §31.13 lot D ; décisions 113, 123
               à 126, 138 à 142
     Étape   : 13, lot D ; file 2v2 (dette 33)
     Dépend  : Config.ArenaConfig (Matchmaking, Bots)
     Exposé  : CanJoin(profile, inMatch) -> (ok, raison?) ; BotKind(profile) -> "Tutorial" | "Guard" | "Normal" ;
               Range(attente) ; New() -> file ; Join(file, userId, elo, botKind, now) ; Leave(file, userId) ;
               Tick(file, now) -> {Matches, Offers} ; AcceptBot(file, userId) ; DeclineBot(file, userId) ; Size(file) ;
               2v2 : JoinParty(file, {ids}, {elos}, now), Tick2v2(file, now)
     Limite  : aucune Instance, aucun remote : ArenaService (session locale) appelle Tick toutes les 5 s avec son
               horloge, montre les offres de bot, crée les matchs et téléporte les joueurs. Une file sert un seul
               format : Join + Tick en 1v1, JoinParty + Tick2v2 en 2v2 (pas de bot imposé en 2v2, décision 142).
               Le champ PvP.LossStreak naîtra avec le schéma v4 ; absent, il vaut 0.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ArenaConfig"))

local MM = ArenaConfig.Matchmaking
local BOTS = ArenaConfig.Bots

type Entry = {UserId: number, Elo: number, JoinedAt: number, Bot: string, OfferedAt: number?, Pending: boolean,
    Members: {number}?}
export type Queue = {Entries: {Entry}}

local Matchmaker = {}

-- G5.5 : niveau 5, pas de match en cours, équipe A complète de 3 brainrots distincts possédés.
function Matchmaker.CanJoin(profile: any, inMatch: boolean?): (boolean, string?)
    if type(profile) ~= "table" or type(profile.PvP) ~= "table" then return false, "NO_PROFILE" end
    if type(profile.Level) ~= "number" or profile.Level < MM.MinLevel then return false, "LEVEL_TOO_LOW" end
    if inMatch then return false, "IN_MATCH" end
    local loadout = type(profile.PvP.Loadouts) == "table" and profile.PvP.Loadouts.A
    if type(loadout) ~= "table" then return false, "LOADOUT_INCOMPLETE" end
    local owned: {[string]: boolean} = {}
    for _, creature in ipairs(profile.Creatures or {}) do
        if type(creature) == "table" and type(creature.Uid) == "string" then owned[creature.Uid] = true end
    end
    local seen: {[string]: boolean} = {}
    for slot = 1, ArenaConfig.Match.TeamSize do
        local uid = loadout[slot]
        if type(uid) ~= "string" or not owned[uid] or seen[uid] then return false, "LOADOUT_INCOMPLETE" end
        seen[uid] = true
    end
    return true, nil
end

-- E1 : bots faciles pour les 3 premiers matchs ; E6 / E11.4 : garde-fou après 3 défaites classées de suite.
function Matchmaker.BotKind(profile: any): string
    local stats = type(profile) == "table" and profile.Stats or nil
    local played = if type(stats) == "table" then (stats.ArenaWins or 0) + (stats.ArenaLosses or 0) else 0
    if played < BOTS.TutorialMatches then return "Tutorial" end
    local pvp = type(profile) == "table" and profile.PvP or nil
    local streak = if type(pvp) == "table" then pvp.LossStreak or 0 else 0
    if streak >= BOTS.GuardLossStreak then return "Guard" end
    return "Normal"
end

-- E6 : ±150 Elo, +50 par tranche pleine de 20 s d'attente, ±400 au plus.
function Matchmaker.Range(waitSeconds: number): number
    local steps = math.floor(math.max(0, waitSeconds) / MM.RangeStepSeconds)
    return math.min(MM.MaxRange, MM.BaseRange + MM.RangeStep * steps)
end

function Matchmaker.New(): Queue
    return {Entries = {}}
end

local function find(queue: Queue, userId: any): (Entry?, number?)
    for i, entry in ipairs(queue.Entries) do
        if entry.UserId == userId then return entry, i end
        if entry.Members and table.find(entry.Members, userId) then return entry, i end
    end
    return nil, nil
end

function Matchmaker.Join(queue: Queue, userId: any, elo: any, botKind: any, now: number): (boolean, string?)
    if type(userId) ~= "number" or type(elo) ~= "number" or elo ~= elo then return false, "BAD_INPUT" end
    if botKind ~= "Tutorial" and botKind ~= "Guard" and botKind ~= "Normal" then return false, "BAD_INPUT" end
    if find(queue, userId) then return false, "ALREADY_QUEUED" end
    table.insert(queue.Entries, {UserId = userId, Elo = elo, JoinedAt = now, Bot = botKind, OfferedAt = nil,
        Pending = false})
    return true, nil
end

function Matchmaker.Leave(queue: Queue, userId: any): boolean
    local _, index = find(queue, userId)
    if not index then return false end
    table.remove(queue.Entries, index)
    return true
end

function Matchmaker.Size(queue: Queue): number
    return #queue.Entries
end

-- G5.5 : un passage de la file. Les bots imposés partent tout de suite ; les autres sont triés par Elo et
-- appariés deux à deux, voisins d'abord, si leur écart tient dans la marge de celui qui attend depuis le plus
-- longtemps (décision 126). Ceux qui attendent depuis 30 s reçoivent une offre de bot, renouvelée toutes les 30 s.
function Matchmaker.Tick(queue: Queue, now: number): any
    local matches: {any}, offers: {number} = {}, {}
    local waiting: {Entry} = {}
    for _, entry in ipairs(queue.Entries) do
        if entry.Bot ~= "Normal" then
            table.insert(matches, {Kind = "Bot", A = entry.UserId, Bot = entry.Bot})
        else
            table.insert(waiting, entry)
        end
    end
    table.sort(waiting, function(a: Entry, b: Entry): boolean
        if a.Elo ~= b.Elo then return a.Elo < b.Elo end
        if a.JoinedAt ~= b.JoinedAt then return a.JoinedAt < b.JoinedAt end
        return a.UserId < b.UserId
    end)
    local left: {Entry} = {}
    local i = 1
    while i <= #waiting do
        local a, b = waiting[i], waiting[i + 1]
        if b and math.abs(a.Elo - b.Elo) <= Matchmaker.Range(now - math.min(a.JoinedAt, b.JoinedAt)) then
            table.insert(matches, {Kind = "Human", A = a.UserId, B = b.UserId})
            i += 2
        else
            table.insert(left, a)
            i += 1
        end
    end
    for _, entry in ipairs(left) do
        local offerDue = entry.OfferedAt == nil or now - entry.OfferedAt >= MM.BotOfferSeconds
        if not entry.Pending and now - entry.JoinedAt >= MM.BotOfferSeconds and offerDue then
            entry.Pending, entry.OfferedAt = true, now
            table.insert(offers, entry.UserId)
        end
    end
    -- La file ne garde que ceux qui n'ont pas trouvé de match, dans leur ordre d'arrivée.
    table.sort(left, function(a: Entry, b: Entry): boolean
        if a.JoinedAt ~= b.JoinedAt then return a.JoinedAt < b.JoinedAt end
        return a.UserId < b.UserId
    end)
    queue.Entries = left
    return {Matches = matches, Offers = offers}
end

-- E1 : l'offre de bot se refuse ; refusée, le joueur garde sa place et son attente. En 2v2, les places vides
-- (partenaire et adversaires) sont prises par des bots normaux.
function Matchmaker.AcceptBot(queue: Queue, userId: any): (any, string?)
    local entry, index = find(queue, userId)
    if not entry or not index or not entry.Pending then return nil, "NO_OFFER" end
    table.remove(queue.Entries, index)
    if entry.Members then
        return {Kind = "Bot", A = table.clone(entry.Members), Bot = "Normal", Bots = 4 - #entry.Members}, nil
    end
    return {Kind = "Bot", A = entry.UserId, Bot = "Normal"}, nil
end

function Matchmaker.DeclineBot(queue: Queue, userId: any): (boolean, string?)
    local entry = find(queue, userId)
    if not entry or not entry.Pending then return false, "NO_OFFER" end
    entry.Pending = false
    return true, nil
end

-- E2 / E6 : file 2v2. Un joueur seul ou un duo d'amis (« co-équipier = ami OU tirage »), avec leurs Elo 2v2 ; le
-- duo est classé à la moyenne de ses deux Elo (Q2 A).
function Matchmaker.JoinParty(queue: Queue, members: any, elos: any, now: number): (boolean, string?)
    if type(members) ~= "table" or type(elos) ~= "table" or #members < 1 or #members > 2 or #elos ~= #members then
        return false, "BAD_INPUT"
    end
    local sum = 0
    for i, userId in ipairs(members) do
        local elo = elos[i]
        if type(userId) ~= "number" or type(elo) ~= "number" or elo ~= elo then return false, "BAD_INPUT" end
        if find(queue, userId) or (i == 2 and userId == members[1]) then return false, "ALREADY_QUEUED" end
        sum += elo
    end
    table.insert(queue.Entries, {UserId = members[1], Elo = sum / #members, JoinedAt = now, Bot = "Normal",
        OfferedAt = nil, Pending = false, Members = table.clone(members)})
    return true, nil
end

local function byElo(a: any, b: any): boolean
    if a.Elo ~= b.Elo then return a.Elo < b.Elo end
    if a.JoinedAt ~= b.JoinedAt then return a.JoinedAt < b.JoinedAt end
    return a.UserId < b.UserId
end

-- Appariement de voisins après tri par Elo, dans la marge de la plus longue attente des deux (décision 126).
local function pairUp(items: {any}, now: number): ({any}, {any})
    table.sort(items, byElo)
    local paired, left = {}, {}
    local i = 1
    while i <= #items do
        local a, b = items[i], items[i + 1]
        if b and math.abs(a.Elo - b.Elo) <= Matchmaker.Range(now - math.min(a.JoinedAt, b.JoinedAt)) then
            table.insert(paired, {a, b})
            i += 2
        else
            table.insert(left, a)
            i += 1
        end
    end
    return paired, left
end

-- Un passage de la file 2v2 : les joueurs seuls forment des duos de voisins d'Elo, puis les duos (d'amis ou
-- formés) s'affrontent par voisins de moyenne ; offres de bot à 30 s comme en 1v1.
function Matchmaker.Tick2v2(queue: Queue, now: number): any
    local teams, solos = {}, {}
    for _, entry in ipairs(queue.Entries) do
        if entry.Members and #entry.Members == 2 then
            table.insert(teams, {Elo = entry.Elo, JoinedAt = entry.JoinedAt, UserId = entry.UserId, Entries = {entry}})
        else
            table.insert(solos, entry)
        end
    end
    local duos, lonely = pairUp(solos, now)
    for _, pair in ipairs(duos) do
        table.insert(teams, {Elo = (pair[1].Elo + pair[2].Elo) / 2, JoinedAt = math.min(pair[1].JoinedAt,
            pair[2].JoinedAt), UserId = math.min(pair[1].UserId, pair[2].UserId), Entries = pair})
    end
    local fights, spare = pairUp(teams, now)
    local matches: {any}, offers: {number} = {}, {}
    local function ids(team: any): {number}
        local out = {}
        for _, entry in ipairs(team.Entries) do
            for _, userId in ipairs(entry.Members :: {number}) do table.insert(out, userId) end
        end
        return out
    end
    for _, fight in ipairs(fights) do table.insert(matches, {Kind = "Human", A = ids(fight[1]), B = ids(fight[2])}) end
    local left: {Entry} = table.clone(lonely)
    for _, team in ipairs(spare) do
        for _, entry in ipairs(team.Entries) do table.insert(left, entry) end
    end
    for _, entry in ipairs(left) do
        local offerDue = entry.OfferedAt == nil or now - entry.OfferedAt >= MM.BotOfferSeconds
        if not entry.Pending and now - entry.JoinedAt >= MM.BotOfferSeconds and offerDue then
            entry.Pending, entry.OfferedAt = true, now
            table.insert(offers, entry.UserId)
        end
    end
    table.sort(left, function(a: Entry, b: Entry): boolean
        if a.JoinedAt ~= b.JoinedAt then return a.JoinedAt < b.JoinedAt end
        return a.UserId < b.UserId
    end)
    queue.Entries = left
    return {Matches = matches, Offers = offers}
end

return table.freeze(Matchmaker)
