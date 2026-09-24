--!nonstrict
--[[ TestPlacement
     Rôle    : vérifier les formules économiques et les validations de placement.
     Doc     : GAME_MASTER_V2 A5, B1, B3, C2, G4 ; PROMPT_EXECUTION_SABL_V4 §18.2, §18.4
     Étape   : 4, lot A ; contrôle du rendu 3D ajouté à l'étape 6, lot B1
     Dépend  : Play serveur avec un joueur connecté ; RemoteGuard, Migrations, TableUtil ;
               lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; plots factices et profil factice, Workspace.Map_Monde1 jamais touché
     Limite  : le rate-limit se mesure sur un service neuf ; l'horloge de test étant
               figée, des appels antérieurs consommeraient le quota de la fenêtre.
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
local PlacementService = require(Server.Services.PlacementService)

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local function makeMap(offset)
    local map = Instance.new("Folder")
    local plots = Instance.new("Folder")
    plots.Name = "Plots"
    plots.Parent = map
    for index = 1, 2 do
        local plot = Instance.new("Part")
        plot.Name = "Plot" .. index
        plot.Anchored = true
        plot.Size = Vector3.new(80, 1, 80)
        plot.Position = Vector3.new((offset or 0) + index * 200, 1.5, 0)
        plot:SetAttribute("Owner", "")
        local folder = Instance.new("Folder")
        folder.Name = "Pedestals"
        folder.Parent = plot
        for slot = 1, 25 do
            local pedestal = Instance.new("Part")
            pedestal.Name = "Pedestal" .. slot
            pedestal.Anchored = true
            pedestal.Size = Vector3.new(3, 1, 3)
            pedestal.Position = plot.Position + Vector3.new(slot, 1, 0)
            pedestal:SetAttribute("Slot", slot)
            pedestal:SetAttribute("Uid", "")
            pedestal.Parent = folder
        end
        plot.Parent = plots
    end
    return map
end

local function makeService(creatures, slots, offset)
    local clockValue = 0
    local profiles = {[player] = Migrations:Create()}
    profiles[player].Creatures = creatures or {}
    if slots then profiles[player].Base.Slots = slots end
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
    fake.Advance = function(seconds) clockValue += seconds end
    local map = makeMap(offset)
    local service = PlacementService.new({
        Data = fake, Map = map,
        PlaceRemote = Instance.new("RemoteFunction"),
        UnplaceRemote = Instance.new("RemoteFunction"),
        SellRemote = Instance.new("RemoteFunction"),
    })
    service:Init()
    return service, fake, map
end

-- Formules B1 × B3 × SellMult (option A validée par le Producer).
check("Revenu noobini Normal = 10 (B1)", EconomyUtil.GetCreatureIncome("noobini", 1) == 10)
check("Revenu noobini Dore = 30 (B1 x B3)", EconomyUtil.GetCreatureIncome("noobini", 2) == 30)
check("Revenu tralalero Celeste = 13 500 000", EconomyUtil.GetCreatureIncome("tralalero", 5) == 90000 * 150)
check("Vente noobini Normal = 400 (10 x 0.4 x 100)", EconomyUtil.GetSellPrice("noobini", 1) == 400)
check("Vente noobini Dore = 1200", EconomyUtil.GetSellPrice("noobini", 2) == 1200)
check("Vente bombardiro Mythic = 750 000 (15000 x 0.5 x 100)",
    EconomyUtil.GetSellPrice("bombardiro", 1) == 750000)
check("Creature inconnue : revenu et prix nuls",
    EconomyUtil.GetCreatureIncome("inexistant", 1) == 0 and EconomyUtil.GetSellPrice("inexistant", 1) == 0)
check("Tier invalide : revenu nul", EconomyUtil.GetCreatureIncome("noobini", 9) == 0)

local service, fake, map = makeService({
    {Uid = "aaa", Id = "noobini", Tier = 1},
    {Uid = "bbb", Id = "tim_cheese", Tier = 1},
    {Uid = "ccc", Id = "trippi", Tier = 2},
    {Uid = "ddd", Id = "noobini", Tier = 1},
})
service:Start()
task.wait(1)
local plot1 = map.Plots.Plot1
check("Plot attribue et marque au proprietaire", plot1:GetAttribute("Owner") == tostring(player.UserId))
check("Base.Plot enregistre dans le profil", fake:Get(player).Base.Plot == 1)

local okPlace, placed = service:Place(player, "aaa", 1)
check("Placement slot 1 accepte", okPlace == true and placed.PlacedSlot == 1)
check("PlacedSlot ecrit dans le profil", fake:Get(player).Creatures[1].PlacedSlot == 1)
local model = plot1.Pedestals.Pedestal1:FindFirstChild("Placed")
local posed = model and model:FindFirstChild("CRT_noobini")
local pedestal1 = plot1.Pedestals.Pedestal1
check("CRT_noobini pose sur le piedestal : un Model, modele du batch ou cube de repli (Loi 5)",
    posed ~= nil and posed:IsA("Model") and posed:GetAttribute("CreatureId") == "noobini"
    and pedestal1:GetAttribute("Uid") == "aaa")
check("Etape 6 : le modele repose sur le dessus du piedestal, pivot au sol",
    posed ~= nil and math.abs(posed:GetPivot().Position.Y - (pedestal1.Position.Y + pedestal1.Size.Y / 2)) < 0.05)

check("Slot deja occupe refuse SLOT_TAKEN", select(2, service:Place(player, "bbb", 1)) == "SLOT_TAKEN")
check("Creature deja placee refusee ALREADY_PLACED", select(2, service:Place(player, "aaa", 2)) == "ALREADY_PLACED")
check("Slot 4 refuse (Base.Slots = 3) NO_SLOT", select(2, service:Place(player, "bbb", 4)) == "NO_SLOT")
check("Slot 0 et negatif refuses", select(2, service:Place(player, "bbb", 0)) == "NO_SLOT"
    and select(2, service:Place(player, "bbb", -1)) == "NO_SLOT")
check("Uid inconnu refuse NOT_OWNER", select(2, service:Place(player, "zzz", 2)) == "NOT_OWNER")
check("Uid non textuel refuse", select(2, service:Place(player, 42, 2)) == "NOT_OWNER")
check("Aucune ecriture apres les refus", #fake:Get(player).Creatures == 4
    and fake:Get(player).Creatures[2].PlacedSlot == nil)

fake.Advance(RemoteConfig.WindowSeconds)
service:Place(player, "ccc", 2)
local profile = fake:Get(player)
check("Revenu total = 10 + 195 = 205 (B1 x B3)", EconomyUtil.GetTotalIncome(profile) == 205)
profile.Rebirths = 2
check("Rebirth x2 par rebirth : 205 x 4 = 820 (C2)", EconomyUtil.GetTotalIncome(profile) == 820)

-- Loi 5 : tant qu'une créature n'a pas son modèle, le cube gris tient la place.
local secondHolder = plot1.Pedestals.Pedestal2:FindFirstChild("Placed")
local second = secondHolder and secondHolder:FindFirstChild("CRT_trippi")
check("Loi 5 : sans modele 3D, un cube gris de repli est pose a la place",
    second ~= nil and second:IsA("Model")
    and (second:GetAttribute("Placeholder") == false or second:FindFirstChild("Cube") ~= nil))

local okUnplace = service:Unplace(player, "aaa")
check("Retrait accepte", okUnplace == true and fake:Get(player).Creatures[1].PlacedSlot == nil)
check("Piedestal libere", plot1.Pedestals.Pedestal1:FindFirstChild("Placed") == nil
    and plot1.Pedestals.Pedestal1:GetAttribute("Uid") == "")
check("Retrait d'une creature non placee refuse", select(2, service:Unplace(player, "aaa")) == "NOT_PLACED")

local moneyBefore = fake:Get(player).Money
local okSell, sold = service:Sell(player, "aaa")
check("Vente acceptee au prix attendu", okSell == true and sold.Price == 400)
check("Argent credite et creature retiree",
    fake:Get(player).Money == moneyBefore + 400 and #fake:Get(player).Creatures == 3)
check("Vente d'une creature placee refusee", select(2, service:Sell(player, "ccc")) == "ALREADY_PLACED")
check("Vente d'un Uid inconnu refusee", select(2, service:Sell(player, "aaa")) == "NOT_OWNER")
service:Stop()

-- Engagement PvP : lecture seule ici, ArenaService marquera le champ à l'étape 13.
local engaged = makeService({{Uid = "eee", Id = "noobini", Tier = 1, InPvPTeam = "A"}}, nil, 1000)
engaged:Start()
task.wait(0.6)
check("Creature engagee : placement refuse IN_ARENA",
    select(2, engaged:Place(player, "eee", 1)) == "IN_ARENA")
check("Creature engagee : vente refusee IN_ARENA",
    select(2, engaged:Sell(player, "eee")) == "IN_ARENA")
engaged:Stop()

-- §18.4 : rate-limit mesuré sur un service neuf, 30 placements tous valides.
local many = {}
for index = 1, 30 do many[index] = {Uid = ("u%02d"):format(index), Id = "noobini", Tier = 1} end
local spam, spamData = makeService(many, 25, 2000)
spam:Start()
task.wait(0.6)
local accepted, limited, other = 0, 0, 0
for index = 1, 30 do
    local ok, code = spam:Place(player, ("u%02d"):format(index), index)
    if ok then accepted += 1 elseif code == "RATE_LIMIT" then limited += 1 else other += 1 end
end
local placedCount = 0
for _, creature in ipairs(spamData:Get(player).Creatures) do
    if creature.PlacedSlot ~= nil then placedCount += 1 end
end
local max = RemoteConfig.MaxRequestsPerWindow
check(("Spam 30 placements : %d acceptes, %d RATE_LIMIT, %d autres"):format(accepted, limited, other),
    accepted == max and limited == 30 - max and other == 0)
check("Seules les creatures acceptees sont posees", placedCount == max)
spamData.Advance(RemoteConfig.WindowSeconds)
check("Fenetre suivante : placement de nouveau accepte", spam:Place(player, "u11", 11) == true)
check("Stop retourne true", spam:Stop() == true)

table.insert(T.lines, ("[PLACEMENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
