--!nonstrict
--[[ FixtureReserveView
     Rôle    : montrer au client, sans rien écrire, l'état d'après un rebirth : tous ses brainrots en Réserve d'or.
     Doc     : GAME_MASTER_V2 C3, A6 §3 et §7 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.9 lot E ; décision 32
     Étape   : 9, lot E
     Dépend  : Play serveur avec un joueur connecté ; Config.DefaultProfile, Shared.TableUtil, Services.DataService,
               Remotes.SyncProfile ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; pendant FIXTURE_SECONDS, un instantané factice part vers le joueur par SyncProfile dix fois
               par seconde : copie de son profil avec un rebirth de plus, argent et base à zéro, brainrots en
               réserve. Attribut Workspace SABL_FixtureRebirth = palier que l'écran doit alors proposer
     Limite  : rien n'est écrit, ni dans le profil ni dans le magasin ; la synchronisation réelle (une par seconde)
               reprend la main ensuite. Pendant ce temps, tous les écrans affichent l'instantané factice.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local DefaultProfile = require(ReplicatedStorage.Config.DefaultProfile)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local DataService = require(Server.Services.DataService)
local sync = ReplicatedStorage.Remotes.SyncProfile

local FIXTURE_SECONDS = 40 -- plusieurs secondes séparent deux appels de l'outil : la fenêtre doit les couvrir
local PERIOD = 0.1
local EXPECTED_ATTRIBUTE = "SABL_FixtureRebirth"

-- Même remise à zéro que RebirthService, appliquée à une copie qui ne quitte jamais cette fixture.
local snapshot = TableUtil.DeepCopy(assert(DataService:Get(player), "Profil du joueur absent"))
snapshot.Rebirths = (tonumber(snapshot.Rebirths) or 0) + 1
snapshot.Money = 0
for key, default in pairs(DefaultProfile.Base) do
    snapshot.Base[key] = if type(default) == "table" then {} else default
end
for _, creature in ipairs(snapshot.Creatures) do
    creature.PlacedSlot = nil
    creature.Reserve = true
end
Workspace:SetAttribute(EXPECTED_ATTRIBUTE, snapshot.Rebirths + 1)
task.spawn(function()
    local deadline = os.clock() + FIXTURE_SECONDS
    while os.clock() < deadline and player.Parent do
        sync:FireClient(player, snapshot)
        task.wait(PERIOD)
    end
end)

local output = ("[RESERVE FIXTURE] %d brainrots en reserve, rebirth %d affiche %d s, rien d'ecrit")
    :format(#snapshot.Creatures, snapshot.Rebirths, FIXTURE_SECONDS)
print(output)
return {passed = 1, failed = 0, success = true, output = output}
