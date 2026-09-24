--!nonstrict
--[[ PreviewShieldDome
     Rôle    : poser un dôme de démonstration sur le plot du joueur, pour la capture du lot A.
     Doc     : GAME_MASTER_V2 A4 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.5
     Étape   : 5, lot A
     Dépend  : Play serveur avec un joueur connecté possédant un plot ; Migrations, TableUtil
     Exposé  : position du plot ; profil factice au générateur 1, aucun profil réel lu ou écrit
     Limite  : le dôme est rangé dans Workspace.ShieldPreview, hors de Workspace.Effects, pour
               que l'instance réelle (générateur 0) ne le retire pas. Rien n'est démarré :
               le dôme reste figé, et tout disparaît à l'arrêt du Play.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local ShieldService = require(Server.Services.ShieldService)

-- Horloge simulée sur un cycle 1300 / 1840 : 1000 = bouclier, 1300 = alerte.
local PREVIEW_CLOCK = 1000

local profile = Migrations:Create()
profile.Base.Generator = 1
profile.ShieldEndsAt = 1300
profile.VulnerableEndsAt = 1840
local fake = {}
function fake:Get(target) return target == player and TableUtil.DeepCopy(profile) or nil end
function fake:Update(target, callback)
    if target ~= player then return false, "NO_PROFILE" end
    local candidate = TableUtil.DeepCopy(profile)
    local ok, accepted = pcall(callback, candidate)
    if not ok or accepted ~= true then return false, "REFUSED" end
    profile = candidate
    return true
end

local previous = Workspace:FindFirstChild("ShieldPreview")
if previous then previous:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "ShieldPreview"
folder.Parent = Workspace

local service = ShieldService.new({Data = fake, Effects = folder, Clock = function() return PREVIEW_CLOCK end})
service:Init()
service:Step()

local plot = nil
for _, candidate in ipairs(Workspace.Map_Monde1.Plots:GetChildren()) do
    if candidate:GetAttribute("Owner") == tostring(player.UserId) then plot = candidate end
end
local dome = folder:GetChildren()[1]
print(("[PREVIEW] phase=%s plot=%s dome=%s couleur=%s position=%s"):format(
    tostring(player:GetAttribute("ShieldState")), plot and plot.Name or "aucun",
    dome and dome.Name or "aucun", dome and dome.Color:ToHex() or "-",
    plot and tostring(plot.Position) or "-"))
return plot and plot.Position
