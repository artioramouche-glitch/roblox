--!nonstrict
--[[ TestClanRules
     Rôle    : vérifier les règles d'un clan : création, adhésion, rôles, départs (Q3 B), exclusions, transfert,
               dons non remboursables, niveau du coffre, perk et tag.
     Doc     : GAME_MASTER_V2 F1, F2, F4 ; PROMPT_EXECUTION_SABL_V4 §31.15 (tests « Création », « Don », « Perk niveau
               3 », « Quitter en pleine guerre ») ; décisions 99, 133 à 137
     Étape   : 15, lots A et B
     Dépend  : ServerScriptService.Clan.ClanRules ; ReplicatedStorage.Config (ClanConfig, DefaultProfile)
     Exposé  : exécution manuelle ; écrit seulement dans des copies locales de profils et de clans
     Limite  : le filtre TextService, l'unicité des noms et le DataStore des clans se testent en Play.
]]
local clanFolder = assert(game:GetService("ServerScriptService"):FindFirstChild("Clan"), "Clan absent")
local R = require(assert(clanFolder:FindFirstChild("ClanRules"), "ClanRules absent"))
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local CC = require(assert(config:FindFirstChild("ClanConfig"), "ClanConfig absent"))
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
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
local function player(money)
    local p = copy(Default)
    p.Money = money or 0
    return p
end
local NOW = 1790000000
-- Clan du chef 1, puis les joueurs 2..n acceptés dans l'ordre (arrivées espacées d'une seconde).
local function clanWith(n)
    local clan = R.Create(player(1e6), 1, "c1", "Les Brainrots", "brn", 7, NOW)
    for userId = 2, n do
        R.Request(clan, userId, player(), NOW + userId)
        R.Accept(clan, 1, userId, NOW + userId)
    end
    return clan
end

-- §31.15 / F1 : création.
local founder = player(600000)
local clan = R.Create(founder, 1, "c1", "Les Brainrots", "brn", 7, NOW)
check("Création : 500 000 💰 débités, chef, tag en majuscules, emblème 7", clan ~= nil and founder.Money == 100000
    and founder.Clan.Id == "c1" and founder.Clan.Role == "Leader" and clan.Tag == "BRN" and clan.Emblem == 7
    and R.RoleOf(clan, 1) == "Leader" and R.Count(clan) == 1)
local function refusal(p, name, tag, emblem)
    local before = copy(p)
    local out, why = R.Create(p, 2, "c2", name, tag, emblem, NOW)
    return out == nil and same(p, before) and why
end
local _, already = R.Create(founder, 1, "c3", "Autre clan", "AUT", 1, NOW)
check("Déjà dans un clan : ALREADY_IN_CLAN", already == "ALREADY_IN_CLAN")
check("Nom de 3 à 16 caractères (« Ab » et 17 refusés ; « Équipe » accepté)", refusal(player(1e6), "Ab", "AB", 1)
    == "BAD_NAME" and refusal(player(1e6), string.rep("x", 17), "AB", 1) == "BAD_NAME"
    and R.Create(player(1e6), 2, "c2", "Équipe", "EQ", 1, NOW) ~= nil)
check("Tag de 2 à 4 lettres (A, ABCDE, É, A1 refusés)", refusal(player(1e6), "Clan", "A", 1) == "BAD_TAG"
    and refusal(player(1e6), "Clan", "ABCDE", 1) == "BAD_TAG" and refusal(player(1e6), "Clan", "É", 1) == "BAD_TAG"
    and refusal(player(1e6), "Clan", "A1", 1) == "BAD_TAG")
check("Emblème 1 à 20 (0, 21, 1,5 refusés)", refusal(player(1e6), "Clan", "AB", 0) == "BAD_EMBLEM"
    and refusal(player(1e6), "Clan", "AB", 21) == "BAD_EMBLEM" and refusal(player(1e6), "Clan", "AB", 1.5) == "BAD_EMBLEM")
check("499 999 💰 : NOT_ENOUGH_MONEY, rien débité", refusal(player(499999), "Clan", "AB", 1) == "NOT_ENOUGH_MONEY")

-- F1 : adhésion.
local requested = R.Request(clan, 2, player(), NOW)
local _, again = R.Request(clan, 2, player(), NOW)
local _, byMember = R.Accept(clan, 2, 2, NOW)
local accepted = R.Accept(clan, 1, 2, NOW)
local _, noRequest = R.Accept(clan, 1, 3, NOW)
local _, member = R.Request(clan, 2, player(), NOW)
local other = player()
other.Clan.Id = "c9"
local _, inClan = R.Request(clan, 3, other, NOW)
check("Demande puis acceptation par le chef ; refus : 2e demande, demandeur non autorisé, sans demande, déjà membre, "
    .. "déjà dans un autre clan", requested and again == "ALREADY_REQUESTED" and byMember == "NOT_ALLOWED" and accepted
    and noRequest == "NO_REQUEST" and member == "ALREADY_MEMBER" and inClan == "ALREADY_IN_CLAN"
    and R.RoleOf(clan, 2) == "Member")
R.Request(clan, 3, player(), NOW)
check("Refus d'une demande par le chef", R.Decline(clan, 1, 3) and clan.Requests[3] == nil and R.Count(clan) == 2)
local full = clanWith(20)
local _, fullRequest = R.Request(full, 21, player(), NOW)
check("F1 : 20 membres au plus (CLAN_FULL)", R.Count(full) == 20 and fullRequest == "CLAN_FULL")
local almost = clanWith(19)
R.Request(almost, 20, player(), NOW)
R.Request(almost, 21, player(), NOW)
R.Accept(almost, 1, 20, NOW)
local _, fullAccept = R.Accept(almost, 1, 21, NOW)
check("Une demande acceptée au-delà de 20 : CLAN_FULL", fullAccept == "CLAN_FULL" and R.Count(almost) == 20)

-- F1 : rôles.
local c = clanWith(6)
local promoted = R.Promote(c, 1, 2) and R.Promote(c, 1, 3) and R.Promote(c, 1, 4)
local _, fourth = R.Promote(c, 1, 5)
local _, notLeader = R.Promote(c, 2, 5)
check("3 officiers au plus, nommés par le chef (OFFICERS_FULL, NOT_ALLOWED)", promoted and fourth == "OFFICERS_FULL"
    and notLeader == "NOT_ALLOWED")
R.Request(c, 7, player(), NOW + 100)
check("Un officier accepte les membres (F1)", R.Accept(c, 2, 7, NOW + 100) and R.RoleOf(c, 7) == "Member")
check("Rétrogradation par le chef", R.Demote(c, 1, 4) and R.RoleOf(c, 4) == "Member" and R.Promote(c, 1, 4))
local _, officerKicksOfficer = R.Kick(c, 2, 3)
local _, memberKicks = R.Kick(c, 5, 6)
local _, selfKick = R.Kick(c, 1, 1)
check("Exclusions : un officier exclut un membre, le chef un officier ; refusées entre officiers, par un membre, "
    .. "de soi-même", R.Kick(c, 2, 7) and R.Kick(c, 1, 4) and officerKicksOfficer == "NOT_ALLOWED"
    and memberKicks == "NOT_ALLOWED" and selfKick == "NOT_ALLOWED")

-- Transfert et départ du chef (Q3 B).
c = clanWith(6)
R.Promote(c, 1, 2)
check("Transfert à un officier : l'ancien chef devient officier", R.Transfer(c, 1, 2) and R.RoleOf(c, 2) == "Leader"
    and R.RoleOf(c, 1) == "Officer")
c = clanWith(6)
R.Promote(c, 1, 2)
R.Promote(c, 1, 3)
R.Promote(c, 1, 4)
check("Transfert à un membre avec 3 officiers : l'ancien chef devient membre", R.Transfer(c, 1, 5)
    and R.RoleOf(c, 5) == "Leader" and R.RoleOf(c, 1) == "Member")
c = clanWith(5)
R.Promote(c, 1, 4)
R.Promote(c, 1, 3)
local gone = R.Leave(c, 1)
check("Q3 (B) : le chef parti, l'officier le plus ancien (3, arrivé avant 4) devient chef", gone.NewLeader == 3
    and R.RoleOf(c, 3) == "Leader" and R.RoleOf(c, 1) == nil)
c = clanWith(4)
local heir = R.Leave(c, 1)
check("Sans officier : le membre le plus ancien (2) devient chef", heir.NewLeader == 2 and R.RoleOf(c, 2) == "Leader")
c = clanWith(1)
local alone = R.Leave(c, 1)
check("Chef seul : son départ dissout le clan", alone.Dissolved and c.Dissolved and R.Count(c) == 0)

-- §31.15 : personne ne quitte ni n'est exclu pendant une guerre.
c = clanWith(6)
c.WarActive = {}
local _, leaveWar = R.Leave(c, 3)
local _, kickWar = R.Kick(c, 1, 3)
c.WarActive = nil
check("Quitter ou exclure en pleine guerre : WAR_ACTIVE ; après : permis", leaveWar == "WAR_ACTIVE"
    and kickWar == "WAR_ACTIVE" and R.Leave(c, 3) ~= nil)

-- F2 : coffre.
c = clanWith(3)
local donor = player(6e6)
local d1 = R.Donate(c, donor, 2, 500000, NOW)
check("Don de 500 K : débité, coffre niveau 1, +3 %, tag gris", donor.Money == 5.5e6 and donor.Clan.Donated == 500000
    and d1.LevelBefore == 0 and d1.Level == 1 and R.IncomeBonus(c) == 0.03 and R.TagColor(c) == "Gris")
local d2 = R.Donate(c, donor, 2, 4500000, NOW + 1)
check("5 M cumulés : niveau 2, +6 %, tag bleu", d2.Level == 2 and R.IncomeBonus(c) == 0.06 and R.TagColor(c) == "Bleu")
local before = copy(donor)
local _, poor = R.Donate(c, donor, 2, 1e9, NOW)
local amounts = true
for _, amount in ipairs({0, -5, 1.5, 0 / 0, math.huge, "10"}) do
    local _, why = R.Donate(c, donor, 2, amount, NOW)
    amounts = amounts and why == "BAD_AMOUNT"
end
local _, stranger = R.Donate(c, player(1e6), 99, 10, NOW)
check("Refus sans effet : plus que son argent, montant invalide, non-membre", poor == "NOT_ENOUGH_MONEY" and amounts
    and stranger == "NOT_MEMBER" and same(donor, before))
R.Leave(c, 2)
check("F2 : dons jamais remboursés, même au départ du donateur", c.Donated == 5e6 and donor.Money == 1e6
    and R.Refund == nil)
local big = clanWith(2)
R.Donate(big, player(5e7), 1, 5e7, NOW)
check("§31.15 : perk niveau 3 = +10 % pour tout le clan, tag doré", R.IncomeBonus(big) == 0.10 and R.TagColor(big) == "Doré")
check("Sans don : tag blanc, aucun perk", R.TagColor(clanWith(1)) == CC.NoLevelTagColor and R.IncomeBonus(clanWith(1)) == 0)
c = clanWith(4)
R.Promote(c, 1, 2)
R.Donate(c, player(1000), 3, 1000, NOW + 5)
local history = R.History(c, 2)
local _, hidden = R.History(c, 3)
check("F2 : historique des dons visible du chef et des officiers seulement", history and #history == 1
    and history[1].UserId == 3 and history[1].Amount == 1000 and hidden == "NOT_ALLOWED")
check("F4 : aucune fusion de clans possible", R.Merge == nil and CC.AntiAbuse.MergeAllowed == false)

local summary = ("[CLAN RULES TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
