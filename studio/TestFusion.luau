--!nonstrict
--[[ TestFusion
     Rôle    : vérifier la fusion 3→1, ses refus, et qu'aucun exemplaire ne se perd.
     Doc     : GAME_MASTER_V2 B3, G4 ; PROMPT_EXECUTION_SABL_V4 §18.2, §18.4, §3, Loi 8
     Étape   : 4, lot C
     Dépend  : Play serveur avec un joueur connecté ; RemoteGuard, Migrations, TableUtil
     Exposé  : bilan ; profil factice, Placement désactivé, aucun piédestal réel touché
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local RemoteGuard = require(Server.Networking.RemoteGuard)
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local EconomyUtil = require(ReplicatedStorage.Shared.EconomyUtil)
local RemoteConfig = require(ReplicatedStorage.Config.RemoteConfig)
local FusionService = require(Server.Services.FusionService)

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local function makeService(creatures)
    local clockValue = 0
    local profiles = {[player] = Migrations:Create()}
    profiles[player].Creatures = creatures or {}
    local fake = {}
    function fake:Get(t) local s = profiles[t] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(t, cb)
        local candidate = TableUtil.DeepCopy(profiles[t])
        local ok, accepted, result = pcall(cb, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        profiles[t] = reconciled
        return true, result
    end
    fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return clockValue end})
    fake.Advance = function(s) clockValue += s end
    -- Placement = false : la batterie ne touche à aucun piédestal du monde réel.
    local service = FusionService.new({Data = fake, Placement = false,
        Remote = Instance.new("RemoteFunction"), Rng = Random.new(7)})
    service:Init()
    return service, fake
end

local function trio(id, tier)
    return {
        {Uid = "a1", Id = id, Tier = tier},
        {Uid = "a2", Id = id, Tier = tier},
        {Uid = "a3", Id = id, Tier = tier},
    }
end

-- Critère H2 : 3 noobini Normal donnent 1 noobini Doré, revenu ×3.
local service, fake = makeService(trio("noobini", 1))
local ok, result = service:Fuse(player, {"a1", "a2", "a3"})
local profile = fake:Get(player)
check("Fusion acceptee", ok == true and result.Id == "noobini" and result.Tier == 2)
check("3 exemplaires consommes, 1 cree", #profile.Creatures == 1)
check("Le resultat est un Dore (Tier 2)", profile.Creatures[1].Tier == 2
    and profile.Creatures[1].Id == "noobini")
check("Nouvel Uid distinct des trois consommes", profile.Creatures[1].Uid ~= "a1"
    and profile.Creatures[1].Uid ~= "a2" and profile.Creatures[1].Uid ~= "a3"
    and #profile.Creatures[1].Uid == 8)
check("Revenu x3 : 10 -> 30 (B3)", EconomyUtil.GetCreatureIncome("noobini", 2) == 30
    and EconomyUtil.GetCreatureIncome("noobini", 1) * 3 == 30)
check("Stats.Fusions incremente", profile.Stats.Fusions == 1)

-- Chaîne complète B3 : 9 normaux donnent 1 arc-en-ciel.
local chain, chainData = makeService({})
local nine = {}
for index = 1, 9 do nine[index] = {Uid = ("n%d"):format(index), Id = "noobini", Tier = 1} end
chainData:Update(player, function(p) p.Creatures = nine return true end)
chain:Fuse(player, {"n1", "n2", "n3"})
chain:Fuse(player, {"n4", "n5", "n6"})
chain:Fuse(player, {"n7", "n8", "n9"})
local golds = chainData:Get(player).Creatures
check("9 normaux -> 3 dores", #golds == 3 and golds[1].Tier == 2 and golds[3].Tier == 2)
local okChain = chain:Fuse(player, {golds[1].Uid, golds[2].Uid, golds[3].Uid})
local rainbow = chainData:Get(player).Creatures
check("3 dores -> 1 arc-en-ciel (Tier 3)", okChain == true and #rainbow == 1 and rainbow[1].Tier == 3)
check("Revenu arc-en-ciel = x10 (B3)", EconomyUtil.GetCreatureIncome("noobini", 3) == 100)

-- Refus : tiers différents, espèces différentes, tier maximal.
local mismatch, mismatchData = makeService({
    {Uid = "a1", Id = "noobini", Tier = 1},
    {Uid = "a2", Id = "noobini", Tier = 2},
    {Uid = "a3", Id = "noobini", Tier = 1},
    {Uid = "b1", Id = "tim_cheese", Tier = 1},
})
check("Tiers differents refuses MISMATCH",
    select(2, mismatch:Fuse(player, {"a1", "a2", "a3"})) == "MISMATCH")
check("Especes differentes refusees MISMATCH",
    select(2, mismatch:Fuse(player, {"a1", "a3", "b1"})) == "MISMATCH")
check("Loi 8 : aucun exemplaire perdu apres un refus", #mismatchData:Get(player).Creatures == 4)

local maxed = makeService(trio("noobini", 5))
check("Tier 5 refuse MAX_TIER", select(2, maxed:Fuse(player, {"a1", "a2", "a3"})) == "MAX_TIER")

-- Formats invalides : le même Uid trois fois est le piège §3.
local bad, badData = makeService(trio("noobini", 1))
check("Meme Uid trois fois refuse BAD_QTY",
    select(2, bad:Fuse(player, {"a1", "a1", "a1"})) == "BAD_QTY")
check("Deux Uid seulement refuses", select(2, bad:Fuse(player, {"a1", "a2"})) == "BAD_QTY")
check("Quatre Uid refuses", select(2, bad:Fuse(player, {"a1", "a2", "a3", "a1"})) == "BAD_QTY")
check("Table vide, nil, nombre et texte refuses",
    select(2, bad:Fuse(player, {})) == "BAD_QTY"
    and select(2, bad:Fuse(player, nil)) == "BAD_QTY"
    and select(2, bad:Fuse(player, 42)) == "BAD_QTY"
    and select(2, bad:Fuse(player, "a1a2a3")) == "BAD_QTY")
check("Uid inconnu refuse NOT_OWNER",
    select(2, bad:Fuse(player, {"a1", "a2", "zzz"})) == "NOT_OWNER")
check("Loi 8 : les 3 exemplaires sont intacts", #badData:Get(player).Creatures == 3)

local engaged = makeService({
    {Uid = "a1", Id = "noobini", Tier = 1, InPvPTeam = "A"},
    {Uid = "a2", Id = "noobini", Tier = 1},
    {Uid = "a3", Id = "noobini", Tier = 1},
})
check("Exemplaire engage refuse IN_ARENA",
    select(2, engaged:Fuse(player, {"a1", "a2", "a3"})) == "IN_ARENA")

-- Héritage du slot : la base continue de produire après une fusion.
local placed, placedData = makeService({
    {Uid = "a1", Id = "noobini", Tier = 1, PlacedSlot = 3},
    {Uid = "a2", Id = "noobini", Tier = 1, PlacedSlot = 1},
    {Uid = "a3", Id = "noobini", Tier = 1},
})
local okPlaced, placedResult = placed:Fuse(player, {"a1", "a2", "a3"})
local after = placedData:Get(player)
check("Le Dore reprend le plus petit slot libere (1)", okPlaced == true
    and placedResult.PlacedSlot == 1 and after.Creatures[1].PlacedSlot == 1)
check("Revenu apres fusion = 30 et non 20", EconomyUtil.GetTotalIncome(after) == 30)

-- §18.4 : rate-limit sur 30 fusions toutes valides.
local spam, spamData = makeService({})
local many = {}
for index = 1, 90 do many[index] = {Uid = ("m%02d"):format(index), Id = "noobini", Tier = 1} end
spamData:Update(player, function(p) p.Creatures = many return true end)
local accepted, limited, other = 0, 0, 0
for index = 0, 29 do
    local okSpam, code = spam:Fuse(player, {
        ("m%02d"):format(index * 3 + 1), ("m%02d"):format(index * 3 + 2), ("m%02d"):format(index * 3 + 3)})
    if okSpam then accepted += 1 elseif code == "RATE_LIMIT" then limited += 1 else other += 1 end
end
local max = RemoteConfig.MaxRequestsPerWindow
check(("Spam 30 fusions : %d acceptees, %d RATE_LIMIT, %d autres"):format(accepted, limited, other),
    accepted == max and limited == 30 - max and other == 0)
check("Inventaire coherent : 90 - 3x10 + 10 = 70", #spamData:Get(player).Creatures == 70)

check("Stop retourne true", spam:Stop() == true)
check("Apres Stop : plus aucune fusion", select(2, spam:Fuse(player, {"m31", "m32", "m33"})) == "INTERNAL")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
check("Remotes.RequestFusion est une RemoteFunction",
    remotes:FindFirstChild("RequestFusion") ~= nil and remotes.RequestFusion:IsA("RemoteFunction"))

table.insert(T.lines, ("[FUSION TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
