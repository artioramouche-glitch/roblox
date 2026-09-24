--!nonstrict
--[[ TestEggService
     Rôle    : vérifier les odds B2, les validations de BuyEgg et l'atomicité des achats.
     Doc     : GAME_MASTER_V2 B2, G4, G5.2 ; PROMPT_EXECUTION_SABL_V4 §18.2, §18.4, §25.2
     Étape   : 3, lot B
     Dépend  : Play serveur avec un joueur connecté ; RemoteGuard, Migrations, TableUtil
     Exposé  : bilan ; service de données factice, aucun profil réel lu ou écrit
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
local EggConfig = require(ReplicatedStorage.Config.EggConfig)
local CreatureConfig = require(ReplicatedStorage.Config.CreatureConfig)
local Economy = require(ReplicatedStorage.Config.EconomyConfig)
local RemoteConfig = require(ReplicatedStorage.Config.RemoteConfig)
local EggService = require(Server.Services.EggService)

local DRAWS = 1000
local TOLERANCE = 5
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local function makeFakeData(seed)
    local clockValue = 0
    local profiles = {[player] = Migrations:Create()}
    local fake = {}
    function fake:Get(target)
        local stored = profiles[target]
        return stored and TableUtil.DeepCopy(stored) or nil
    end
    function fake:Update(target, callback)
        local current = profiles[target]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(callback, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        profiles[target] = reconciled
        return true, result
    end
    fake.Guard = RemoteGuard.new(function(target) return fake:Get(target) end,
        {Clock = function() return clockValue end})
    fake.Advance = function(seconds) clockValue += seconds end
    fake.Set = function(field, value) profiles[player][field] = value end
    return fake
end

local function makeService(seed)
    local fake = makeFakeData(seed)
    local service = EggService.new({
        Data = fake,
        Remote = Instance.new("RemoteFunction"),
        Rng = Random.new(seed or 20260912),
    })
    service:Init()
    return service, fake
end

-- 1. Batterie PROBABILITÉS §25.2 : les 8 œufs, 1000 tirages chacun.
local service, fake = makeService()
for _, egg in ipairs(EggConfig.Eggs) do
    local counts = {}
    for _ = 1, DRAWS do
        local rarity = service:_rollRarity(egg.id)
        counts[rarity] = (counts[rarity] or 0) + 1
    end
    local worst, worstRarity, total = 0, "", 0
    for rarity, expected in pairs(egg.odds) do
        local got = (counts[rarity] or 0) / DRAWS * 100
        local gap = math.abs(got - expected)
        if gap > worst then worst = gap worstRarity = rarity end
        total += counts[rarity] or 0
    end
    check(("%s : ecart max %.1f pt sur %s (tolerance %d)"):format(egg.id, worst, worstRarity, TOLERANCE),
        worst <= TOLERANCE and total == DRAWS)
end

-- 2. La créature tirée appartient au pool et porte la rareté demandée.
local poolValid, rarityValid = true, true
for _, egg in ipairs(EggConfig.Eggs) do
    local allowed = {}
    for _, id in ipairs(egg.pool) do allowed[id] = true end
    for _ = 1, 200 do
        local rarity = service:_rollRarity(egg.id)
        local id = service:_rollCreature(egg.id, rarity)
        if not id or not allowed[id] then poolValid = false break end
        local creature = CreatureConfig:Get(id)
        if not creature or creature.rarity ~= rarity then rarityValid = false break end
    end
end
check("Creature tiree toujours dans le pool de l'oeuf", poolValid)
check("Creature tiree toujours de la rarete tiree", rarityValid)
check("Oeuf inconnu : aucun tirage", service:_rollRarity("egg_inexistant") == nil
    and service:_rollCreature("egg_basic", "Secret") == nil)

-- 3. Achat ×1 : débit exact, une créature ajoutée, Tier 1.
local buy1, fake1 = makeService()
fake1.Set("Money", 1000000)
local ok1, result1 = buy1:Buy(player, "egg_basic", 1)
local profile1 = fake1:Get(player)
local basic = EggConfig:Get("egg_basic")
check("Achat x1 accepte", ok1 == true and type(result1) == "table" and #result1.Results == 1)
check("Debit exact du prix (" .. basic.price .. ")", profile1.Money == 1000000 - basic.price
    and result1.Spent == basic.price)
check("Une creature ajoutee au Tier 1", #profile1.Creatures == 1 and profile1.Creatures[1].Tier == 1
    and type(profile1.Creatures[1].Uid) == "string" and #profile1.Creatures[1].Uid == 8)
check("Stats.EggsOpened incremente", profile1.Stats.EggsOpened == 1)

-- 4. Achats ×10 et ×50 : quantités et débits exacts.
local buy10, fake10 = makeService()
fake10.Set("Money", 1000000)
local ok10, result10 = buy10:Buy(player, "egg_basic", 10)
local profile10 = fake10:Get(player)
check("Achat x10 : 10 creatures, debit x10", ok10 == true and #result10.Results == 10
    and #profile10.Creatures == 10 and profile10.Money == 1000000 - basic.price * 10)
local ok50, result50 = buy10:Buy(player, "egg_basic", 50)
local profile50 = fake10:Get(player)
check("Achat x50 : 60 creatures au total", ok50 == true and #result50.Results == 50
    and #profile50.Creatures == 60)
local uids = {}
local uniqueUids = true
for _, creature in ipairs(profile50.Creatures) do
    if uids[creature.Uid] then uniqueUids = false end
    uids[creature.Uid] = true
end
check("60 Uid tous distincts", uniqueUids)

-- 5. Quantités refusées (G4 : 1, 10 ou 50 uniquement).
local badQty, fakeQty = makeService()
fakeQty.Set("Money", 1000000)
local badQuantities = {7, 0, -1, 1.5, 100, 2}
local refusedQty = 0
for _, quantity in ipairs(badQuantities) do
    local allowed, code = badQty:Buy(player, "egg_basic", quantity)
    if allowed == false and code == "BAD_QTY" then refusedQty += 1 end
end
local strQty = select(2, badQty:Buy(player, "egg_basic", "10"))
local nilQty = select(2, badQty:Buy(player, "egg_basic", nil))
check("Quantites invalides refusees BAD_QTY", refusedQty == #badQuantities
    and strQty == "BAD_QTY" and nilQty == "BAD_QTY")
check("Quantites invalides : aucune ecriture", fakeQty:Get(player).Money == 1000000
    and #fakeQty:Get(player).Creatures == 0)

-- 6. Œufs invalides.
local badEgg, fakeEgg = makeService()
fakeEgg.Set("Money", 1000000)
local badEggs = {"egg_inexistant", "", 123, {}, true}
local refusedEgg = 0
for index = 1, 5 do
    local allowed, code = badEgg:Buy(player, badEggs[index], 1)
    if allowed == false and code == "BAD_EGG" then refusedEgg += 1 end
end
local nilEgg = select(2, badEgg:Buy(player, nil, 1))
check("Oeufs invalides refuses BAD_EGG", refusedEgg == 5 and nilEgg == "BAD_EGG")

-- 7. Monde verrouillé (egg_dessert exige le monde 2).
local locked, fakeLocked = makeService()
fakeLocked.Set("Money", 1000000000)
local allowedLocked, codeLocked = locked:Buy(player, "egg_dessert", 1)
check("Oeuf du monde 2 refuse WORLD_LOCKED", allowedLocked == false and codeLocked == "WORLD_LOCKED")
check("Monde verrouille : aucune ecriture", fakeLocked:Get(player).Money == 1000000000)

-- 8. Argent insuffisant : refus et aucune écriture.
local poor, fakePoor = makeService()
fakePoor.Set("Money", basic.price - 1)
local allowedPoor, codePoor = poor:Buy(player, "egg_basic", 1)
local profilePoor = fakePoor:Get(player)
check("Sans argent : refus NOT_ENOUGH_MONEY", allowedPoor == false and codePoor == "NOT_ENOUGH_MONEY")
check("Sans argent : ni debit ni creature", profilePoor.Money == basic.price - 1
    and #profilePoor.Creatures == 0)
local allowedPoor10 = poor:Buy(player, "egg_basic", 10)
check("x10 impayable refuse", allowedPoor10 == false and fakePoor:Get(player).Money == basic.price - 1)

-- 9. Plafond d'inventaire (G4 : 150).
local full, fakeFull = makeService()
fakeFull.Set("Money", 100000000)
local stock = {}
for position = 1, Economy.InventoryMax do
    stock[position] = {Uid = ("stock%04d"):format(position), Id = "noobini", Tier = 1}
end
fakeFull.Set("Creatures", stock)
local allowedFull, codeFull = full:Buy(player, "egg_basic", 1)
check("Inventaire plein : refus INVENTORY_FULL", allowedFull == false and codeFull == "INVENTORY_FULL")
local partial = {}
for position = 1, Economy.InventoryMax - 5 do
    partial[position] = {Uid = ("stock%04d"):format(position), Id = "noobini", Tier = 1}
end
fakeFull.Set("Creatures", partial)
local allowedOver, codeOver = full:Buy(player, "egg_basic", 10)
check("145 + 10 refuse (depassement)", allowedOver == false and codeOver == "INVENTORY_FULL")
local allowedFit = full:Buy(player, "egg_basic", 1)
check("145 + 1 accepte", allowedFit == true and #fakeFull:Get(player).Creatures == Economy.InventoryMax - 4)

-- 10. Test d'abus §18.4 : rafale de 30 achats.
local spam, fakeSpam = makeService()
fakeSpam.Set("Money", 1000000)
local accepted, limited = 0, 0
for _ = 1, 30 do
    local allowed, code = spam:Buy(player, "egg_basic", 1)
    if allowed then accepted += 1 elseif code == "RATE_LIMIT" then limited += 1 end
end
check("Spam 30 achats : " .. RemoteConfig.MaxRequestsPerWindow .. " acceptes",
    accepted == RemoteConfig.MaxRequestsPerWindow and limited == 30 - RemoteConfig.MaxRequestsPerWindow)
check("Spam : debit coherent avec les achats acceptes",
    fakeSpam:Get(player).Money == 1000000 - basic.price * RemoteConfig.MaxRequestsPerWindow)

-- 11. Après Stop, plus aucun achat.
local stopped, fakeStopped = makeService()
fakeStopped.Set("Money", 1000000)
check("Stop retourne true", stopped:Stop() == true)
local allowedStopped, codeStopped = stopped:Buy(player, "egg_basic", 1)
check("Apres Stop : refus INTERNAL", allowedStopped == false and codeStopped == "INTERNAL")
check("Apres Stop : aucune ecriture", fakeStopped:Get(player).Money == 1000000)

-- 12. Le remote contractuel existe côté jeu.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local buyRemote = remotes and remotes:FindFirstChild("BuyEgg")
check("Remotes.BuyEgg est une RemoteFunction", buyRemote ~= nil and buyRemote:IsA("RemoteFunction"))

table.insert(T.lines, ("[EGG TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
