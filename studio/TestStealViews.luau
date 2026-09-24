--!nonstrict
--[[ TestStealViews
     Rôle    : batterie du lot D1 : attributs d'alerte et de rachat, téléportations Q9-Q10, remotes hors G4.
     Doc     : GAME_MASTER_V2 A4, A6 §5, G4 ; PROMPT_EXECUTION_SABL_V4 §18.3, §18.4, §25.2 ; Q9-Q10 option A
     Étape   : 5, lot D1
     Dépend  : Play serveur avec un joueur connecté ; Migrations, TableUtil, RemoteGuard, RemoteConfig,
               ShieldService.BaseState, StealService, Shared.ErrorMessages
     Exposé  : bilan ; le joueur réel sert de victime et d'appelant (attributs et RemoteGuard exigent un vrai
               Player), avec profil, voleur, plots et horloges factices
     Limite  : aucun profil réel lu ou écrit ; la téléportation est enregistrée, jamais exécutée. Les attributs
               du joueur réel sont écrasés pendant la batterie puis remis au neutre par Stop ; l'instance
               réelle republie l'alerte et les rachats au tick suivant, l'état de voleur seulement à sa
               prochaine transition : à lancer hors vol réel en cours.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local RemoteConfig = require(ReplicatedStorage.Config.RemoteConfig)
local ErrorMessages = require(ReplicatedStorage.Shared.ErrorMessages)
local ShieldService = require(Server.Services.ShieldService)
local StealService = require(Server.Services.StealService)
local B = ShieldService.BaseState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- §18.3 : chaque code du vol a sa traduction ; les chiffres viennent de StealConfig.
local translated = true
for _, code in ipairs({"ON_COOLDOWN", "TARGET_SHIELDED", "TOO_FAR", "LEVEL_TOO_LOW", "TARGET_PROTECTED",
    "ALREADY_CARRYING", "NOT_CARRYING", "SECURE_NOT_READY", "DROP_GONE", "BUYBACK_GONE", "NO_TELEPORT"}) do
    translated = translated and ErrorMessages.Codes[code] ~= nil and ErrorMessages.Get(code) ~= ErrorMessages.Codes.INTERNAL
end
check("ErrorMessages : 11 codes du vol traduits", translated)
check("LEVEL_TOO_LOW cite niveau 5 et 60 min (A4, depuis StealConfig)",
    ErrorMessages.Get("LEVEL_TOO_LOW"):find("niveau 5", 1, true) ~= nil and ErrorMessages.Get("LEVEL_TOO_LOW"):find("60 min", 1, true) ~= nil)
check("Codes existants inchanges (NO_SLOT, INVENTORY_FULL 150)", ErrorMessages.Get("NO_SLOT") == "Plus de piédestal libre."
    and ErrorMessages.Get("INVENTORY_FULL"):find("150", 1, true) ~= nil)

local function makeScenario()
    local s = {clock = 10000, guardClock = 0, profiles = {}, positions = {}, present = {}, plots = {}, teleports = {}}
    local data = {}
    function data:Get(p) local v = s.profiles[p] return v and TableUtil.DeepCopy(v) or nil end
    function data:Update(p, callback)
        local current = s.profiles[p]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(callback, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        s.profiles[p] = reconciled
        return true, result
    end
    data.Guard = RemoteGuard.new(function(p) return data:Get(p) end, {Clock = function() return s.guardClock end})
    local shield = {BaseState = B}
    function shield:GetPhase() return B.VULNERABLE end
    local placement = {}
    function placement:PlotOf(p) return s.plots[p] end
    function placement:Refresh() return true end
    s.thief = {Name = "Voleur", UserId = 303}
    s.other = {Name = "Autre", UserId = 404}
    local byId = {[303] = s.thief, [404] = s.other, [player.UserId] = player}
    local function addProfile(p, x, creatures, overrides)
        local profile = Migrations:Create()
        profile.Level, profile.Playtime = 5, 3600
        profile.Creatures = creatures or {}
        for key, value in pairs(overrides or {}) do profile[key] = value end
        s.profiles[p], s.present[p] = profile, true
        local plot = Instance.new("Part")
        plot.Size, plot.Position = Vector3.new(80, 1, 80), Vector3.new(x, 1.5, 0)
        local lintel = Instance.new("Part")
        lintel.Name, lintel.Position, lintel.Parent = "EntranceLintel", Vector3.new(x, 10, -40), plot
        local folder = Instance.new("Folder")
        folder.Name, folder.Parent = "Pedestals", plot
        for slot = 1, 3 do
            local pedestal = Instance.new("Part")
            pedestal.Name = "Pedestal" .. slot
            pedestal.Position, pedestal.Parent = plot.Position + Vector3.new(slot * 4, 1, 0), folder
        end
        s.plots[p] = plot
    end
    addProfile(player, 0, {{Uid = "p1", Id = "noobini", Tier = 1, PlacedSlot = 1}}, {Money = 1000})
    addProfile(s.thief, 300)
    addProfile(s.other, 600, {{Uid = "o1", Id = "noobini", Tier = 1, PlacedSlot = 1}})
    s.pedestal = function(p, slot) return s.plots[p].Pedestals["Pedestal" .. slot].Position end
    s.remoteFolder = Instance.new("Folder")
    s.service = StealService.new({
        Data = data, Shield = shield, Placement = placement, Clock = function() return s.clock end,
        IsPresent = function(p) return p == player or s.present[p] == true end,
        Characters = {
            GetPosition = function(p) return s.positions[p] end,
            SetSpeedMultiplier = function() end,
            Teleport = function(p, cframe) table.insert(s.teleports, {player = p, cframe = cframe}) return true end,
        },
        ListPlayers = function() return {player, s.thief, s.other} end,
        ResolvePlayer = function(id) return byId[id] end,
        RemoteFolder = s.remoteFolder, World = false,
    })
    s.service:Init()
    s.service:Start()
    return s
end
local function offersOf() return HttpService:JSONDecode(player:GetAttribute("StealOffers") or "[]") end
local function near(a, b) return (a - b).Magnitude < 0.01 end

local s = makeScenario()
local classes = {}
for _, child in ipairs(s.remoteFolder:GetChildren()) do classes[child.Name] = child.ClassName end
check("Remotes hors G4 TeleportToBase et BuybackCreature crees (RemoteFunction), 5 au total",
    classes.TeleportToBase == "RemoteFunction" and classes.BuybackCreature == "RemoteFunction" and #s.remoteFolder:GetChildren() == 5)
s.service:Step()
check("Sans vol : alerte a 0 et aucun rachat", player:GetAttribute("StealAlertThiefUserId") == 0
    and player:GetAttribute("StealAlertEndsAt") == 0 and #offersOf() == 0)
check("Q9 : Y ALLER sans vol en cours : NO_TELEPORT", select(2, s.service:Remote("TeleportToBase", player, player.UserId)) == "NO_TELEPORT")

s.positions[s.thief] = s.pedestal(player, 1)
check("Preparation : le voleur factice vole p1 au joueur", s.service:AttemptSteal(s.thief, player, "p1") == true)
check("A6 §5 : alerte publiee (voleur 303, fin 10060, noobini)", player:GetAttribute("StealAlertThiefUserId") == 303
    and player:GetAttribute("StealAlertEndsAt") == 10060 and player:GetAttribute("StealAlertCreatureId") == "noobini")
local okHome = s.service:Remote("TeleportToBase", player, player.UserId)
check("Q9 : Y ALLER pendant le vol : teleporte a l'entree de sa base", okHome == true and #s.teleports == 1
    and s.teleports[1].player == player and near(s.teleports[1].cframe.Position, Vector3.new(0, 5, -40)))
check("Q10 : vers le voleur avant la pose : NO_TELEPORT", select(2, s.service:Remote("TeleportToBase", player, 303)) == "NO_TELEPORT")

s.positions[s.thief] = s.pedestal(s.thief, 1)
s.service:BeginSecure(s.thief, 1)
s.clock += 5
local okSecure = s.service:CompleteSecure(s.thief)
local list = offersOf()
check("Pose du voleur : alerte retiree", okSecure == true and player:GetAttribute("StealAlertThiefUserId") == 0)
check("A4 : rachat publie (prix 600, voleur 303 nomme, teleportation disponible)", #list == 1 and list[1].Price == 600
    and list[1].ThiefUserId == 303 and list[1].ThiefName == "Voleur" and list[1].TeleportUsed == false)
check("Q9 : Y ALLER apres la pose : NO_TELEPORT", select(2, s.service:Remote("TeleportToBase", player, player.UserId)) == "NO_TELEPORT")
local okRevenge = s.service:Remote("TeleportToBase", player, 303)
check("Q10 : vengeance : teleporte a l'entree de la base du voleur", okRevenge == true and #s.teleports == 2
    and near(s.teleports[2].cframe.Position, Vector3.new(300, 5, -40)))
list = offersOf()
check("Q10 : teleportation marquee utilisee dans le rachat", #list == 1 and list[1].TeleportUsed == true)
check("Q10 : seconde vengeance : NO_TELEPORT", select(2, s.service:Remote("TeleportToBase", player, 303)) == "NO_TELEPORT")
check("Q10 : joueur sans lien avec le vol : NO_TELEPORT", select(2, s.service:Remote("TeleportToBase", player, 404)) == "NO_TELEPORT")
local okBuy, bought = s.service:Remote("BuybackCreature", player, list[1] and list[1].Id)
check("Remote BuybackCreature : rachat a 600, liste videe", okBuy == true and bought ~= nil and bought.Price == 600
    and #offersOf() == 0 and s.profiles[player].Money == 400)
check("Stop retourne true", s.service:Stop() == true)

local e = makeScenario()
e.positions[e.thief] = e.pedestal(player, 1)
e.service:AttemptSteal(e.thief, player, "p1")
e.positions[e.thief] = e.pedestal(e.thief, 1)
e.service:BeginSecure(e.thief, 1)
e.clock += 5
e.service:CompleteSecure(e.thief)
e.clock += 600
check("Q10 : rachat expire avant le tick : NO_TELEPORT", select(2, e.service:Remote("TeleportToBase", player, 303)) == "NO_TELEPORT"
    and #e.teleports == 0)
e.service:Stop()

local c = makeScenario()
c.positions[player] = c.pedestal(c.other, 1)
check("Preparation : le joueur vole o1", c.service:Remote("AttemptSteal", player, 404, "o1") == true)
c.positions[c.thief] = c.pedestal(player, 1)
c.clock += 1
c.service:AttemptSteal(c.thief, player, "p1")
check("Joueur en portage : Y ALLER refuse ALREADY_CARRYING", select(2, c.service:Remote("TeleportToBase", player, player.UserId)) == "ALREADY_CARRYING"
    and #c.teleports == 0)
check("Stop : aucun residu sur le joueur reel (IDLE, alerte a 0, aucun rachat)", c.service:Stop() == true
    and player:GetAttribute("StealState") == StealService.ThiefState.IDLE
    and player:GetAttribute("CarryEndsAt") == 0 and player:GetAttribute("CarryHits") == 0
    and player:GetAttribute("StealAlertThiefUserId") == 0 and player:GetAttribute("StealAlertEndsAt") == 0
    and player:GetAttribute("StealAlertCreatureId") == "" and #offersOf() == 0)

-- §18.4 sur les deux remotes hors G4.
local a = makeScenario()
local function codeOf(name, ...) return select(2, a.service:Remote(name, player, ...)) end
check("Abus - TeleportToBase absurde (nil, texte, table, NaN) : NO_PROFILE", codeOf("TeleportToBase", nil) == "NO_PROFILE"
    and codeOf("TeleportToBase", "303") == "NO_PROFILE" and codeOf("TeleportToBase", {}) == "NO_PROFILE"
    and codeOf("TeleportToBase", 0 / 0) == "NO_PROFILE")
check("Abus - BuybackCreature absurde (nil, table, 100 000 caracteres) : BUYBACK_GONE", codeOf("BuybackCreature", nil) == "BUYBACK_GONE"
    and codeOf("BuybackCreature", {}) == "BUYBACK_GONE" and codeOf("BuybackCreature", string.rep("x", 100000)) == "BUYBACK_GONE")
a.guardClock += RemoteConfig.WindowSeconds
local limited, handled = 0, 0
for _ = 1, 30 do
    if codeOf("TeleportToBase", player.UserId) == "RATE_LIMIT" then limited += 1 else handled += 1 end
end
check(("Abus - 30 teleportations en 1 s : %d traitees, %d RATE_LIMIT"):format(handled, limited),
    handled == RemoteConfig.MaxRequestsPerWindow and limited == 30 - RemoteConfig.MaxRequestsPerWindow)
check("Abus - aucune teleportation ni argent consommes", #a.teleports == 0 and a.profiles[player].Money == 1000)
check("Stop retourne true", a.service:Stop() == true)

table.insert(T.lines, ("[STEAL VIEWS TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
