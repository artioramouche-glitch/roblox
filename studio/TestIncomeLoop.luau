--!nonstrict
--[[ TestIncomeLoop
     Rôle    : vérifier le crédit du revenu passif, seconde par seconde.
     Doc     : GAME_MASTER_V2 B1, B3, C2, G1 ; PROMPT_EXECUTION_SABL_V4 §31.4
     Étape   : 4, lot B
     Dépend  : Play serveur avec un joueur connecté ; RemoteGuard, Migrations, TableUtil
     Exposé  : bilan ; profil factice, aucun profil réel lu ou écrit
     Limite  : l'attribut IncomePerSecond du joueur de test est écrasé pendant la
               batterie ; la boucle réelle le remet à sa valeur au tick suivant.
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

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- failTimes simule une écriture momentanément occupée par une autre action du joueur.
local function makeService(creatures, failTimes)
    local profiles = {[player] = Migrations:Create()}
    profiles[player].Creatures = creatures or {}
    local remaining = failTimes or 0
    local fake = {}
    function fake:Get(t) local s = profiles[t] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(t, cb)
        if remaining > 0 then remaining -= 1 return false, "BUSY" end
        local candidate = TableUtil.DeepCopy(profiles[t])
        local ok, accepted, result = pcall(cb, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        profiles[t] = Migrations:Apply(candidate)
        return true, result
    end
    fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return 0 end})
    local service = IncomeService.new({Data = fake, Remote = Instance.new("RemoteEvent")})
    service:Init()
    return service, fake
end

check("Periode de boucle = 1 s (G1)", Economy.IncomeTickSeconds == 1)

local idle, idleData = makeService({{Uid = "aaa", Id = "noobini", Tier = 1}})
player:SetAttribute("IncomePerSecond", 999)
local okIdle, codeIdle = idle:Credit(player, 1)
check("Inventaire non pose : aucun revenu", okIdle == false and codeIdle == "NO_INCOME")
check("Attribut remis a 0", player:GetAttribute("IncomePerSecond") == 0)
check("Argent inchange", idleData:Get(player).Money == 0)

local one, oneData = makeService({{Uid = "aaa", Id = "noobini", Tier = 1, PlacedSlot = 1}})
local okOne, gainOne = one:Credit(player, 1)
check("1 noobini pose : +10 en une seconde", okOne == true and gainOne == 10
    and oneData:Get(player).Money == 10)
check("Attribut IncomePerSecond = 10", player:GetAttribute("IncomePerSecond") == 10)
check("Stats.Earned suit le revenu", oneData:Get(player).Stats.Earned == 10)
one:Credit(player, 5)
check("5 secondes d'un coup : +50", oneData:Get(player).Money == 60)

local mixed, mixedData = makeService({
    {Uid = "a", Id = "noobini", Tier = 1, PlacedSlot = 1},
    {Uid = "b", Id = "trippi", Tier = 2, PlacedSlot = 2},
    {Uid = "c", Id = "tralalero", Tier = 5},
})
mixed:Credit(player, 1)
check("Base mixte : 10 + 195 = 205, la creature non posee ne produit rien",
    mixedData:Get(player).Money == 205 and player:GetAttribute("IncomePerSecond") == 205)

local busy, busyData = makeService({{Uid = "a", Id = "noobini", Tier = 1, PlacedSlot = 1}}, 3)
local okBusy, codeBusy = busy:Credit(player, 1)
check("Ecriture occupee : refus signale", okBusy == false and codeBusy == "BUSY")
busy:Credit(player, 1)
busy:Credit(player, 1)
check("Toujours rien credite pendant l'indisponibilite", busyData:Get(player).Money == 0)
local okRetry, gainRetry = busy:Credit(player, 1)
check("Rattrapage des 4 secondes dues : +40", okRetry == true and gainRetry == 40
    and busyData:Get(player).Money == 40)

local capped, cappedData = makeService({{Uid = "a", Id = "noobini", Tier = 1, PlacedSlot = 1}}, 200)
for _ = 1, 200 do capped:Credit(player, 1) end
local okCapped, gainCapped = capped:Credit(player, 1)
check("Arriere plafonne a 60 s : +600 et pas davantage", okCapped == true and gainCapped == 600
    and cappedData:Get(player).Money == 600)

local ticked, tickedData = makeService({{Uid = "a", Id = "tim_cheese", Tier = 1, PlacedSlot = 1}})
ticked:Tick(2)
check("Tick(2) credite 2 secondes de tim_cheese : +24", tickedData:Get(player).Money == 24)
ticked:Tick(0)
check("Tick(0) ne credite rien", tickedData:Get(player).Money == 24)
check("Stop retourne true", ticked:Stop() == true)
local okStopped = ticked:Credit(player, 1)
check("Apres Stop : plus aucun credit", okStopped == false and tickedData:Get(player).Money == 24)

table.insert(T.lines, ("[INCOME LOOP TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
print(table.concat(T.lines, "\n"))
return {passed = T.pass, failed = T.fail, success = T.fail == 0}
