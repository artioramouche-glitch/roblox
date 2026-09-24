--!nonstrict
--[[ TestIncomeService
     Rôle    : tester le gain par clic avec un service de données factice et une horloge contrôlée.
     Doc     : GAME_MASTER_V2 C1, G3, G4 ; PROMPT_EXECUTION_SABL_V4 §18.2, §18.4
     Étape   : 3, lot A
     Dépend  : Play serveur avec un joueur connecté ; RemoteGuard, Migrations, TableUtil
     Exposé  : bilan ; aucun profil réel lu ou écrit, aucun DataStore sollicité
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
local Economy = require(ReplicatedStorage.Config.EconomyConfig)
local IncomeService = require(Server.Services.IncomeService)
local RemoteConfig = require(ReplicatedStorage.Config.RemoteConfig)

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Service de données factice : mémoire seule, jamais le profil du joueur réel.
local function makeFakeData(withProfile)
    local clockValue = 0
    local profiles = {}
    if withProfile then profiles[player] = Migrations:Create() end
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
    fake.Profiles = profiles
    return fake
end

local function makeService(withProfile)
    local fake = makeFakeData(withProfile)
    local service = IncomeService.new({Data = fake, Remote = Instance.new("RemoteEvent")})
    service:Init()
    return service, fake
end

-- 1. Un clic crédite exactement le montant de configuration.
local service, fake = makeService(true)
local ok, gain = service:Click(player)
local profile = fake:Get(player)
check("Un clic accepte", ok == true and gain == Economy.ClickGain)
check("Money = " .. Economy.ClickGain, profile.Money == Economy.ClickGain)
check("Clicks = 1", profile.Clicks == 1)
check("Stats.Earned suit le gain", profile.Stats.Earned == Economy.ClickGain)

-- 2. Loi 2 : la valeur envoyée par le client est ignorée.
local service2, fake2 = makeService(true)
service2:Click(player, 999999)
service2:Click(player, -1, {}, string.rep("a", 100000))
service2:Click(player, nil)
local profile2 = fake2:Get(player)
check("Arguments client ignores (3 clics = " .. Economy.ClickGain * 3 .. ")",
    profile2.Money == Economy.ClickGain * 3 and profile2.Clicks == 3)

-- 3. Test d'abus §18.4 : spam de 30 appels dans la même fenêtre.
local service3, fake3 = makeService(true)
local accepted, limited, otherCodes = 0, 0, {}
for _ = 1, 30 do
    local allowed, code = service3:Click(player)
    if allowed then accepted += 1
    elseif code == "RATE_LIMIT" then limited += 1
    else table.insert(otherCodes, tostring(code)) end
end
check("Spam 30/s : " .. RemoteConfig.MaxRequestsPerWindow .. " acceptes", accepted == RemoteConfig.MaxRequestsPerWindow)
check("Spam 30/s : 20 refus RATE_LIMIT", limited == 30 - RemoteConfig.MaxRequestsPerWindow and #otherCodes == 0)
check("Argent plafonne par le rate-limit", fake3:Get(player).Money == Economy.ClickGain * RemoteConfig.MaxRequestsPerWindow)

-- 4. La fenêtre suivante réaccepte les clics.
fake3.Advance(RemoteConfig.WindowSeconds)
local allowedAfter = service3:Click(player)
check("Nouvelle fenetre acceptee", allowedAfter == true
    and fake3:Get(player).Money == Economy.ClickGain * (RemoteConfig.MaxRequestsPerWindow + 1))

-- 5. Sans profil chargé : refus sans écriture.
local service5, fake5 = makeService(false)
local allowed5, code5 = service5:Click(player)
check("Sans profil : refus NO_PROFILE", allowed5 == false and code5 == "NO_PROFILE")
check("Sans profil : aucune ecriture", fake5:Get(player) == nil)

-- 6. Paramètres absurdes sur le joueur : aucun crash, aucun effet.
local service6, fake6 = makeService(true)
local badTargets = {nil, -1, {}, "joueur", workspace, string.rep("b", 100000)}
local refused = 0
for index = 1, 6 do
    local allowed6 = service6:Click(badTargets[index])
    if allowed6 == false then refused += 1 end
end
check("Cibles invalides toutes refusees", refused == 6)
check("Cibles invalides : aucune ecriture", fake6:Get(player).Money == 0)

-- 7. Après Stop, plus aucun gain.
local service7, fake7 = makeService(true)
check("Stop retourne true", service7:Stop() == true)
local allowed7, code7 = service7:Click(player)
check("Apres Stop : refus INTERNAL", allowed7 == false and code7 == "INTERNAL")
check("Apres Stop : aucune ecriture", fake7:Get(player).Money == 0)

-- 8. Le remote contractuel existe côté jeu.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local clickRemote = remotes and remotes:FindFirstChild("ClickGain")
check("Remotes.ClickGain est un RemoteEvent", clickRemote ~= nil and clickRemote:IsA("RemoteEvent"))

-- 9. Init répété reste sans effet.
local service9, fake9 = makeService(true)
service9:Init()
service9:Click(player)
check("Init idempotent", fake9:Get(player).Money == Economy.ClickGain)

-- 10. Le montant vient bien de la configuration, pas du code du service.
check("ClickGain = 5 (C1)", Economy.ClickGain == 5)
check("InventoryMax = 150 (G4)", Economy.InventoryMax == 150)
check("Quantites d'oeufs {1,10,50} (G4)", Economy.IsValidQuantity(1) and Economy.IsValidQuantity(10)
    and Economy.IsValidQuantity(50) and not Economy.IsValidQuantity(7) and not Economy.IsValidQuantity(0)
    and not Economy.IsValidQuantity(-1) and not Economy.IsValidQuantity("10") and not Economy.IsValidQuantity(1.5))

table.insert(T.lines, ("[INCOME TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
