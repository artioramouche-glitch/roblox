--!nonstrict
--[[ TestStealRemotes
     Rôle    : batterie du lot C1 : rendu des invites et des brainrots (StealWorld), remotes G4, abus §18.4.
     Doc     : GAME_MASTER_V2 A4, G3, G4 ; PROMPT_EXECUTION_SABL_V4 Loi 7, §16.5, §18.2, §18.4, §25.2
     Étape   : 5, lot C1 ; contrôles du rendu 3D mis à jour à l'étape 6, lot B2
     Dépend  : Play serveur avec un joueur connecté ; Migrations, TableUtil, RemoteGuard, RemoteConfig,
               ShieldService.BaseState, StealService, Steal.StealWorld
     Exposé  : bilan ; plots, piédestaux, profils, joueurs factices et horloges simulées ; le joueur réel
               appelle les remotes et joue le voleur du scénario (RemoteGuard exige un vrai Player),
               sur un profil factice
     Limite  : remotes créés dans un dossier factice, jamais dans ReplicatedStorage.Remotes ; aucun profil
               réel lu ou écrit. Les attributs de vol du joueur réel sont écrasés pendant la batterie puis
               remis au neutre par Stop : à lancer hors vol réel en cours. Journaux [LOG][STEAL] et
               avertissement [GUARD] RATE_LIMIT attendus.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local RemoteConfig = require(ReplicatedStorage.Config.RemoteConfig)
local ShieldService = require(Server.Services.ShieldService)
local StealService = require(Server.Services.StealService)
local StealWorld = require(Server.Steal.StealWorld)
local B = ShieldService.BaseState
local S = StealService.ThiefState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Partie 1 : StealWorld rend l'instantané qu'on lui donne, sans aucune règle.
local function makePedestal(name, parent)
    local pedestal = Instance.new("Part")
    pedestal.Name, pedestal.Anchored = name, true
    local holder = Instance.new("Folder")
    holder.Name = "Placed"
    local cube = Instance.new("Part")
    cube.Name, cube.Parent = "CRT_noobini", holder
    holder.Parent, pedestal.Parent = pedestal, parent
    return pedestal, cube
end

local effects = Instance.new("Folder")
local pedestals = Instance.new("Folder")
local p1, placed1 = makePedestal("Pedestal1", pedestals)
local p2 = makePedestal("Pedestal2", pedestals)
local began, triggered = {}, {}
local world = StealWorld.new({
    Effects = effects,
    OnSecureBegan = function(who, slot) table.insert(began, {who = who, slot = slot}) end,
    OnSecureTriggered = function(who) table.insert(triggered, who) end,
})

world:Sync({stealPrompts = {[p1] = {targetUserId = 101, uid = "v1", creatureId = "noobini"}}})
local steal = p1:FindFirstChild("StealPrompt")
check("Invite Voler sur le piedestal occupe", steal ~= nil and steal:IsA("ProximityPrompt") and steal.ActionText == "Voler")
check("Loi 7 : touche E, sans maintien, 12 studs, sans ligne de vue", steal ~= nil
    and steal.KeyboardKeyCode == Enum.KeyCode.E and steal.HoldDuration == 0
    and steal.MaxActivationDistance == 12 and steal.RequiresLineOfSight == false)
check("Invite Voler : cible 101, Uid v1, nom de la creature", steal ~= nil and steal:GetAttribute("TargetUserId") == 101
    and steal:GetAttribute("Uid") == "v1" and steal.ObjectText == "Noobini Pizzanini")
world:Sync({})
check("Instantane vide : invite Voler retiree", p1:FindFirstChild("StealPrompt") == nil)

world:Sync({hiddenPedestals = {[p1] = true}})
check("Brainrot porte : cube de la victime masque", placed1.Transparency == 1)
world:Sync({})
check("Brainrot revenu : cube de la victime visible", placed1.Transparency == 0)

local character = Instance.new("Model")
local root = Instance.new("Part")
root.Name, root.Anchored, root.Parent = "HumanoidRootPart", true, character
character.Parent = effects
local thief = {Name = "Voleur", UserId = 202, Character = character}
local carrying = {carries = {[thief] = {creatureId = "noobini", securePedestals = {[p2] = 2}}}}
world:Sync(carrying)
local carried = character:FindFirstChild("CRT_noobini")
local carriedBase = carried and carried.PrimaryPart
local weld = carriedBase and carriedBase:FindFirstChildOfClass("WeldConstraint")
check("Etape 6 : le brainrot porte est un Model soude au voleur par sa racine",
    carried ~= nil and carried:IsA("Model") and carried:GetAttribute("Carried") == true
    and weld ~= nil and weld.Part0 == root and weld.Part1 == carriedBase)
check("Brainrot porte : aucune piece ancree, rien ne pese sur le voleur", carried ~= nil
    and carriedBase ~= nil and not carriedBase.Anchored and carriedBase.Massless == true)
local hit = carried and carried:FindFirstChild("HitPrompt", true)
check("Invite Frapper sur le voleur : 12 studs, ThiefUserId 202", hit ~= nil and hit.ActionText == "Frapper"
    and hit.MaxActivationDistance == 12 and hit:GetAttribute("ThiefUserId") == 202)
local secure = p2:FindFirstChild("SecurePrompt")
check("Invite Poser : maintien 5 s, piedestal libre du voleur", secure ~= nil and secure.ActionText == "Poser"
    and secure.HoldDuration == 5 and secure:GetAttribute("OwnerUserId") == 202 and secure:GetAttribute("Slot") == 2)
if secure then
    world:_SecureBegan({UserId = 999}, secure)
    world:_SecureTriggered({UserId = 999}, secure)
end
check("Pose declenchee par un autre joueur : ignoree", #began == 0 and #triggered == 0)
if secure then
    world:_SecureBegan(thief, secure)
    world:_SecureTriggered(thief, secure)
end
check("Pose du voleur : debut (slot 2) puis fin transmis a StealService", #began == 1 and began[1].slot == 2
    and began[1].who == thief and #triggered == 1)

root.Name = "AncienneRacine"
local newRoot = Instance.new("Part")
newRoot.Name, newRoot.Anchored, newRoot.Parent = "HumanoidRootPart", true, character
world:Sync(carrying)
local respawned = character:FindFirstChild("CRT_noobini")
local newWeld = respawned and respawned.PrimaryPart and respawned.PrimaryPart:FindFirstChildOfClass("WeldConstraint")
check("Reapparition : brainrot recree et soude a la nouvelle racine", respawned ~= nil and respawned ~= carried
    and newWeld ~= nil and newWeld.Part0 == newRoot and (carried == nil or carried.Parent == nil))
world:Sync({})
check("Fin du portage : brainrot porte et invite Poser retires", character:FindFirstChild("CRT_noobini") == nil
    and p2:FindFirstChild("SecurePrompt") == nil)

world:Sync({drops = {drop_7 = {creatureId = "noobini", position = Vector3.new(10, 5, 10)}}})
local dropFolder = effects:FindFirstChild("Drop_7")
local dropModel = dropFolder and dropFolder:FindFirstChild("CRT_noobini")
local claim = dropModel and dropModel:FindFirstChild("ClaimPrompt", true)
check("Brainrot au sol : Model ancre, pose pres du sol", dropModel ~= nil and dropModel:IsA("Model")
    and dropModel.PrimaryPart ~= nil and dropModel.PrimaryPart.Anchored
    and (dropModel:GetPivot().Position - Vector3.new(10, 3, 10)).Magnitude < 0.01)
check("Invite Ramasser : DropId drop_7, 12 studs", claim ~= nil and claim.ActionText == "Ramasser"
    and claim:GetAttribute("DropId") == "drop_7" and claim.MaxActivationDistance == 12)
world:Sync({})
check("Lacher termine : cube au sol retire", effects:FindFirstChild("Drop_7") == nil)
world:Sync({stealPrompts = {[p1] = {targetUserId = 101, uid = "v1", creatureId = "noobini"}}, hiddenPedestals = {[p1] = true}})
world:Destroy()
check("Destroy : invite retiree et cube restaure", p1:FindFirstChild("StealPrompt") == nil and placed1.Transparency == 0)

-- Partie 2 : remotes G4 par StealService, RemoteGuard réel, profils et victime factices.
local function makeScenario()
    local s = {clock = 10000, guardClock = 0, profiles = {}, positions = {}, present = {}, plots = {}}
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
    local recorder = {}
    function recorder:Sync(snapshot) s.snapshot = snapshot end
    function recorder:Destroy() s.destroyed = true end
    s.victim = {Name = "Victime", UserId = 101}
    s.carrier = {Name = "Porteur", UserId = 303}
    local byId = {[101] = s.victim, [303] = s.carrier, [player.UserId] = player}
    local function addProfile(p, x, creatures)
        local profile = Migrations:Create()
        profile.Level, profile.Playtime = 5, 3600
        profile.Creatures = creatures or {}
        s.profiles[p], s.present[p] = profile, true
        local plot = Instance.new("Part")
        plot.Position = Vector3.new(x, 1.5, 0)
        local folder = Instance.new("Folder")
        folder.Name, folder.Parent = "Pedestals", plot
        for slot = 1, 3 do
            local pedestal = Instance.new("Part")
            pedestal.Name = "Pedestal" .. slot
            pedestal.Position, pedestal.Parent = plot.Position + Vector3.new(slot * 4, 1, 0), folder
        end
        s.plots[p] = plot
    end
    addProfile(player, 300)
    addProfile(s.victim, 0, {{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1},
        {Uid = "v2", Id = "talpa", Tier = 1, PlacedSlot = 2}})
    addProfile(s.carrier, 600)
    s.pedestal = function(p, slot) return s.plots[p].Pedestals["Pedestal" .. slot] end
    s.remoteFolder = Instance.new("Folder")
    s.service = StealService.new({
        Data = data, Shield = shield, Placement = placement, Clock = function() return s.clock end,
        IsPresent = function(p) return p == player or s.present[p] == true end,
        Characters = {GetPosition = function(p) return s.positions[p] end, SetSpeedMultiplier = function() end},
        ListPlayers = function() return {player, s.victim, s.carrier} end,
        ResolvePlayer = function(id) return byId[id] end,
        RemoteFolder = s.remoteFolder, World = recorder,
    })
    s.service:Init()
    s.service:Start()
    return s
end

local s = makeScenario()
local names = {}
for _, child in ipairs(s.remoteFolder:GetChildren()) do
    if child:IsA("RemoteFunction") then names[child.Name] = true end
end
check("G4 : remotes AttemptSteal, HitThief et ClaimDropped crees (RemoteFunction), 5 avec l'extension D1", names.AttemptSteal == true
    and names.HitThief == true and names.ClaimDropped == true and #s.remoteFolder:GetChildren() == 5)
check("Remote inconnu : INTERNAL", select(2, s.service:Remote("GiveMoney", player)) == "INTERNAL")

s.positions[player] = s.pedestal(s.victim, 1).Position
local okSteal, stolen = s.service:Remote("AttemptSteal", player, 101, "v1")
check("Remote AttemptSteal valide : portage du joueur", okSteal == true and stolen ~= nil and stolen.Uid == "v1"
    and s.service:GetSession(player).State == S.CARRYING)
local snap = s.snapshot or {}
check("Instantane apres le vol : cube de la victime masque", snap.hiddenPedestals ~= nil
    and snap.hiddenPedestals[s.pedestal(s.victim, 1)] == true)
check("Instantane : Voler reste sur v2 et disparait de v1", snap.stealPrompts ~= nil
    and snap.stealPrompts[s.pedestal(s.victim, 2)] ~= nil and snap.stealPrompts[s.pedestal(s.victim, 1)] == nil)
local carry = snap.carries and snap.carries[player]
check("Instantane : portage du joueur et ses piedestaux libres pour poser", carry ~= nil
    and carry.creatureId == "noobini" and carry.securePedestals[s.pedestal(player, 1)] == 1
    and carry.securePedestals[s.pedestal(player, 3)] == 3)

s.clock = 10031
s.positions[s.carrier] = s.pedestal(s.victim, 2).Position
check("Preparation : un joueur factice porte v2", s.service:AttemptSteal(s.carrier, s.victim, "v2") == true)
s.positions[player] = s.positions[s.carrier] + Vector3.new(5, 0, 0)
local okHit, hitResult = s.service:Remote("HitThief", player, 303)
check("Remote HitThief valide : coup 1 sur le porteur", okHit == true and hitResult ~= nil and hitResult.Hits == 1)
s.clock += 1
s.service:Remote("HitThief", player, 303)
s.clock += 1
local _, dropped = s.service:Remote("HitThief", player, 303)
check("3 coups par le remote : le porteur lache v2", dropped ~= nil and dropped.Dropped == true)
snap = s.snapshot or {}
check("Instantane : lacher present, portage du porteur retire", dropped ~= nil and snap.drops ~= nil
    and snap.drops[dropped.DropId] ~= nil and snap.carries ~= nil and snap.carries[s.carrier] == nil)
s.positions[player] = s.positions[s.carrier]
check("Remote ClaimDropped avant 10 s par un non-proprietaire : NOT_OWNER", dropped ~= nil
    and select(2, s.service:Remote("ClaimDropped", player, dropped.DropId)) == "NOT_OWNER")
check("Stop : remotes coupes et invites detruites", s.service:Stop() == true and s.destroyed == true)
check("Stop : aucun residu sur le joueur reel (IDLE, portage a 0)", player:GetAttribute("StealState") == S.IDLE
    and player:GetAttribute("CarryEndsAt") == 0 and player:GetAttribute("CarryHits") == 0)

-- §18.4 : les abus doivent être refusés sans jamais modifier un profil.
local a = makeScenario()
a.positions[player] = a.pedestal(a.victim, 1).Position
local function codeOf(name, ...) return select(2, a.service:Remote(name, player, ...)) end
check("Abus 1 - Uid non possede : NOT_OWNER", codeOf("AttemptSteal", 101, "zz") == "NOT_OWNER")
local targets = codeOf("AttemptSteal", nil, "v1") == "NO_PROFILE" and codeOf("AttemptSteal", "101", "v1") == "NO_PROFILE"
    and codeOf("AttemptSteal", -1, "v1") == "NO_PROFILE" and codeOf("AttemptSteal", 1.5, "v1") == "NO_PROFILE"
    and codeOf("AttemptSteal", 0 / 0, "v1") == "NO_PROFILE" and codeOf("AttemptSteal", {}, "v1") == "NO_PROFILE"
check("Abus 2 - cibles absurdes (nil, texte, -1, 1.5, NaN, table) : NO_PROFILE", targets)
local uids = codeOf("AttemptSteal", 101, nil) == "NOT_OWNER" and codeOf("AttemptSteal", 101, {}) == "NOT_OWNER"
    and codeOf("AttemptSteal", 101, string.rep("x", 100000)) == "NOT_OWNER"
check("Abus 2 - Uid absurdes (nil, table, 100 000 caracteres) : NOT_OWNER", uids)
a.guardClock += RemoteConfig.WindowSeconds
check("Abus 2 - HitThief absurde (nil, texte, table) : NO_PROFILE ; cible qui ne porte rien : NOT_CARRYING",
    codeOf("HitThief", nil) == "NO_PROFILE" and codeOf("HitThief", "303") == "NO_PROFILE"
    and codeOf("HitThief", {}) == "NO_PROFILE" and codeOf("HitThief", 303) == "NOT_CARRYING")
check("Abus 2 - ClaimDropped absurde (nil, table, 100 000 caracteres, inconnu) : DROP_GONE",
    codeOf("ClaimDropped", nil) == "DROP_GONE" and codeOf("ClaimDropped", {}) == "DROP_GONE"
    and codeOf("ClaimDropped", string.rep("x", 100000)) == "DROP_GONE" and codeOf("ClaimDropped", "drop_999") == "DROP_GONE")
a.guardClock += RemoteConfig.WindowSeconds
local limited, handled = 0, 0
for _ = 1, 30 do
    if codeOf("AttemptSteal", 101, "zz") == "RATE_LIMIT" then limited += 1 else handled += 1 end
end
check(("Abus 3 - 30 appels en 1 s : %d traites, %d RATE_LIMIT"):format(handled, limited),
    handled == RemoteConfig.MaxRequestsPerWindow and limited == 30 - RemoteConfig.MaxRequestsPerWindow)
a.guardClock += RemoteConfig.WindowSeconds
check("Fenetre suivante : le remote repond de nouveau", codeOf("AttemptSteal", 101, "zz") == "NOT_OWNER")
check("Abus 4 - aucun refus n'a modifie les profils ni l'etat", a.profiles[player].LastStealAttempt == 0
    and #a.profiles[a.victim].Creatures == 2 and a.service:GetSession(player).State == S.IDLE)
check("Stop retourne true", a.service:Stop() == true)

table.insert(T.lines, ("[STEAL REMOTES TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
