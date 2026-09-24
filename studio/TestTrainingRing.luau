--!nonstrict
--[[ TestTrainingRing
     Rôle    : prouver l'anneau d'entraînement : +2 % par niveau sur les stats PvP B4 des brainrots posés.
     Doc     : GAME_MASTER_V2 A5, B4, E11, G4 (BuyUpgrade) ; PROMPT_EXECUTION_SABL_V4 §31.9 lot D
     Étape   : 9, lot D ; achat factice tu dans la sortie au lot F3, rebirth factice à l'étape 10, lot 0
     Dépend  : Play serveur avec un joueur connecté ; Config.CreatureConfig, Shared.CombatUtil, Shared.TableUtil,
               RemoteGuard, Migrations, Services.UpgradeService / RebirthService / DataService ;
               lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan. Profils factices pour l'achat et le rebirth ; le profil du joueur n'est que lu, et ses
               stats attendues sont publiées dans l'attribut Workspace SABL_ExpectedPvp pour
               studio/TestTrainingRingClient.luau
     Limite  : aucun combat n'existe avant l'étape 13 : on prouve la formule partagée et son affichage.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local CreatureConfig = require(ReplicatedStorage.Config.CreatureConfig)
local CombatUtil = require(ReplicatedStorage.Shared.CombatUtil)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local Migrations = require(Server.Data.Migrations)
local UpgradeService = require(Server.Services.UpgradeService)
local RebirthService = require(Server.Services.RebirthService)
local DataService = require(Server.Services.DataService)

-- B4, recopié tel quel : les deux exemples du document, en classé.
local TUNG = {Id = "tung_tung", Tier = 4, HP = 725, ATK = 58}
local TRALALERO = {Id = "tralalero", Tier = 5, HP = 6400, ATK = 448}
local EXPORT_ATTRIBUTE = "SABL_ExpectedPvp"

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local function ringProfile(level)
    local profile = Migrations:Create()
    profile.Base.TrainingRing = level
    return profile
end
local function placed(spec) return {Uid = "p1", Id = spec.Id, Tier = spec.Tier, PlacedSlot = 1} end

-- ── A5 : +2 % par niveau ─────────────────────────────────────────────────
local points = {}
for level = 0, 5 do table.insert(points, CombatUtil.TrainingPercent(ringProfile(level))) end
check(("A5 : +2 %% par niveau, soit %s points aux niveaux 0 a 5"):format(table.concat(points, "/")),
    table.concat(points, "/") == "0/2/4/6/8/10")
local invalid = true
for _, level in ipairs({-1, "3", 0 / 0}) do
    if CombatUtil.TrainingPercent(ringProfile(level)) ~= 0 then invalid = false end
end
check("Niveaux invalides (-1, texte, NaN), profil ou base absents : 0 point ; niveau 9 plafonne a 10",
    invalid and CombatUtil.TrainingPercent(nil) == 0 and CombatUtil.TrainingPercent({}) == 0
    and CombatUtil.TrainingPercent(ringProfile(9)) == 10)

-- ── G5.1 intact sans anneau ──────────────────────────────────────────────
local compared, mismatches = 0, 0
for _, species in ipairs(CreatureConfig.Creatures) do
    for tier = 1, 5 do
        for _, ranked in ipairs({true, false}) do
            local reference = CreatureConfig:GetCombatStats(species.id, tier, ranked)
            local atZero = CombatUtil.GetCreatureStats({Id = species.id, Tier = tier, PlacedSlot = 1}, ringProfile(0), ranked)
            local unplaced = CombatUtil.GetCreatureStats({Id = species.id, Tier = tier}, ringProfile(5), ranked)
            compared += 1
            for _, stats in ipairs({atZero, unplaced}) do
                if not stats or stats.HP ~= reference.HP or stats.ATK ~= reference.ATK or stats.Type ~= reference.Type
                    or stats.Training ~= 0 then
                    mismatches += 1
                end
            end
        end
    end
end
check(("G5.1 intact : %d combinaisons (brainrots x 5 tiers x 2 modes), %d ecart, anneau 0 ou brainrot non pose")
    :format(compared, mismatches), compared == #CreatureConfig.Creatures * 10 and mismatches == 0)

-- ── B4 avec l'anneau ─────────────────────────────────────────────────────
local tung5 = CombatUtil.GetCreatureStats(placed(TUNG), ringProfile(5), true)
local tralalero5 = CombatUtil.GetCreatureStats(placed(TRALALERO), ringProfile(5), true)
local tungBase = CreatureConfig:GetCombatStats(TUNG.Id, TUNG.Tier, true)
local tralaleroBase = CreatureConfig:GetCombatStats(TRALALERO.Id, TRALALERO.Tier, true)
check(("B4 + anneau 5 : Tung Tung Galaxie %d PV / %d ATK (725 / 58 sans), Tralalero Celeste %d / %d (6 400 / 448 sans)")
    :format(tung5.HP, tung5.ATK, tralalero5.HP, tralalero5.ATK),
    tungBase.HP == TUNG.HP and tungBase.ATK == TUNG.ATK and tralaleroBase.HP == TRALALERO.HP
    and tralaleroBase.ATK == TRALALERO.ATK and tung5.HP == 797 and tung5.ATK == 63
    and tralalero5.HP == 7040 and tralalero5.ATK == 492 and tung5.Training == 10)
local ladder, exact = {}, true
for level = 0, 5 do
    local stats = CombatUtil.GetCreatureStats(placed(TUNG), ringProfile(level), true)
    table.insert(ladder, ("%d/%d"):format(stats.HP, stats.ATK))
    local factor = 100 + 2 * level
    if stats.HP ~= math.floor(TUNG.HP * factor / 100) or stats.ATK ~= math.floor(TUNG.ATK * factor / 100) then
        exact = false
    end
end
check(("Tung Tung Galaxie, anneau 0 a 5 : %s (arrondi vers le bas, comme G5.1)"):format(table.concat(ladder, ", ")),
    exact and ladder[2] == "739/59" and ladder[6] == "797/63")

-- ── A5 : seuls les brainrots posés ───────────────────────────────────────
local ring5 = ringProfile(5)
local loose = CombatUtil.GetCreatureStats({Id = TUNG.Id, Tier = TUNG.Tier}, ring5, true)
local reserve = CombatUtil.GetCreatureStats({Id = TUNG.Id, Tier = TUNG.Tier, Reserve = true}, ring5, true)
local odd = CombatUtil.GetCreatureStats({Id = TUNG.Id, Tier = TUNG.Tier, PlacedSlot = 1, Reserve = true}, ring5, true)
check(("Anneau 5 sans effet hors socle : non pose %d PV, Reserve d'or %d PV, reserve marquee posee %d PV")
    :format(loose.HP, reserve.HP, odd.HP),
    loose.HP == TUNG.HP and reserve.HP == TUNG.HP and odd.HP == TUNG.HP
    and loose.Training == 0 and reserve.Training == 0 and odd.Training == 0)
local free0 = CreatureConfig:GetCombatStats(TUNG.Id, TUNG.Tier, false)
local free5 = CombatUtil.GetCreatureStats(placed(TUNG), ring5, false)
check(("Decision 45 : l'anneau vaut aussi en libre : %d -> %d PV, %d -> %d ATK")
    :format(free0.HP, free5.HP, free0.ATK, free5.ATK),
    free5.HP == math.floor(free0.HP * 110 / 100) and free5.ATK == math.floor(free0.ATK * 110 / 100)
    and free5.HP > free0.HP)
check("Entrees invalides (rien, brainrot inconnu, texte) : nil",
    CombatUtil.GetCreatureStats(nil, ring5, true) == nil
    and CombatUtil.GetCreatureStats({Id = "inconnu", Tier = 1}, ring5, true) == nil
    and CombatUtil.GetCreatureStats("tung_tung", ring5, true) == nil)

-- ── Faux services ────────────────────────────────────────────────────────
local function makeData(profile)
    local clockValue = 0
    local profiles = {[player] = profile}
    local fake = {}
    function fake:Get(t) local s = profiles[t] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(t, cb)
        local current = profiles[t]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(cb, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        profiles[t] = reconciled
        return true, result
    end
    fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return clockValue end})
    fake.Tick = function() clockValue += 1 end
    return fake
end
local noRefresh = {Refresh = function() return true end}

-- ── G4 : l'anneau acheté par BuyUpgrade ──────────────────────────────────
local shop = Migrations:Create()
shop.Money = 250000 + 1410000
shop.Creatures = {
    {Uid = "aaa", Id = TUNG.Id, Tier = TUNG.Tier, PlacedSlot = 1},
    {Uid = "bbb", Id = TUNG.Id, Tier = TUNG.Tier},
}
local shopData = makeData(shop)
local upgrades = UpgradeService.new({Data = shopData, Placement = noRefresh, Remote = Instance.new("RemoteFunction"),
    Log = false}) -- lot F3 : achat factice, rien dans la sortie sous l'identifiant du testeur
upgrades:Init()
local bought = {}
for _ = 1, 2 do
    shopData.Tick()
    local ok, result = upgrades:Buy(player, "TrainingRing")
    table.insert(bought, ok == true and result.Price or -1)
end
local shopped = shopData:Get(player)
local posed = CombatUtil.GetCreatureStats(shopped.Creatures[1], shopped, true)
local kept = CombatUtil.GetCreatureStats(shopped.Creatures[2], shopped, true)
check(("Achat : anneau 0 -> %d pour %d puis %d ; brainrot pose %d PV / %d ATK (+4 %%), non pose %d PV")
    :format(shopped.Base.TrainingRing, bought[1], bought[2], posed.HP, posed.ATK, kept.HP),
    shopped.Base.TrainingRing == 2 and bought[1] == 250000 and bought[2] == 1410000 and shopped.Money == 0
    and posed.HP == 754 and posed.ATK == 60 and kept.HP == TUNG.HP)

-- ── Lot C : le rebirth remet l'anneau à 0 et range le brainrot ───────────
local reborn = Migrations:Create()
reborn.Money = 1e6
reborn.Base.TrainingRing = 3
reborn.Creatures = {{Uid = "aaa", Id = TUNG.Id, Tier = TUNG.Tier, PlacedSlot = 1}}
local trained = CombatUtil.GetCreatureStats(reborn.Creatures[1], reborn, true)
local rebirthData = makeData(reborn)
local rebirths = RebirthService.new({Data = rebirthData, Placement = noRefresh,
    Steal = {IsInvolved = function() return false end}, Remote = Instance.new("RemoteFunction"), Log = false})
rebirths:Init()
rebirthData.Tick()
local okRebirth = rebirths:Rebirth(player, true)
local after = rebirthData:Get(player)
local stored = CombatUtil.GetCreatureStats(after.Creatures[1], after, true)
check(("Rebirth : anneau 3 -> %d ; brainrot %d PV avant (+6 %%), %d PV en Reserve d'or")
    :format(after.Base.TrainingRing, trained.HP, stored.HP),
    okRebirth == true and after.Base.TrainingRing == 0 and trained.HP == 768 and stored.HP == TUNG.HP
    and stored.Training == 0 and after.Creatures[1].Reserve == true)

-- ── Profil réel, en lecture seule : stats attendues à l'écran ────────────
local live = DataService:Get(player)
local expected, count, placedCount = {}, 0, 0
if live then
    for _, creature in ipairs(live.Creatures) do
        local stats = CombatUtil.GetCreatureStats(creature, live, true)
        if stats and type(creature.Uid) == "string" then
            expected[creature.Uid] = ("%d PV · %d ATK"):format(stats.HP, stats.ATK)
            count += 1
            if stats.Training > 0 then placedCount += 1 end
        end
    end
end
local ring = CombatUtil.TrainingPercent(live)
Workspace:SetAttribute(EXPORT_ATTRIBUTE, HttpService:JSONEncode({Ring = ring, Stats = expected}))
check(("Profil reel (lu, jamais ecrit) : %d brainrots dont %d renforces, anneau +%d %%, attendus publies pour le client")
    :format(count, placedCount, ring), live ~= nil and count > 0)

table.insert(T.lines, ("[TRAINING RING TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
