--!nonstrict
--[[ FixtureAlarmShow
     Rôle    : pendant la poursuite à 2 joueurs, faire sonner l'alarme d'un portage réel au niveau 2 ou 3 (attributs du
               voleur et surlignage), pour voir surlignage et flèche sans acheter ces niveaux.
     Doc     : GAME_MASTER_V2 A5 (Alarme) ; PROMPT_EXECUTION_SABL_V4 §25.1 ; décision 43 ; suggestion du lot F3
     Étape   : 10, lot 0 (sert la poursuite à 2 joueurs de l'étape 5, lot E)
     Dépend  : Play serveur ; Services.StealService (portage en cours), Base.DefenseVisual, Config.StealConfig ;
               lancé par ServerScriptService.Tests.TestRunner ; niveau lu dans l'attribut Workspace SABL_AlarmLevel
               (2 ou 3, 3 par défaut)
     Exposé  : bilan ; attributs AlarmLevel / AlarmVictimUserId / AlarmCreatureId du voleur, surlignage
     Limite  : aucun profil lu ou écrit. Sans portage en cours (contrôle en solo), le premier joueur sert de voleur
               simulé pendant 30 s, victime inconnue. Tout est retiré à la fin du portage ou du délai.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local StealService = require(Server.Services.StealService)
local DefenseVisual = require(Server.Base.DefenseVisual)

local LEVEL_ATTRIBUTE = "SABL_AlarmLevel"
local SOLO_SECONDS = 30 -- voleur simulé : le temps d'un contrôle client (appels de l'outil espacés de 10 s et plus)
local POLL_SECONDS = 0.5
local CARRYING = StealService.ThiefState.CARRYING
local DEFENSE = StealConfig.Defense

local wanted = Workspace:GetAttribute(LEVEL_ATTRIBUTE)
local level = if wanted == DEFENSE.AlarmHighlightLevel then wanted else DEFENSE.AlarmArrowLevel
local thief, session = nil, nil
for _, player in ipairs(Players:GetPlayers()) do
    local candidate = StealService:GetSession(player)
    if candidate.State == CARRYING then
        thief, session = player, candidate
        break
    end
end
local solo = thief == nil
if solo then thief = assert(Players:GetPlayers()[1], "Joueur de test requis") end

-- Même ordre que DefenseService : la victime et le brainrot d'abord, le niveau ensuite.
thief:SetAttribute("AlarmVictimUserId", if session then session.VictimUserId else 0)
thief:SetAttribute("AlarmCreatureId", if session then session.Id else "noobini")
thief:SetAttribute("AlarmLevel", level)
local highlight = DefenseVisual.MarkThief(thief.Character, level >= DEFENSE.AlarmHighlightLevel)
local endsAt = if session then session.EndsAt else Workspace:GetServerTimeNow() + SOLO_SECONDS

task.spawn(function()
    while Workspace:GetServerTimeNow() < endsAt do
        task.wait(POLL_SECONDS)
        if session and (thief.Parent == nil or StealService:GetSession(thief).State ~= CARRYING) then break end
    end
    pcall(function()
        DefenseVisual.MarkThief(thief.Character, false)
        thief:SetAttribute("AlarmLevel", 0)
        thief:SetAttribute("AlarmVictimUserId", 0)
        thief:SetAttribute("AlarmCreatureId", "")
    end)
end)

local victim = if session then tostring(session.VictimUserId) else "inconnue"
local creature = if session then tostring(session.Id) else "noobini"
local removal = if solo then ("dans %d s"):format(SOLO_SECONDS) else "a la fin du portage"
local output = ("[FIXTURE] Alarme niveau %d sur %s (%s) : victime %s, brainrot %s ; surlignage %s ; retrait %s")
    :format(level, thief.Name, if solo then "voleur simule, en solo" else "portage reel", victim, creature,
        if highlight then "pose" else "absent", removal)
print(output)
local ok = level < DEFENSE.AlarmHighlightLevel or highlight ~= nil
return {passed = if ok then 1 else 0, failed = if ok then 0 else 1, success = ok, output = output}
