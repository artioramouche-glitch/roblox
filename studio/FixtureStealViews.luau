--!nonstrict
--[[ FixtureStealViews
     Rôle    : poser ou retirer, sur le joueur réel, le scénario d'affichage du vol (alerte, rachats, portage).
     Doc     : GAME_MASTER_V2 A4, A6 §5-6 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.5 ; lot D1 (attributs publiés)
     Étape   : 5, lot D2
     Dépend  : Play serveur avec un joueur apparu ; lancé par ServerScriptService.Tests.TestRunner ;
               mode lu dans l'attribut Workspace SABL_TestMode : « on », « ghost » ou « off »
     Exposé  : bilan ; attributs StealAlertThiefUserId / StealAlertEndsAt / StealAlertCreatureId /
               StealOffers / StealState / CarryEndsAt / CarryHits du joueur réel
     Limite  : aucun profil lu ou écrit, tout disparaît à l'arrêt du Play. Les modes « on » et « ghost »
               arrêtent d'abord le StealService vivant, sinon son tick d'une seconde republie l'alerte
               et les rachats réels par-dessus le scénario : après eux, relancer le Play pour retrouver
               un serveur de vol actif.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local StealConfig = require(ReplicatedStorage.Config.StealConfig)

local MODE_ATTRIBUTE = "SABL_TestMode"
local ABSENT_USER_ID = 101 -- voleur qui n'est pas sur le serveur : la flèche doit disparaître
local GHOST_NAME = "VoleurFantome"
local CARRY_FRACTION = 1 -- portage entier : l'anneau se vide pendant le contrôle, qui lit l'horloge
local SHORT_OFFER_SECONDS = 120 -- second rachat, plus proche de l'expiration que le premier
local CARRIED_HITS = 1
-- Données de scénario : deux rachats, dont un dont la vengeance a déjà été utilisée (Q10).
local OFFERS = {
    {Id = "offer_1", CreatureId = "noobini", Tier = 1, Price = 600, ThiefName = "Voleur", TeleportUsed = false},
    {Id = "offer_2", CreatureId = "talpa", Tier = 1, Price = 1320, ThiefName = GHOST_NAME, TeleportUsed = true},
}

local mode = Workspace:GetAttribute(MODE_ATTRIBUTE)
mode = (mode == "on" or mode == "ghost" or mode == "off") and mode or "on"
local lines = {}
local function report(text) table.insert(lines, text) end

local function stopLiveService()
    local services = ServerScriptService:FindFirstChild("Services")
    local module = services and services:FindFirstChild("StealService")
    if not module then
        report("[FIXTURE] StealService introuvable : rien a arreter")
        return
    end
    local ok, service = pcall(require, module)
    if not ok then
        report("[FIXTURE] StealService non chargeable : " .. tostring(service))
        return
    end
    local stopped = pcall(function() return service:Stop() end)
    report(("[FIXTURE] StealService vivant arrete : %s (relancer le Play pour un serveur de vol actif)")
        :format(tostring(stopped)))
end

local function clear()
    player:SetAttribute("StealAlertThiefUserId", 0)
    player:SetAttribute("StealAlertEndsAt", 0)
    player:SetAttribute("StealAlertCreatureId", "")
    player:SetAttribute("StealOffers", "[]")
    player:SetAttribute("StealState", "IDLE")
    player:SetAttribute("CarryEndsAt", 0)
    player:SetAttribute("CarryHits", 0)
end

if mode == "off" then
    clear()
    report("[FIXTURE] Mode off : alerte, rachats et portage remis a zero")
else
    stopLiveService()
    local now = Workspace:GetServerTimeNow()
    local thiefUserId = mode == "ghost" and ABSENT_USER_ID or player.UserId
    local encoded = {}
    for index, offer in ipairs(OFFERS) do
        encoded[index] = {
            Id = offer.Id, CreatureId = offer.CreatureId, Tier = offer.Tier, Price = offer.Price,
            ThiefUserId = index == 1 and player.UserId or ABSENT_USER_ID, ThiefName = offer.ThiefName,
            TeleportUsed = offer.TeleportUsed,
            ExpiresAt = now + (index == 1 and StealConfig.GetBuybackWindowSeconds() or SHORT_OFFER_SECONDS),
        }
    end
    player:SetAttribute("StealAlertThiefUserId", thiefUserId)
    player:SetAttribute("StealAlertEndsAt", now + StealConfig.GetAlertSeconds())
    player:SetAttribute("StealAlertCreatureId", "noobini")
    player:SetAttribute("StealOffers", HttpService:JSONEncode(encoded))
    player:SetAttribute("StealState", "CARRYING")
    player:SetAttribute("CarryEndsAt", now + StealConfig.Thief.CarryTimeoutSeconds * CARRY_FRACTION)
    player:SetAttribute("CarryHits", CARRIED_HITS)
    report(("[FIXTURE] Mode %s : alerte voleur %d pendant %d s, %d rachats, portage %d s")
        :format(mode, thiefUserId, StealConfig.GetAlertSeconds(), #encoded,
            StealConfig.Thief.CarryTimeoutSeconds * CARRY_FRACTION))
end

local output = table.concat(lines, "\n")
print(output)
return {passed = #lines, failed = 0, success = true, output = output}
