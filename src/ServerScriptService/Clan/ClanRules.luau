--!strict
--[[ ClanRules
     Rôle    : règles d'un clan : création, demandes d'adhésion, rôles, départs, exclusions, transfert de chef,
               dons au coffre (jamais remboursés), niveau, perk de revenus et couleur du tag.
     Doc     : GAME_MASTER_V2 F1, F2, F4, G2 ; PROMPT_EXECUTION_SABL_V4 §31.15 lots A-B ; décisions 99, 103, 104,
               133 à 137
     Étape   : 15, lots A et B
     Dépend  : Config.ClanConfig
     Exposé  : Create(profile, userId, clanId, name, tag, emblem, now) -> clan ; Request, Accept, Decline, Leave,
               Kick, Promote, Demote, Transfer, Donate, History -> (résultat, raison?) ; RoleOf(clan, userId) ;
               Count(clan) ; IncomeBonus(clan) ; TagColor(clan)
     Limite  : un clan est un enregistrement pur (DataStore des clans en session locale). Le service filtre le nom
               par TextService (§24), garantit son unicité entre serveurs et recopie Clan.Id / Clan.Role dans le
               profil de chaque membre ; ici, seul le profil de celui qui paie (création, don) est écrit. Aucune
               fusion de clans n'existe (F4).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClanConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ClanConfig"))

local ROLES = ClanConfig.Roles
local CREATION = ClanConfig.Creation

local ClanRules = {}

function ClanRules.RoleOf(clan: any, userId: any): string?
    local member = clan.Members[userId]
    return if member then member.Role else nil
end

function ClanRules.Count(clan: any): number
    local n = 0
    for _ in pairs(clan.Members) do n += 1 end
    return n
end

local function officers(clan: any): number
    local n = 0
    for _, member in pairs(clan.Members) do
        if member.Role == "Officer" then n += 1 end
    end
    return n
end

local function can(clan: any, userId: any, right: string): boolean
    local role = ClanRules.RoleOf(clan, userId)
    return role ~= nil and (ROLES :: any)[role][right] == true
end

-- F1 : 500 000 💰, nom de 3 à 16 caractères, tag de 2 à 4 lettres (affiché en majuscules), emblème 1 à 20 ;
-- le fondateur est chef.
function ClanRules.Create(profile: any, userId: any, clanId: any, name: any, tag: any, emblem: any, now: number)
    : (any, string?)
    if type(profile) ~= "table" or type(profile.Clan) ~= "table" or type(userId) ~= "number" then
        return nil, "BAD_INPUT"
    end
    if profile.Clan.Id ~= nil then return nil, "ALREADY_IN_CLAN" end
    if not ClanConfig.ValidName(name) then return nil, "BAD_NAME" end
    if not ClanConfig.ValidTag(tag) then return nil, "BAD_TAG" end
    if type(emblem) ~= "number" or emblem % 1 ~= 0 or emblem < 1 or emblem > CREATION.Emblems then
        return nil, "BAD_EMBLEM"
    end
    if type(profile.Money) ~= "number" or profile.Money < CREATION.Cost then return nil, "NOT_ENOUGH_MONEY" end
    profile.Money -= CREATION.Cost
    profile.Clan.Id, profile.Clan.Role = clanId, "Leader"
    return {
        Id = clanId, Name = name, Tag = string.upper(tag), Emblem = emblem, CreatedAt = now,
        Members = {[userId] = {Role = "Leader", JoinedAt = now}}, Requests = {},
        Donated = 0, Donations = {}, WarActive = nil, LastWarEnd = 0, Dissolved = false,
    }, nil
end

-- F1 : un joueur demande, un officier ou le chef accepte ; un seul clan par joueur, 20 membres au plus.
function ClanRules.Request(clan: any, userId: any, profile: any, now: number): (boolean, string?)
    if clan.Dissolved then return false, "NO_CLAN" end
    if type(profile) ~= "table" or type(profile.Clan) ~= "table" then return false, "BAD_INPUT" end
    if clan.Members[userId] then return false, "ALREADY_MEMBER" end
    if profile.Clan.Id ~= nil then return false, "ALREADY_IN_CLAN" end
    if ClanRules.Count(clan) >= ClanConfig.MaxMembers then return false, "CLAN_FULL" end
    if clan.Requests[userId] then return false, "ALREADY_REQUESTED" end
    clan.Requests[userId] = now
    return true, nil
end

function ClanRules.Accept(clan: any, actorId: any, userId: any, now: number): (boolean, string?)
    if not can(clan, actorId, "CanAccept") then return false, "NOT_ALLOWED" end
    if not clan.Requests[userId] then return false, "NO_REQUEST" end
    if ClanRules.Count(clan) >= ClanConfig.MaxMembers then return false, "CLAN_FULL" end
    clan.Requests[userId] = nil
    clan.Members[userId] = {Role = "Member", JoinedAt = now}
    return true, nil
end

function ClanRules.Decline(clan: any, actorId: any, userId: any): (boolean, string?)
    if not can(clan, actorId, "CanAccept") then return false, "NOT_ALLOWED" end
    if not clan.Requests[userId] then return false, "NO_REQUEST" end
    clan.Requests[userId] = nil
    return true, nil
end

-- Plus ancien membre d'un rôle (arrivée, puis identifiant), hors `except`.
local function oldest(clan: any, role: string, except: any): number?
    local best, bestAt = nil, math.huge
    for userId, member in pairs(clan.Members) do
        if userId ~= except and member.Role == role
            and (member.JoinedAt < bestAt or (member.JoinedAt == bestAt and best ~= nil and userId < best)) then
            best, bestAt = userId, member.JoinedAt
        end
    end
    return best
end

-- §31.15 : personne ne quitte pendant une guerre (WAR_ACTIVE). Q3 (B) : le chef qui part laisse sa place à
-- l'officier le plus ancien, sinon au membre le plus ancien ; seul, il dissout le clan. Les dons restent (F2).
function ClanRules.Leave(clan: any, userId: any): (any, string?)
    local member = clan.Members[userId]
    if not member then return nil, "NOT_MEMBER" end
    if clan.WarActive then return nil, "WAR_ACTIVE" end
    clan.Members[userId] = nil
    local result: any = {Left = userId}
    if member.Role == "Leader" then
        local heir = oldest(clan, "Officer", nil) or oldest(clan, "Member", nil)
        if heir then
            clan.Members[heir].Role = "Leader"
            result.NewLeader = heir
        else
            clan.Dissolved = true
            result.Dissolved = true
        end
    end
    return result, nil
end

-- Le chef exclut tout le monde, un officier seulement les membres ; jamais pendant une guerre.
function ClanRules.Kick(clan: any, actorId: any, userId: any): (boolean, string?)
    local actor, target = ClanRules.RoleOf(clan, actorId), ClanRules.RoleOf(clan, userId)
    if not target then return false, "NOT_MEMBER" end
    if clan.WarActive then return false, "WAR_ACTIVE" end
    local allowed = actorId ~= userId
        and (actor == "Leader" or (actor == "Officer" and target == "Member"))
    if not allowed then return false, "NOT_ALLOWED" end
    clan.Members[userId] = nil
    return true, nil
end

-- F1 : 3 officiers au plus, nommés par le chef.
function ClanRules.Promote(clan: any, actorId: any, userId: any): (boolean, string?)
    if ClanRules.RoleOf(clan, actorId) ~= "Leader" then return false, "NOT_ALLOWED" end
    if ClanRules.RoleOf(clan, userId) ~= "Member" then return false, "NOT_MEMBER" end
    if officers(clan) >= ROLES.Officer.Max then return false, "OFFICERS_FULL" end
    clan.Members[userId].Role = "Officer"
    return true, nil
end

function ClanRules.Demote(clan: any, actorId: any, userId: any): (boolean, string?)
    if ClanRules.RoleOf(clan, actorId) ~= "Leader" then return false, "NOT_ALLOWED" end
    if ClanRules.RoleOf(clan, userId) ~= "Officer" then return false, "NOT_OFFICER" end
    clan.Members[userId].Role = "Member"
    return true, nil
end

-- F1 : chef unique et transférable ; l'ancien chef devient officier s'il reste une place, sinon membre.
function ClanRules.Transfer(clan: any, actorId: any, userId: any): (boolean, string?)
    if ClanRules.RoleOf(clan, actorId) ~= "Leader" then return false, "NOT_ALLOWED" end
    local target = ClanRules.RoleOf(clan, userId)
    if not target or userId == actorId then return false, "NOT_MEMBER" end
    clan.Members[userId].Role = "Leader"
    clan.Members[actorId].Role = if officers(clan) < ROLES.Officer.Max then "Officer" else "Member"
    return true, nil
end

-- F2 : don en 💰 entiers, jamais remboursé ; le niveau du coffre suit le total.
function ClanRules.Donate(clan: any, profile: any, userId: any, amount: any, now: number): (any, string?)
    if not clan.Members[userId] then return nil, "NOT_MEMBER" end
    if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 1 or amount == math.huge then
        return nil, "BAD_AMOUNT"
    end
    if type(profile) ~= "table" or type(profile.Money) ~= "number" or profile.Money < amount then
        return nil, "NOT_ENOUGH_MONEY"
    end
    local before = ClanConfig.ChestLevel(clan.Donated)
    profile.Money -= amount
    profile.Clan.Donated = (profile.Clan.Donated or 0) + amount
    clan.Donated += amount
    table.insert(clan.Donations, {UserId = userId, Amount = amount, At = now})
    return {LevelBefore = before, Level = ClanConfig.ChestLevel(clan.Donated), Donated = clan.Donated}, nil
end

-- F2 : l'historique des dons n'est visible que du chef et des officiers.
function ClanRules.History(clan: any, actorId: any): (any, string?)
    local role = ClanRules.RoleOf(clan, actorId)
    if role ~= "Leader" and role ~= "Officer" then return nil, "NOT_ALLOWED" end
    return table.clone(clan.Donations), nil
end

function ClanRules.IncomeBonus(clan: any): number
    return ClanConfig.ChestBonus(clan.Donated)
end

function ClanRules.TagColor(clan: any): string
    local level = ClanConfig.ChestLevel(clan.Donated)
    return if level > 0 then (ClanConfig.ChestLevels :: any)[level].TagColor else ClanConfig.NoLevelTagColor
end

return table.freeze(ClanRules)
