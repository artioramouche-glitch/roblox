--!nonstrict
--[[ TestRebirthService
     Rôle    : prouver le rebirth : paliers C3, ×2 au calcul, Réserve d'or sans perte, monde 2 à R3, persistance.
     Doc     : GAME_MASTER_V2 C3, C2, G2, G4 (DoRebirth) ; PROMPT_EXECUTION_SABL_V4 §31.9 (tests), Loi 8 ;
               décisions 32, 35 et 36
     Étape   : 9, lot C ; journal des rebirths factices capté à l'étape 10, lot 0
     Dépend  : Play serveur avec un joueur connecté ; Config.RebirthConfig, Config.DefaultProfile (version courante
               du schéma, 3 depuis le lot F1), Shared.EconomyUtil, RemoteGuard,
               Migrations, TableUtil, Services.RebirthService / PlacementService / FusionService / EggService /
               StealService, Packages.ProfileService, Data.ProfileStoreAdapter, Data.DataConfig ;
               lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan. Profils factices pour tout le rebirth ; la persistance écrit une clé dédiée du magasin
               de test (Test_RebirthPersistence), jamais le profil d'un joueur
     Limite  : IsInvolved n'est vérifié qu'au repos sur le StealService vivant ; le refus pendant un vol passe
               par un StealService factice.
]]
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
-- Étape 10, lot 0 : les rebirths factices ne s'écrivent pas dans la sortie ; une fuite s'y verrait quand même.
local logged, leaked = {}, 0
local leakWatch = LogService.MessageOut:Connect(function(message)
    if message:find("[REBIRTH] user=", 1, true) then leaked += 1 end
end)
local RebirthConfig = require(ReplicatedStorage.Config.RebirthConfig)
local CURRENT_VERSION = require(ReplicatedStorage.Config.DefaultProfile).DataVersion -- 3 depuis le lot F1
local EconomyUtil = require(ReplicatedStorage.Shared.EconomyUtil)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local Migrations = require(Server.Data.Migrations)
local DataConfig = require(Server.Data.DataConfig)
local RebirthService = require(Server.Services.RebirthService)
local PlacementService = require(Server.Services.PlacementService)
local FusionService = require(Server.Services.FusionService)
local EggService = require(Server.Services.EggService)
local StealService = require(Server.Services.StealService)

-- C3, recopié tel quel.
local C3 = {
    {1, 1e6}, {2, 50e6}, {3, 2.5e9}, {4, 100e9}, {5, 500e9}, {10, 100e12},
}
local PERSISTENCE_KEY = DataConfig.StoreName .. "/Test_RebirthPersistence"
local RELEASE_SECONDS = 15

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- ── C3 : les paliers ─────────────────────────────────────────────────────
local exact = true
for _, row in ipairs(C3) do
    if RebirthConfig.CostOf(row[1]) ~= row[2] then exact = false end
end
check("C3 : R1 1M, R2 50M, R3 2,5B, R4 100B, R5 500B, R10 100T exacts", exact)
local geometric = true
for rebirth = 6, 9 do
    local ideal = 500e9 * (100e12 / 500e9) ^ ((rebirth - 5) / 5)
    if math.abs(RebirthConfig.CostOf(rebirth) - ideal) > ideal * 0.005 then geometric = false end
end
check("Decision 35 : R6-R9 intercales entre R5 et R10 (a 0,5 % pres), R11 = R10 x 50",
    geometric and RebirthConfig.CostOf(11) == 100e12 * 50)
check("C3 : mondes 2 / 3 / 4 a R3 / R5 / R10, monde 1 avant",
    RebirthConfig.WorldFor(0) == 1 and RebirthConfig.WorldFor(2) == 1 and RebirthConfig.WorldFor(3) == 2
    and RebirthConfig.WorldFor(5) == 3 and RebirthConfig.WorldFor(9) == 3 and RebirthConfig.WorldFor(10) == 4)
check("C3 : x2 par rebirth, +10 % chance a R1, tokens 500 a R2 et 2 000 a R4",
    RebirthConfig.IncomeMultiplier == 2 and RebirthConfig.LuckBonus(1) == 0.10 and RebirthConfig.LuckBonus(0) == 0
    and RebirthConfig.Get(2).ArenaTokens == 500 and RebirthConfig.Get(4).ArenaTokens == 2000)

-- ── G2 : schéma v2 et suivants ───────────────────────────────────────────────────────
local v1 = {DataVersion = 1, Money = 7, Creatures = {{Uid = "aaa", Id = "noobini", Tier = 1, PlacedSlot = 1}}}
local migrated, migrationError = Migrations:Apply(v1)
check(("Migration v1 -> v%d : creature intacte, hors reserve"):format(CURRENT_VERSION),
    migrationError == nil and migrated.DataVersion == CURRENT_VERSION and migrated.Creatures[1].Uid == "aaa"
    and migrated.Creatures[1].PlacedSlot == 1 and migrated.Creatures[1].Reserve == nil and v1.DataVersion == 1)
local kept = Migrations:Apply({DataVersion = 2, Creatures = {{Uid = "bbb", Id = "noobini", Tier = 1, Reserve = true}}})
local future, futureError = Migrations:Apply({DataVersion = CURRENT_VERSION + 1, Money = 5})
check(("Profil v2 : drapeau Reserve conserve ; profil v%d refuse (FUTURE_VERSION)"):format(CURRENT_VERSION + 1),
    kept ~= nil and kept.Creatures[1].Reserve == true and future == nil and futureError == "FUTURE_VERSION")

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

local function makeRebirth(profile, involved)
    local data = makeData(profile)
    local refreshed = 0
    local service = RebirthService.new({
        Data = data,
        Placement = {Refresh = function() refreshed += 1 return true end},
        Steal = {IsInvolved = function() return involved == true end},
        Remote = Instance.new("RemoteFunction"),
        Log = function(line) table.insert(logged, line) end,
    })
    service:Init()
    local function rebirth(confirmed)
        data.Tick()
        return service:Rebirth(player, confirmed)
    end
    return rebirth, data, function() return refreshed end
end

local function sampleProfile(money)
    local profile = Migrations:Create()
    profile.Money = money
    profile.Level, profile.Playtime = 7, 5000
    profile.Stats.EggsOpened = 12
    profile.PvP.ArenaTokens = 10
    profile.Base.Plot = 4
    profile.Base.Slots = 6
    profile.Base.Generator = 2
    profile.Base.TrainingRing = 1
    profile.Base.Decor = {"pot_fleurs", "parasol"}
    profile.Creatures = {
        {Uid = "aaa", Id = "noobini", Tier = 2, PlacedSlot = 1},
        {Uid = "bbb", Id = "tim_cheese", Tier = 1, PlacedSlot = 2, InPvPTeam = "A"},
        {Uid = "ccc", Id = "noobini", Tier = 1},
    }
    return profile
end

-- ── G4 : DoRebirth ───────────────────────────────────────────────────────
local rebirth, data, refreshes = makeRebirth(sampleProfile(1e6), false)
local refusals = {}
for _, value in ipairs({false, "oui", 1}) do
    local ok, code = rebirth(value)
    if ok == false and code == "NOT_CONFIRMED" then table.insert(refusals, tostring(value)) end
end
local okNil, codeNil = rebirth(nil)
check(("Sans confirmation explicite : refuse (%s, nil)"):format(table.concat(refusals, ", ")),
    #refusals == 3 and okNil == false and codeNil == "NOT_CONFIRMED" and data:Get(player).Rebirths == 0)

local rebirthPoor, dataPoor = makeRebirth(sampleProfile(1e6 - 1), false)
local okPoor, codePoor = rebirthPoor(true)
local poor = dataPoor:Get(player)
check("Rebirth sous le seuil (999 999) : NOT_ENOUGH_MONEY, rien ne change",
    okPoor == false and codePoor == "NOT_ENOUGH_MONEY" and poor.Rebirths == 0 and poor.Money == 1e6 - 1
    and poor.Creatures[1].PlacedSlot == 1 and poor.Base.Generator == 2)

local rebirthBusy, dataBusy = makeRebirth(sampleProfile(1e6), true)
local okBusy, codeBusy = rebirthBusy(true)
check("Pendant un vol ou un rachat : IN_STEAL, rien ne change",
    okBusy == false and codeBusy == "IN_STEAL" and dataBusy:Get(player).Rebirths == 0)

local before = data:Get(player)
local incomeBefore = EconomyUtil.GetTotalIncome(before)
local ok, result = rebirth(true)
local after = data:Get(player)
check(("Rebirth 1 pour %d : accepte, argent a 0, rebirth 1, plot redessine"):format(result and result.Cost or -1),
    ok == true and result.Cost == 1e6 and after.Rebirths == 1 and after.Money == 0 and refreshes() == 1)
local uids, reserve, placed = {}, 0, 0
for _, creature in ipairs(after.Creatures) do
    uids[creature.Uid] = true
    if creature.Reserve == true then reserve += 1 end
    if creature.PlacedSlot ~= nil then placed += 1 end
end
check(("Loi 8 : %d brainrots avant, %d apres, memes Uid, %d en Reserve d'or, %d sur un socle")
    :format(#before.Creatures, #after.Creatures, reserve, placed),
    #after.Creatures == 3 and uids.aaa and uids.bbb and uids.ccc and reserve == 3 and placed == 0)
check("Q1 : composants remis a zero (3 slots, generateur 0, anneau 0, decos 0), plot garde",
    after.Base.Slots == 3 and after.Base.Generator == 0 and after.Base.TrainingRing == 0
    and #after.Base.Decor == 0 and after.Base.Plot == 4)
check("Q1 : niveau, temps de jeu, stats et equipe PvP intacts",
    after.Level == 7 and after.Playtime == 5000 and after.Stats.EggsOpened == 12
    and after.Creatures[2].InPvPTeam == "A" and after.PvP.ArenaTokens == 10)
-- Critère H2 : le revenu d'un brainrot posé double après le rebirth ; la Réserve ne produit rien.
local fresh = TableUtil.DeepCopy(after)
table.insert(fresh.Creatures, {Uid = "ddd", Id = "noobini", Tier = 1, PlacedSlot = 1})
local withoutRebirth = TableUtil.DeepCopy(fresh)
withoutRebirth.Rebirths = 0
check(("H2 : Rebirth 1 -> x2 verifie au calcul : noobini pose = %d/s (sans rebirth %d/s) ; reserve = %d/s")
    :format(EconomyUtil.GetTotalIncome(fresh), EconomyUtil.GetTotalIncome(withoutRebirth), EconomyUtil.GetTotalIncome(after)),
    EconomyUtil.GetTotalIncome(fresh) == 2 * EconomyUtil.GetTotalIncome(withoutRebirth)
    and EconomyUtil.GetTotalIncome(fresh) == 20 and EconomyUtil.GetTotalIncome(after) == 0 and incomeBefore > 0)

-- R2, R3, R4 enchaînés sur le même profil : tokens, monde 2, et toujours aucun brainrot perdu.
local ladder = sampleProfile(0)
ladder.Rebirths = 1
local rebirthLadder, dataLadder = makeRebirth(ladder, false)
local steps = {}
for _, spec in ipairs({{2, 50e6}, {3, 2.5e9}, {4, 100e9}}) do
    dataLadder:Update(player, function(p) p.Money = spec[2] return true end)
    local okStep, step = rebirthLadder(true)
    local now = dataLadder:Get(player)
    steps[spec[1]] = {ok = okStep, step = step, world = now.WorldUnlocked, tokens = now.PvP.ArenaTokens,
        count = #now.Creatures}
end
check(("R2 : +500 tokens (%d) ; R4 : +2 000 tokens (%d)"):format(steps[2].tokens, steps[4].tokens),
    steps[2].ok and steps[2].tokens == 510 and steps[4].ok and steps[4].tokens == 2510)
check(("Rebirth 3 : WorldUnlocked passe a 2 (%d), il l'etait a 1 apres R2 (%d)"):format(steps[3].world, steps[2].world),
    steps[3].ok and steps[3].world == 2 and steps[2].world == 1 and steps[4].world == 2)
check("Loi 8 : 3 brainrots apres R2, R3 et R4", steps[2].count == 3 and steps[3].count == 3 and steps[4].count == 3)

-- ── La Réserve d'or ailleurs : ni posée, ni vendue, ni fusionnée, hors plafond d'œufs ────────
local reserveProfile = Migrations:Create()
reserveProfile.Money = 1e9
reserveProfile.Creatures = {
    {Uid = "r1", Id = "noobini", Tier = 1, Reserve = true},
    {Uid = "r2", Id = "noobini", Tier = 1, Reserve = true},
    {Uid = "r3", Id = "noobini", Tier = 1, Reserve = true},
}
local placementData = makeData(TableUtil.DeepCopy(reserveProfile))
local fakeMap = Instance.new("Folder")
local fakePlots = Instance.new("Folder")
fakePlots.Name = "Plots"
fakePlots.Parent = fakeMap
local placement = PlacementService.new({Data = placementData, Map = fakeMap,
    PlaceRemote = Instance.new("RemoteFunction"), UnplaceRemote = Instance.new("RemoteFunction"),
    SellRemote = Instance.new("RemoteFunction")})
placement:Init()
local okPlace, codePlace = placement:Place(player, "r1", 1)
local okSell, codeSell = placement:Sell(player, "r1")
local fusionData = makeData(TableUtil.DeepCopy(reserveProfile))
local fusion = FusionService.new({Data = fusionData, Placement = false, Remote = Instance.new("RemoteFunction")})
fusion:Init()
local okFuse, codeFuse = fusion:Fuse(player, {"r1", "r2", "r3"})
check(("Reserve : pose %s, vente %s, fusion %s ; rien de retire"):format(tostring(codePlace), tostring(codeSell),
    tostring(codeFuse)), okPlace == false and codePlace == "IN_RESERVE" and okSell == false and codeSell == "IN_RESERVE"
    and okFuse == false and codeFuse == "IN_RESERVE" and #placementData:Get(player).Creatures == 3
    and #fusionData:Get(player).Creatures == 3)
local crowded = Migrations:Create()
crowded.Money = 1e9
for index = 1, 150 do
    table.insert(crowded.Creatures, {Uid = ("x%03d"):format(index), Id = "noobini", Tier = 1, Reserve = true})
end
local eggData = makeData(crowded)
local eggs = EggService.new({Data = eggData, Remote = Instance.new("RemoteFunction")})
eggs:Init()
local okEgg = eggs:Buy(player, "egg_basic", 1)
local full = TableUtil.DeepCopy(eggData:Get(player))
for _, creature in ipairs(full.Creatures) do creature.Reserve = nil end
local fullData = makeData(full)
local eggsFull = EggService.new({Data = fullData, Remote = Instance.new("RemoteFunction")})
eggsFull:Init()
local okFull, codeFull = eggsFull:Buy(player, "egg_basic", 1)
check(("Plafond : 150 en reserve n'empechent pas un oeuf (%s) ; 151 actifs -> %s"):format(tostring(okEgg), tostring(codeFull)),
    okEgg == true and okFull == false and codeFull == "INVENTORY_FULL")

check("StealService vivant : IsInvolved faux pour un joueur au repos", StealService:IsInvolved(player) == false)

-- ── Persistance : un rebirth écrit, relâché, rechargé (clé dédiée du magasin de test) ────────
local persistenceOk, detail, persisted = pcall(function()
    local library = require(Server.Packages.ProfileService)
    local store = library.GetProfileStore({Name = DataConfig.StoreName, Scope = DataConfig.StoreScope}, {})
    local Adapter = require(Server.Data.ProfileStoreAdapter)
    local adapter = Adapter.new(store, {BindUserIds = false})
    local lease = assert(adapter:Acquire(PERSISTENCE_KEY))
    local seed = sampleProfile(1e6)
    seed.DataVersion = 1 -- un profil d'avant l'étape 9, pour éprouver aussi la migration au chargement
    local rebirthSaved, dataSaved = makeRebirth(assert(Migrations:Apply(seed)), false)
    assert(rebirthSaved(true))
    assert(lease:Release(dataSaved:Get(player)))
    assert(adapter:AwaitPendingReleases(RELEASE_SECONDS))
    local reloaded = assert(adapter:Acquire(PERSISTENCE_KEY))
    local profile = assert(Migrations:Apply(reloaded.Data))
    reloaded:Release(nil)
    adapter:AwaitPendingReleases(RELEASE_SECONDS)
    local reserved = 0
    for _, creature in ipairs(profile.Creatures) do
        if creature.Reserve == true and creature.PlacedSlot == nil then reserved += 1 end
    end
    return ("rebirth %d, argent %d, %d/%d en reserve, version %d"):format(profile.Rebirths, profile.Money, reserved,
        #profile.Creatures, profile.DataVersion), profile.Rebirths == 1 and profile.Money == 0 and reserved == 3
        and #profile.Creatures == 3 and profile.DataVersion == CURRENT_VERSION
end)
check(("Persistance : rebirth relu apres liberation de la session (%s)"):format(
    if persistenceOk then tostring(detail) else "erreur : " .. tostring(detail)), persistenceOk and persisted == true)
task.wait(0.2) -- laisse passer les messages différés avant de couper la veille
leakWatch:Disconnect()
local shown = (logged[1] or "?"):gsub("user=%d+", "user=<id>") -- le libellé ne ressort pas l'identifiant
check(("G3 : %d rebirths journalises par la batterie, %d dans la sortie ; « %s »"):format(#logged, leaked, shown),
    #logged > 0 and leaked == 0 and (logged[1] or ""):match("^%[REBIRTH%] user=%d+ rebirth=1 cost=1000000 ") ~= nil)

table.insert(T.lines, ("[REBIRTH TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
