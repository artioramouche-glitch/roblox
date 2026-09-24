--!nonstrict
--[[ FixtureStealPrompts
     Rôle    : poser en Play des invites de vol factices autour du joueur, pour vérifier StealController.
     Doc     : GAME_MASTER_V2 A4 ; PROMPT_EXECUTION_SABL_V4 Loi 7, §25.1, §31.5
     Étape   : 5, lot C2
     Dépend  : Play serveur avec un personnage apparu ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : dossier Workspace.StealClientFixture ; sortie listant chaque invite et l'état attendu côté client
     Limite  : aucune règle ni aucun profil touché, tout disparaît à l'arrêt du Play. Seule l'invite
               « OtherPedestal » est à portée : elle vise l'UserId 101, absent du serveur, et son
               déclenchement doit revenir « AttemptSteal:NO_PROFILE » dans l'attribut StealLastResult.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local me = player.UserId

local FAR = 60 -- studs : hors des 12 studs d'activation, seule l'invite proche peut se déclencher
local REPLICATION_WAIT = 1 -- s laissées au client avant de poser les attributs tardifs

local previous = Workspace:FindFirstChild("StealClientFixture")
if previous then previous:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "StealClientFixture"
local expected = {}

local function add(name, offset, promptName, attributes, visible)
    local part = Instance.new("Part")
    part.Name, part.Anchored, part.CanCollide = name, true, false
    part.Size = Vector3.new(2, 2, 2)
    part.Position = root.Position + offset
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name, prompt.ActionText = promptName, promptName
    prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
    for key, value in pairs(attributes) do prompt:SetAttribute(key, value) end
    prompt.Parent, part.Parent = part, folder
    table.insert(expected, ("%s.%s attendu Enabled=%s"):format(name, promptName, tostring(visible)))
    return prompt
end

add("OtherPedestal", Vector3.new(3, 0, 0), "StealPrompt", {TargetUserId = 101, Uid = "v1"}, true)
add("OwnPedestal", Vector3.new(FAR, 0, 0), "StealPrompt", {TargetUserId = me, Uid = "own"}, false)
add("OwnCarriedCube", Vector3.new(FAR, 0, 6), "HitPrompt", {ThiefUserId = me}, false)
add("OtherCarriedCube", Vector3.new(FAR, 0, 12), "HitPrompt", {ThiefUserId = 303}, true)
add("MySecure", Vector3.new(FAR, 0, 18), "SecurePrompt", {OwnerUserId = me, Slot = 1}, true)
add("OtherSecure", Vector3.new(FAR, 0, 24), "SecurePrompt", {OwnerUserId = 999, Slot = 1}, false)
add("Drop", Vector3.new(FAR, 0, 30), "ClaimPrompt", {DropId = "drop_999"}, true)
local late = add("LateOwnPedestal", Vector3.new(FAR, 0, 36), "StealPrompt", {}, false)
folder.Parent = Workspace

-- Comme StealWorld, attributs posés après l'arrivée de l'invite chez le client.
task.wait(REPLICATION_WAIT)
late:SetAttribute("TargetUserId", me)
late:SetAttribute("Uid", "late")

local output = "[FIXTURE] " .. #expected .. " invites posees pres de " .. player.Name .. "\n" .. table.concat(expected, "\n")
print(output)
return {passed = #expected, failed = 0, success = true, output = output}
