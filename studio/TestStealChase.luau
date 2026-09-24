--!nonstrict
--[[ TestStealChase
     Rôle    : observer une poursuite réelle à deux joueurs et dire ce qui a déjà été vu, sans rien déclencher.
     Doc     : GAME_MASTER_V2 A4, H2 (« Poursuite à 2 joueurs OK, débutant protégé ») ;
               PROMPT_EXECUTION_SABL_V4 §18.2, §23.2 (journal), §25.2
     Étape   : 5, lot E
     Dépend  : Play serveur ; Services.StealService vivant, Services.DataService, Config.StealConfig ;
               journal [LOG][STEAL] écrit par StealService ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : état des joueurs, compte des événements du journal, jalons de la poursuite, sonde de protection
     Limite  : lecture seule, rien n'est provoqué. La sonde de protection n'est lancée que si un débutant
               est présent : le refus tombe alors avant tout effet (§18.2). Deux joueurs débloqués :
               la sonde est sautée, car un vol réel pourrait démarrer.
               Seuls comptent les événements dont les deux parties sont des joueurs réels présents :
               les batteries du vol jouent le joueur réel contre des joueurs factices, et leurs
               événements sont dans le même journal.
]]
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local DataService = require(ServerScriptService.Services.DataService)
local StealService = require(ServerScriptService.Services.StealService)

local PROTECTION = StealConfig.Protection
local IDLE = StealService.ThiefState.IDLE
local EVENTS = {"CARRY", "ABORT", "DROP", "RETURN", "PICKUP", "SECURED", "BUYBACK", "BUYBACK_CLOSED", "TELEPORT"}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function note(text) table.insert(T.lines, text) end

-- 1. Qui est là, et qui peut voler.
local profiles, beginners, unlocked = {}, {}, {}
for _, player in ipairs(Players:GetPlayers()) do
    local profile = DataService:Get(player)
    profiles[player] = profile
    local level = profile and profile.Level or 0
    local playtime = profile and profile.Playtime or 0
    local protege = level < PROTECTION.MinLevel or playtime < PROTECTION.MinPlaytimeSeconds
    table.insert(protege and beginners or unlocked, player)
    local placed = 0
    for _, creature in ipairs(profile and profile.Creatures or {}) do
        if type(creature.PlacedSlot) == "number" then placed += 1 end
    end
    note(("[JOUEUR] %s (%d) : niveau %s, %s s, %d posee(s), %s")
        :format(player.Name, player.UserId, tostring(level), tostring(playtime), placed,
            protege and "DEBUTANT PROTEGE" or "peut voler"))
end
note(("[JOUEUR] %d present(s) : %d debloque(s), %d debutant(s)")
    :format(#Players:GetPlayers(), #unlocked, #beginners))

-- 2. Ce que le journal du serveur a enregistré (§23.2).
local counts, records = {}, {}
for _, entry in ipairs(LogService:GetLogHistory()) do
    local _, userId, payload = entry.message:match("^%[LOG%]%[STEAL%]%[(.-)|(%-?%d+)%]%s(.+)$")
    if payload then
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, payload)
        if ok and type(decoded) == "table" and type(decoded.event) == "string" then
            counts[decoded.event] = (counts[decoded.event] or 0) + 1
            table.insert(records, {userId = tonumber(userId), data = decoded})
        end
    end
end
local summary = {}
for _, event in ipairs(EVENTS) do
    table.insert(summary, ("%s=%d"):format(event, counts[event] or 0))
end
note("[JOURNAL] brut : " .. table.concat(summary, " "))

-- Les batteries du vol font jouer le joueur réel contre des joueurs factices, dans ce même journal :
-- un jalon ne compte que si les deux parties sont des joueurs réels présents, et distinctes.
local realIds = {}
for _, player in ipairs(Players:GetPlayers()) do realIds[player.UserId] = true end
local function between(event, partnerField, predicate)
    for _, record in ipairs(records) do
        local partner = record.data[partnerField]
        if record.data.event == event and realIds[record.userId] and type(partner) == "number"
            and realIds[partner] and partner ~= record.userId
            and (predicate == nil or predicate(record)) then
            return true
        end
    end
    return false
end

-- 3. Les jalons d'une poursuite complète (A4) : vus ou encore à faire.
local milestones = {
    {"Vol d'un autre joueur reel (CARRY)", between("CARRY", "victim")},
    {"Trois coups : le voleur lache (DROP reason=HITS)",
        between("DROP", "victim", function(r) return r.data.reason == "HITS" end)},
    {"Brainrot ramasse au sol (PICKUP)", between("PICKUP", "victim")},
    {"Pose reussie, transfert effectif (SECURED)", between("SECURED", "victim")},
    {"Vengeance : teleportation vers le voleur (TELEPORT, Q10)", between("TELEPORT", "target")},
    {"Rachat paye par la victime (BUYBACK)", between("BUYBACK", "thief")},
}
local done = 0
for _, milestone in ipairs(milestones) do
    if milestone[2] then done += 1 end
    note((milestone[2] and "[VU] " or "[A FAIRE] ") .. milestone[1])
end
check("Loi 8 : aucun transfert echoue entre joueurs reels (ABORT reason=TRANSFER_FAILED)",
    not between("ABORT", "victim", function(r) return r.data.reason == "TRANSFER_FAILED" end))

-- 4. L'état vivant du service, tel qu'il le publie lui-même.
for _, player in ipairs(Players:GetPlayers()) do
    local session = StealService:GetSession(player)
    local offers = StealService:GetBuybacks(player)
    if session.State ~= IDLE or #offers > 0 then
        note(("[ETAT] %s : %s%s"):format(player.Name, session.State,
            #offers > 0 and (", " .. #offers .. " rachat(s) ouvert(s)") or ""))
    end
end
local drops = StealService:GetDrops()
note(("[ETAT] %d brainrot(s) au sol"):format(#drops))

-- 5. Sonde de protection : sans effet tant qu'un débutant est concerné (§18.2).
local function placedUid(player)
    for _, creature in ipairs(profiles[player] and profiles[player].Creatures or {}) do
        if type(creature.PlacedSlot) == "number" then return creature.Uid end
    end
    return nil
end

if #beginners == 0 then
    note("[SONDE] Sautee : aucun debutant present, un vol reel pourrait demarrer")
elseif #Players:GetPlayers() < 2 then
    note("[SONDE] Sautee : il faut deux joueurs")
else
    local beginner = beginners[1]
    local other = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= beginner then other = player break end
    end
    local uid = other and placedUid(other)
    if uid then
        check("A4 : un debutant ne peut pas voler (LEVEL_TOO_LOW)",
            select(2, StealService:AttemptSteal(beginner, other, uid)) == "LEVEL_TOO_LOW")
    else
        note("[SONDE] Voler : sautee, l'autre joueur n'a rien de pose")
    end
    local target = placedUid(beginner)
    if other and target and StealService:GetSession(other).State == IDLE then
        local unlockedThief = profiles[other] and profiles[other].Level >= PROTECTION.MinLevel
            and profiles[other].Playtime >= PROTECTION.MinPlaytimeSeconds
        local expected = unlockedThief and "TARGET_PROTECTED" or "LEVEL_TOO_LOW"
        check(("A4 : le debutant est protege du vol (%s)"):format(expected),
            select(2, StealService:AttemptSteal(other, beginner, target)) == expected)
    else
        note("[SONDE] Etre vole : sautee, le debutant n'a rien de pose ou l'autre porte deja")
    end
end

table.insert(T.lines, ("[CHASE TEST] %d/%d jalons vus, %d OK / %d FAIL")
    :format(done, #milestones, T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
