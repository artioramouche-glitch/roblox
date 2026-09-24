--!nonstrict
--[[ FixtureDefenseVisuals
     Rôle    : montrer en jeu, sur le joueur réel et son plot, ce que les défenses dessinent côté serveur : tête de la
               tourelle tournée vers une cible, gouttes de colle sur le voleur, surlignage de l'alarme.
     Doc     : GAME_MASTER_V2 A5 ; PROMPT_EXECUTION_SABL_V4 §25.1 ; décisions 42 et 43
     Étape   : 9, lot F3
     Dépend  : Play serveur avec un joueur apparu et la tourelle du kit sur son plot (niveau 1 ou plus) ;
               Base.DefenseVisual, Services.PlacementService ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; attribut Workspace SABL_AimTarget (point visé) pour studio/TestDefenseClient.luau
     Limite  : aucun profil lu ou écrit : seulement des pièces et un surlignage sur le personnage, retirés au bout de
               45 s, tête ramenée face à l'entrée ; rien ne survit non plus à l'arrêt du Play.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local DefenseVisual = require(Server.Base.DefenseVisual)
local PlacementService = require(Server.Services.PlacementService)

local SHOW_SECONDS = 45 -- fenêtre du contrôle client : deux appels de l'outil peuvent être espacés de 10 s et plus
local TARGET_OFFSET = Vector3.new(20, 3, 0) -- 20 studs à droite de la colonne, dans le repère du plot
local TARGET_ATTRIBUTE = "SABL_AimTarget"

local character = assert(player.Character, "Personnage requis")
local plot = assert(PlacementService:PlotOf(player), "Plot du joueur requis")
local foot = DefenseVisual.TurretSpot + Vector3.new(0, plot.Size.Y / 2, 0)
local target = (plot.CFrame * CFrame.new(foot + TARGET_OFFSET)).Position
local yaw = DefenseVisual.Aim(plot, target)
Workspace:SetAttribute(TARGET_ATTRIBUTE, target)
local glue = DefenseVisual.Glue(character, SHOW_SECONDS)
local highlight = DefenseVisual.MarkThief(character, true)
task.delay(SHOW_SECONDS, function()
    DefenseVisual.MarkThief(character, false)
    DefenseVisual.Aim(plot, nil)
    Workspace:SetAttribute(TARGET_ATTRIBUTE, nil)
end)

local output = ("[FIXTURE] %s : tete de la tourelle tournee de %s deg vers (%.1f, %.1f, %.1f) ; %d gouttes et surlignage %s sur %s ; retrait dans %d s")
    :format(plot.Name, yaw and tostring(math.round(math.deg(yaw))) or "?", target.X, target.Y, target.Z,
        glue and #glue:GetChildren() or 0, highlight and "pose" or "absent", player.Name, SHOW_SECONDS)
print(output)
return {passed = yaw and glue and highlight and 1 or 0, failed = yaw and glue and highlight and 0 or 1,
    success = yaw ~= nil and glue ~= nil and highlight ~= nil, output = output}
