--!nonstrict
--[[ TestUpgradeService
     Rôle    : vérifier les prix A5, l'achat des composants de base et les bonus de revenu C2 qu'ils donnent.
     Doc     : GAME_MASTER_V2 A5, C2, G4 (BuyUpgrade) ; PROMPT_EXECUTION_SABL_V4 §18.2, §25 (lot ÉCONOMIE), §31.9
     Étape   : 9, lot B ; Coffre-fort achetable au lot F1 ; Tourelle et Piège au lot F2 ; Alarme et journal
               capté au lot F3
     Dépend  : Play serveur avec un joueur connecté ; Config.UpgradeConfig, Shared.EconomyUtil, RemoteGuard,
               Migrations, TableUtil, Services.UpgradeService, Base.DecorVisual, ServerStorage.PropModels
               (décos de studio/BuildDecoProps.luau) ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; profil factice, remote factice, plot factice : aucun profil réel touché. Les lignes
               [UPGRADE] BUY des achats factices sont captées ici : aucune ne sort sous l'identifiant du testeur
     Limite  : l'horloge du garde est figée et avancée d'une seconde avant chaque achat, pour que le
               rate-limit ne se mêle pas des contrôles d'achat ; il est mesuré à part, sur un service neuf.
]]
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local UpgradeConfig = require(ReplicatedStorage.Config.UpgradeConfig)
local EconomyUtil = require(ReplicatedStorage.Shared.EconomyUtil)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local Migrations = require(Server.Data.Migrations)
local UpgradeService = require(Server.Services.UpgradeService)
local DecorVisual = require(Server.Base.DecorVisual)

-- A5, recopié tel quel : premier et dernier prix de chaque composant (Q2, option A).
local A5 = {
    Slots = {5000, 50000000, 22},
    Generator = {50000, 5000000, 500000000},
    Alarm = {25000, 2000000, 200000000},
    Turret = {100000, 100000000, 5},
    Trap = {30000, 3000000, 300000000},
    Vault = {10000, 10000000, 5},
    TrainingRing = {250000, 250000000, 5},
}
-- Coffre-fort : lot F1 ; Tourelle et Piège : lot F2 ; Alarme : lot F3
local BUYABLE = {Slots = true, Generator = true, TrainingRing = true, Vault = true, Turret = true, Trap = true,
    Alarm = true}
local DECOR_FIRST, DECOR_LAST, DECOR_COUNT = 1000, 1000000, 12
local GEOMETRIC_TOLERANCE = 0.005 -- les prix intermédiaires sont arrondis à 3 chiffres significatifs

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

-- Échelle géométrique de a à b en n prix, bornes exactes, intermédiaires à 3 chiffres significatifs près.
local function isLadder(prices, a, b, n)
    if #prices ~= n or prices[1] ~= a or prices[n] ~= b then return false end
    for index = 2, n - 1 do
        local exact = a * (b / a) ^ ((index - 1) / (n - 1))
        local digits = 10 ^ (math.floor(math.log10(prices[index])) - 2)
        if math.abs(prices[index] - exact) > exact * GEOMETRIC_TOLERANCE or prices[index] % digits ~= 0 then
            return false
        end
    end
    return true
end

-- ── A5 : les prix ─────────────────────────────────────────────────────────
for _, component in ipairs(UpgradeConfig.Components) do
    local spec = A5[component.Key]
    local prices = component.Prices
    local ok
    if #spec == 3 and component.Max == 3 then
        ok = prices[1] == spec[1] and prices[2] == spec[2] and prices[3] == spec[3]
    else
        ok = isLadder(prices, spec[1], spec[2], spec[3])
    end
    check(("A5 %s : %d prix de %s a %s, niveaux %d a %d, %s"):format(component.Key, #prices, prices[1],
        prices[#prices], component.Start, component.Max, component.Available and "achetable" or "bientot"),
        ok and #prices == component.Max - component.Start and component.Available == (BUYABLE[component.Key] == true))
end
local decorPrices = {}
for _, item in ipairs(UpgradeConfig.Decor.Items) do table.insert(decorPrices, item.Price) end
check(("A5 Decos : %d objets de %d a %d, +2 %% chacun"):format(#decorPrices, decorPrices[1], decorPrices[#decorPrices]),
    isLadder(decorPrices, DECOR_FIRST, DECOR_LAST, DECOR_COUNT) and UpgradeConfig.Decor.Available)

-- ── C2 : les bonus de revenu ─────────────────────────────────────────────
local function profileWith(base)
    local profile = Migrations:Create()
    for key, value in pairs(base) do
        if key == "Rebirths" then profile.Rebirths = value else profile.Base[key] = value end
    end
    return profile
end
local allDecor = {}
for _, item in ipairs(UpgradeConfig.Decor.Items) do table.insert(allDecor, item.Id) end
check("C2 : generateur 1 / 2 / 3 -> x1,167 / x1,333 / x1,5 (Q3 option A)",
    near(EconomyUtil.GetGlobalMultiplier(profileWith({Generator = 1})), 1 + 0.5 / 3)
    and near(EconomyUtil.GetGlobalMultiplier(profileWith({Generator = 2})), 1 + 1 / 3)
    and near(EconomyUtil.GetGlobalMultiplier(profileWith({Generator = 3})), 1.5))
check("C2 : 12 decos -> x1,24 (+24 % max)", near(EconomyUtil.GetGlobalMultiplier(profileWith({Decor = allDecor})), 1.24))
check("C2 : rebirth x2, generateur 3 et 12 decos se multiplient -> x3,72",
    near(EconomyUtil.GetGlobalMultiplier(profileWith({Rebirths = 1, Generator = 3, Decor = allDecor})), 2 * 1.5 * 1.24))
local known = profileWith({Rebirths = 1, Generator = 3, Decor = allDecor})
known.Creatures = {{Uid = "aaa", Id = "noobini", Tier = 2, PlacedSlot = 1}, {Uid = "bbb", Id = "noobini", Tier = 1}}
check(("Revenu d'une base connue : %d/s (B1 10 x B3 3 x C2 3,72, une seule creature posee)")
    :format(EconomyUtil.GetTotalIncome(known)), EconomyUtil.GetTotalIncome(known) == math.floor(10 * 3 * 3.72))
check("Anneau : x1,02 au niveau 1, x1,10 au niveau 5, borne au maximum",
    near(UpgradeConfig.TrainingMultiplier(1), 1.02) and near(UpgradeConfig.TrainingMultiplier(5), 1.10)
    and near(UpgradeConfig.TrainingMultiplier(9), 1.10) and near(UpgradeConfig.TrainingMultiplier(-1), 1))

-- ── G4 : l'achat ─────────────────────────────────────────────────────────
-- Lot F3 : les achats factices ne s'écrivent pas dans la sortie ; une fuite s'y verrait quand même.
local logged, leaked = {}, 0
local leakWatch = LogService.MessageOut:Connect(function(message)
    if message:find("[UPGRADE] BUY", 1, true) then leaked += 1 end
end)
local function makeService(profile)
    local clockValue = 0
    local profiles = {[player] = profile}
    local refreshed = 0
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
    local placement = {Refresh = function() refreshed += 1 return true end}
    local service = UpgradeService.new({Data = fake, Placement = placement, Remote = Instance.new("RemoteFunction"),
        Log = function(line) table.insert(logged, line) end})
    service:Init()
    local function buy(key)
        clockValue += 1
        return service:Buy(player, key)
    end
    return buy, fake, function() return refreshed end, service
end

local profile = Migrations:Create()
profile.Money = 50000
local buy, fake, refreshes = makeService(profile)
local ok, result = buy("Generator")
local after = fake:Get(player)
check("Generateur 0 -> 1 pour 50 000 : argent a 0, niveau 1",
    ok == true and result.Level == 1 and result.Price == 50000 and after.Money == 0 and after.Base.Generator == 1)
ok, result = buy("Generator")
after = fake:Get(player)
check(("Sans argent : %s, niveau et argent inchanges"):format(tostring(result)),
    ok == false and result == "NOT_ENOUGH_MONEY" and after.Money == 0 and after.Base.Generator == 1)
local alarmProfile = Migrations:Create()
alarmProfile.Money = 25000
local buyAlarm, fakeAlarm, alarmRefreshes = makeService(alarmProfile)
local okAlarm, alarmResult = buyAlarm("Alarm")
check("Lot F3 : Alarme 0 -> 1 pour 25 000, rien a redessiner sur le plot",
    okAlarm == true and alarmResult.Price == 25000 and fakeAlarm:Get(player).Base.Alarm == 1
    and fakeAlarm:Get(player).Money == 0 and alarmRefreshes() == 0)
for _, spec in ipairs({{"Turret", 100000}, {"Trap", 30000}}) do
    local p = Migrations:Create()
    p.Money = spec[2]
    local buyOne, fakeOne, refreshedOne = makeService(p)
    local okOne, result = buyOne(spec[1])
    check(("Lot F2 : %s 0 -> 1 pour %d, plot redessine"):format(spec[1], spec[2]),
        okOne == true and result.Price == spec[2] and fakeOne:Get(player).Base[spec[1]] == 1
        and fakeOne:Get(player).Money == 0 and refreshedOne() == 1)
end
local vaultProfile = Migrations:Create()
vaultProfile.Money = 10000
local buyVault, fakeVault = makeService(vaultProfile)
local okVault, vaultResult = buyVault("Vault")
check("Lot F1 : Coffre-fort 0 -> 1 pour 10 000, argent a 0",
    okVault == true and vaultResult.Price == 10000 and fakeVault:Get(player).Base.Vault == 1
    and fakeVault:Get(player).Money == 0)
local unknown = {}
for _, key in ipairs({"Foo", "Plot", 42}) do
    local okUnknown, code = buy(key)
    if okUnknown == false and code == "BAD_UPGRADE" then table.insert(unknown, tostring(key)) end
end
local okNil, codeNil = buy(nil)
check(("Composant inconnu refuse (%s, nil)"):format(table.concat(unknown, ", ")),
    #unknown == 3 and okNil == false and codeNil == "BAD_UPGRADE")

local maxed = Migrations:Create()
maxed.Money = 1e12
maxed.Base.Generator = 3
maxed.Base.Slots = 24
local buyMax, fakeMax = makeService(maxed)
local okMax, codeMax = buyMax("Generator")
check("Generateur au niveau 3 : MAX_LEVEL", okMax == false and codeMax == "MAX_LEVEL")
local okSlot, slotResult = buyMax("Slots")
local okSlotMax, codeSlotMax = buyMax("Slots")
check("Piedestaux 24 -> 25 pour 50 000 000, puis MAX_LEVEL",
    okSlot == true and slotResult.Price == 50000000 and fakeMax:Get(player).Base.Slots == 25
    and okSlotMax == false and codeSlotMax == "MAX_LEVEL")

local fresh = Migrations:Create()
fresh.Money = 5000 + 250000
local buyFresh, fakeFresh = makeService(fresh)
local okFirstSlot, firstSlot = buyFresh("Slots")
local okRing, ring = buyFresh("TrainingRing")
check("4e piedestal a 5 000 et anneau 0 -> 1 a 250 000",
    okFirstSlot == true and firstSlot.Price == 5000 and fakeFresh:Get(player).Base.Slots == 4
    and okRing == true and ring.Price == 250000 and fakeFresh:Get(player).Base.TrainingRing == 1
    and fakeFresh:Get(player).Money == 0)

local decorProfile = Migrations:Create()
decorProfile.Money = 1000
local buyDecor, fakeDecor, decorRefreshes = makeService(decorProfile)
local okDecor, decorResult = buyDecor("Decor")
check("1re deco (pot de fleurs) a 1 000, plot redessine",
    okDecor == true and decorResult.Item == "pot_fleurs" and decorResult.Price == 1000
    and fakeDecor:Get(player).Base.Decor[1] == "pot_fleurs" and decorRefreshes() == 1)
local nearlyAll = Migrations:Create()
nearlyAll.Money = 1000000
for index = 1, DECOR_COUNT - 1 do table.insert(nearlyAll.Base.Decor, allDecor[index]) end
local buyLast, fakeLast = makeService(nearlyAll)
local okLast, lastResult = buyLast("Decor")
local okNone, codeNone = buyLast("Decor")
check("12e deco (trone) a 1 000 000, puis MAX_LEVEL",
    okLast == true and lastResult.Item == "trone" and #fakeLast:Get(player).Base.Decor == DECOR_COUNT
    and okNone == false and codeNone == "MAX_LEVEL")
check("Seules les decos redessinent le plot (generateur achete ou refuse : 0 rendu)", refreshes() == 0)

-- Rate-limit G3 : 10 requêtes par seconde et par remote, mesuré sur un service neuf, horloge figée.
local spam = Migrations:Create()
spam.Money = 0
local _, _, _, spamService = makeService(spam)
local limited, others = 0, 0
for _ = 1, 20 do
    local _, code = spamService:Buy(player, "Generator")
    if code == "RATE_LIMIT" then limited += 1 else others += 1 end
end
check(("Spam de 20 achats : %d NOT_ENOUGH_MONEY, %d RATE_LIMIT"):format(others, limited), limited > 0 and others <= 10)
task.wait(0.2) -- laisse passer les messages différés avant de couper la veille
leakWatch:Disconnect()
local shown = (logged[1] or "?"):gsub("user=%d+", "user=<id>") -- le libellé ne ressort pas l'identifiant
check(("G3 : %d achats journalises par la batterie, %d dans la sortie ; « %s »"):format(#logged, leaked, shown),
    #logged > 0 and leaked == 0
    and (logged[1] or ""):match("^%[UPGRADE%] BUY user=%d+ key=Generator level=1 price=50000$") ~= nil)

-- ── Les décos sur un plot factice ────────────────────────────────────────
local plot = Instance.new("Part")
plot.Size = Vector3.new(80, 1, 80)
plot.CFrame = CFrame.new(1000, 1.5, 1000) * CFrame.Angles(0, math.rad(-30), 0)
plot.Anchored = true
plot.Parent = workspace
local placed = DecorVisual.Render(plot, {"pot_fleurs", "trone", "inconnue", 7})
local folder = plot:FindFirstChild("Decos")
local facing, grounded = 0, 0
for _, model in ipairs(folder and folder:GetChildren() or {}) do
    local pivot = model:GetPivot()
    local toCenter = (plot.Position - pivot.Position) * Vector3.new(1, 0, 1)
    if pivot.LookVector:Dot(toCenter.Unit) > 0.99 then facing += 1 end
    if math.abs(pivot.Position.Y - (plot.Position.Y + plot.Size.Y / 2)) < 0.01 then grounded += 1 end
end
check(("Decos : %d posees sur 2 connues, au sol du plot (%d), tournees vers son centre (%d)")
    :format(placed, grounded, facing), placed == 2 and grounded == 2 and facing == 2)
DecorVisual.Render(plot, {})
check("Decos : aucune possedee, aucun dossier laisse sur le plot", plot:FindFirstChild("Decos") == nil)
plot:Destroy()

table.insert(T.lines, ("[UPGRADE TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
