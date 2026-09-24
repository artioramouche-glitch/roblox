--!nonstrict
--[[ FixtureCreatureShowcase
     Rôle    : poser en Play les 30 brainrots du monde 1, construits par CreatureVisual, en vitrine.
     Doc     : GAME_MASTER_V2 H2 étape 7 (« 30 modèles vivants en jeu »), B1, G5.8, §21.2
     Étape   : 7, lot C
     Dépend  : Play serveur avec un joueur apparu ; Creatures.CreatureVisual, Config.CreatureConfig ;
               lancé par ServerScriptService.Tests.TestRunner ; mode lu dans l'attribut Workspace
               SABL_TestMode : « on » (défaut) pose la vitrine, « off » la retire
     Exposé  : Workspace.CreatureShowcase : grille de 6 × 5 devant le joueur ; bilan par rareté
     Limite  : aucun profil touché, rien ne passe par PlacementService : la vitrine montre les modèles
               tels que le jeu les sert, auras comprises. Tout disparaît à l'arrêt du Play.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local CreatureConfig = require(ReplicatedStorage.Config.CreatureConfig)
local CreatureVisual = require(Server.Creatures.CreatureVisual)

local FOLDER = "CreatureShowcase"
local COLUMNS = 6
local SPACING = 8 -- studs : assez pour que les plus larges ne se chevauchent pas
local DISTANCE = 20 -- studs devant le joueur, jusqu'au premier rang
local WORLD_ONE_COUNT = 30 -- B1 : les 30 brainrots du monde 1, dans l'ordre du bestiaire

local previous = Workspace:FindFirstChild(FOLDER)
if previous then previous:Destroy() end
local mode = Workspace:GetAttribute("SABL_TestMode")
if mode == "off" then
    local output = "[VITRINE] retiree"
    print(output)
    return {passed = 1, failed = 0, success = true, output = output}
end

local character = player.Character or player.CharacterAdded:Wait()
local origin = character:GetPivot()
local floor = origin.Position.Y - character:GetExtentsSize().Y / 2
local ahead = origin.LookVector * Vector3.new(1, 0, 1)
ahead = ahead.Magnitude > 0 and ahead.Unit or Vector3.new(0, 0, -1)
local side = Vector3.new(-ahead.Z, 0, ahead.X)

local folder = Instance.new("Folder")
folder.Name = FOLDER
local byRarity, withAura = {}, 0
for index = 1, WORLD_ONE_COUNT do
    local species = CreatureConfig.Creatures[index]
    local model = CreatureVisual.Build(species.id, 1)
    local column = (index - 1) % COLUMNS
    local row = math.floor((index - 1) / COLUMNS)
    local spot = origin.Position + ahead * (DISTANCE + row * SPACING)
        + side * ((column - (COLUMNS - 1) / 2) * SPACING)
    model:PivotTo(CFrame.lookAt(Vector3.new(spot.X, floor, spot.Z),
        Vector3.new(origin.Position.X, floor, origin.Position.Z)))
    model.Parent = folder
    byRarity[species.rarity] = (byRarity[species.rarity] or 0) + 1
    if model:FindFirstChildWhichIsA("ParticleEmitter", true) or model:FindFirstChildWhichIsA("PointLight", true) then
        withAura += 1
    end
end
folder.Parent = Workspace

local summary = {}
for _, rarity in ipairs(CreatureConfig.Rarities) do
    table.insert(summary, ("%s=%d"):format(rarity.Id, byRarity[rarity.Id] or 0))
end
local output = ("[VITRINE] %d brainrots poses devant %s, %d avec une aura\n[VITRINE] %s")
    :format(#folder:GetChildren(), player.Name, withAura, table.concat(summary, " "))
print(output)
return {passed = #folder:GetChildren(), failed = 0, success = true, output = output}
