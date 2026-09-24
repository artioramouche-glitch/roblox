--!nonstrict
--[[ TestDefenseService
     Rôle    : prouver les défenses de la base : tourelle (portée, cadence, précision, coup A4, visée), piège (colle
               une fois par plaque et par portage, gouttes, retour à la vitesse du portage), alarme (niveau lu au
               début du portage, publié sur le voleur, surlignage, silence à la fin), bandeau de la victime, dessin
               sur le plot, redessin et journal à l'achat.
     Doc     : GAME_MASTER_V2 A4, A5 ; PROMPT_EXECUTION_SABL_V4 §25.2, §31.9 lot F ; décisions 42 et 43
     Étape   : 9, lot F2 ; alarme, visée, gouttes, bandeau de la victime et journal des achats au lot F3
     Dépend  : Play serveur avec un joueur connecté ; Config.StealConfig, Config.UpgradeConfig, Shared.TableUtil,
               Migrations, RemoteGuard, ShieldService.BaseState, Services.StealService / DefenseService /
               UpgradeService, Base.DefenseVisual, ServerStorage.PropModels.PROP_turret ; lancé par
               ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; joueurs, profils, plots, positions, horloge et tirage factices : aucun profil réel touché.
               L'achat passe par RemoteGuard, qui n'admet qu'un vrai joueur : le joueur connecté n'y sert que de
               clé à un profil factice, et le journal de ces achats est capté ici
     Limite  : le tir et l'alarme sur un vrai voleur se prouveront pendant la poursuite à 2 joueurs (étape 5, lot E) ;
               ce que voient les clients, dans studio/TestDefenseClient.luau.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local UpgradeConfig = require(ReplicatedStorage.Config.UpgradeConfig)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local Migrations = require(Server.Data.Migrations)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local ShieldService = require(Server.Services.ShieldService)
local StealService = require(Server.Services.StealService)
local DefenseService = require(Server.Services.DefenseService)
local UpgradeService = require(Server.Services.UpgradeService)
local DefenseVisual = require(Server.Base.DefenseVisual)
local B = ShieldService.BaseState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 1e-9 end

-- ── A5 et décisions 42-43 : les chiffres ─────────────────────────────────
local D = StealConfig.Defense
check("A5 : tourelle 30 studs, 1 tir/s ; colle -50 % pendant 5 s ; alarme : message, surlignage, fleche aux niveaux 1, 2, 3",
    D.TurretRangeStuds == 30 and D.TurretShotSeconds == 1 and D.TrapSlowFactor == 0.5 and D.TrapSlowSeconds == 5
    and D.AlarmMessageLevel == 1 and D.AlarmHighlightLevel == 2 and D.AlarmArrowLevel == 3)
local chances = {}
for level = 0, 6 do table.insert(chances, math.round(StealConfig.TurretHitChance(level) * 100)) end
check(("Decision 42 : precision %s %% aux niveaux 0 a 6 (plafond au niveau 5)"):format(table.concat(chances, "/")),
    table.concat(chances, "/") == "0/15/30/45/60/75/75" and StealConfig.TurretHitChance("3") == 0
    and StealConfig.TurretHitChance(0 / 0) == 0)
local turret, trap, alarm = UpgradeConfig.Get("Turret"), UpgradeConfig.Get("Trap"), UpgradeConfig.Get("Alarm")
check("A5 : Tourelle (100K -> 100M), Piege (30K / 3M / 300M) et Alarme (25K / 2M / 200M) achetables",
    turret.Available and trap.Available and alarm.Available and turret.Prices[1] == 100000
    and turret.Prices[5] == 100000000 and trap.Prices[1] == 30000 and trap.Prices[3] == 300000000
    and alarm.Prices[1] == 25000 and alarm.Prices[3] == 200000000)

-- ── Géométrie sur un plot factice (surface à y = 2) ──────────────────────
local function makePlot(x)
    local plot = Instance.new("Part")
    plot.Anchored, plot.Size, plot.Position = true, Vector3.new(80, 1, 80), Vector3.new(x, 1.5, 0)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Pedestals", plot
    local pedestal = Instance.new("Part")
    pedestal.Name, pedestal.Anchored = "Pedestal1", true
    pedestal.Position, pedestal.Parent = plot.Position + Vector3.new(4, 1, 0), folder
    return plot
end
local plot = makePlot(0)
local muzzle = DefenseVisual.TurretMuzzle(plot)
check(("Bouche du canon a (%.0f, %.1f, %.0f), a gauche de l'entree"):format(muzzle.X, muzzle.Y, muzzle.Z),
    near(muzzle.X, -12) and near(muzzle.Y, 6.5) and near(muzzle.Z, -34))
local ON_PLATE = {Vector3.new(0, 5, -35), Vector3.new(-36, 5, -9), Vector3.new(36, 5, -9)}
local found = {}
for index, position in ipairs(ON_PLATE) do found[index] = DefenseVisual.PlateAt(plot, 3, position) or 0 end
check(("Plaques 1 (entree), 2 et 3 (cotes) reconnues au niveau 3 : %s"):format(table.concat(found, "/")),
    table.concat(found, "/") == "1/2/3")
check("Plaque 3 absente au niveau 2 ; hors plaque, trop haut (13 studs) ou sans piege : aucune",
    DefenseVisual.PlateAt(plot, 2, ON_PLATE[3]) == nil and DefenseVisual.PlateAt(plot, 3, Vector3.new(0, 5, 0)) == nil
    and DefenseVisual.PlateAt(plot, 3, Vector3.new(0, 15, -35)) == nil and DefenseVisual.PlateAt(plot, 0, ON_PLATE[1]) == nil)

local drawn = DefenseVisual.Render(plot, {Turret = 1, Trap = 2})
local folder = plot:FindFirstChild("Defenses")
local model = folder and folder:FindFirstChild("PROP_turret")
check(("Rendu : tourelle %s, %d plaque(s) de colle, sans collision"):format(model and "du kit" or "absente", drawn.Plates),
    drawn.Turret and drawn.Plates == 2 and model ~= nil and folder:FindFirstChild("Colle1") ~= nil
    and folder:FindFirstChild("Colle2") ~= nil and folder:FindFirstChild("Colle3") == nil
    and folder.Colle1.CanCollide == false)
-- Suggestion du lot F2 : la tête suit sa cible ; ici une cible 20 studs à droite de la colonne.
local yaw = DefenseVisual.Aim(plot, Vector3.new(8, 5, -34))
local aimed = model and model.Canon.Position
local back = DefenseVisual.Aim(plot, nil)
local rest = model and model.Canon.Position
check(("Visee : cible a droite, tete tournee de %d deg, canon en (%.1f ; %.1f) ; sans cible, retour face a l'entree")
    :format(math.round(math.deg(yaw or 0)), aimed and aimed.X or 0, aimed and aimed.Z or 0),
    yaw ~= nil and math.abs(yaw + math.pi / 2) < 1e-6 and aimed ~= nil and math.abs(aimed.X + 9.9) < 0.01
    and math.abs(aimed.Z + 34) < 0.01 and back == 0 and rest ~= nil and math.abs(rest.X + 12) < 0.01
    and math.abs(rest.Z + 36.1) < 0.01)
local empty = DefenseVisual.Render(plot, {Turret = 0, Trap = 0})
check("Sans tourelle ni piege : aucun dossier Defenses, rien a viser", not empty.Turret and empty.Plates == 0
    and plot:FindFirstChild("Defenses") == nil and DefenseVisual.Aim(plot, Vector3.new(8, 5, -34)) == nil)

-- Gouttes de colle et surlignage de l'alarme (lot F3) sur un personnage factice.
local dummy = Instance.new("Model")
dummy.Name = "VoleurFactice"
local dummyRoot = Instance.new("Part")
dummyRoot.Name, dummyRoot.Anchored, dummyRoot.Size = "HumanoidRootPart", true, Vector3.new(2, 2, 1)
dummyRoot.Position, dummyRoot.Parent = Vector3.new(0, 60, 0), dummy
dummy.Parent = workspace
local glued = DefenseVisual.Glue(dummy, 0.3)
local drops, welded = 0, 0
for _, drop in ipairs(glued and glued:GetChildren() or {}) do
    drops += 1
    local weld = drop:FindFirstChildOfClass("WeldConstraint")
    if weld and weld.Part0 == dummyRoot and weld.Part1 == drop and not drop.Anchored and drop.Massless
        and not drop.CanCollide and (drop.Position - dummyRoot.Position).Magnitude < 4 then
        welded += 1
    end
end
local marked = DefenseVisual.MarkThief(dummy, true)
local markedAgain = DefenseVisual.MarkThief(dummy, true)
local throughWalls = marked ~= nil and marked.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop
local highlights = 0
for _, child in ipairs(dummy:GetChildren()) do
    if child:IsA("Highlight") then highlights += 1 end
end
DefenseVisual.MarkThief(dummy, false)
task.wait(0.5)
check(("Gouttes : %d / %d soudees au voleur, sans poids ni collision, parties a la fin du ralenti ; sans personnage, rien")
    :format(welded, drops),
    drops == 5 and welded == 5 and dummy:FindFirstChild(DefenseVisual.GlueFolder) == nil
    and DefenseVisual.Glue(nil, 5) == nil)
check("Alarme niv. 2 : un seul surlignage, visible a travers les murs, retire a la fin ; sans personnage, rien",
    throughWalls and markedAgain == marked and highlights == 1
    and dummy:FindFirstChild(DefenseVisual.HighlightName) == nil and DefenseVisual.MarkThief(nil, true) == nil)
dummy:Destroy()

-- ── Monde de vol factice (même montage que TestStealService) ─────────────
local function makeWorld(turretLevel, trapLevel, alarmLevel)
    local w = {clock = 10000, present = {}, positions = {}, speeds = {}, profiles = {}, plots = {}, byId = {},
        players = {}, shots = {}, aims = {}, glued = {}, marks = {}, refreshed = 0}
    local data = {}
    function data:Get(p) local s = w.profiles[p] return s and TableUtil.DeepCopy(s) or nil end
    function data:Update(p, callback)
        local current = w.profiles[p]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(callback, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        w.profiles[p] = reconciled
        return true, result
    end
    local shield = {BaseState = B}
    function shield:GetPhase() return B.VULNERABLE end
    local placement = {}
    function placement:PlotOf(p) return w.plots[p] end
    function placement:Refresh() w.refreshed += 1 return true end
    -- Joueurs factices : ils portent des attributs comme un vrai Player, et comptent leurs écritures.
    local function addPlayer(name, id, x, creatures, base)
        local p = {Name = name, UserId = id, Attributes = {}, Sets = {}}
        function p:SetAttribute(key, value)
            self.Attributes[key] = value
            self.Sets[key] = (self.Sets[key] or 0) + 1
        end
        function p:GetAttribute(key) return self.Attributes[key] end
        local profile = Migrations:Create()
        profile.Level, profile.Playtime = 5, 3600
        profile.Creatures = creatures or {}
        for key, value in pairs(base or {}) do profile.Base[key] = value end
        w.profiles[p], w.present[p], w.byId[id] = profile, true, p
        w.plots[p] = makePlot(x)
        table.insert(w.players, p)
        return p
    end
    w.victim = addPlayer("Victime", 101, 0, {{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1}},
        {Turret = turretLevel, Trap = trapLevel, Alarm = alarmLevel or 0})
    w.thief = addPlayer("Voleur", 202, 300)
    w.steal = StealService.new({
        Data = data, Shield = shield, Placement = placement, Clock = function() return w.clock end,
        Remotes = false, World = false,
        IsPresent = function(p) return w.present[p] == true end,
        Characters = {
            GetPosition = function(p) return w.positions[p] end,
            SetSpeedMultiplier = function(p, m) w.speeds[p] = m end,
        },
    })
    w.steal:Init()
    w.roll = 0.10
    w.defense = DefenseService.new({
        Data = data, Steal = w.steal, Placement = placement, Clock = function() return w.clock end,
        Rng = {NextNumber = function() return w.roll end},
        ListPlayers = function() return w.players end,
        ResolvePlayer = function(id) return w.byId[id] end,
        GetPosition = function(p) return w.positions[p] end,
        Visual = {TurretMuzzle = DefenseVisual.TurretMuzzle, PlateAt = DefenseVisual.PlateAt,
            Shot = function(_, _, hit) table.insert(w.shots, hit) end,
            Aim = function(_, position) table.insert(w.aims, position) return 0 end,
            Glue = function(_, seconds) table.insert(w.glued, seconds) end,
            MarkThief = function(_, on) table.insert(w.marks, on) end},
    })
    w.defense:Init()
    -- Le voleur prend le brainrot sur le piédestal 1 de la victime.
    w.positions[w.thief] = w.plots[w.victim].Pedestals.Pedestal1.Position
    w.carrying = w.steal:AttemptSteal(w.thief, w.victim, "v1") == true
    return w
end
local IN_RANGE = Vector3.new(-12, 5, -14) -- 20 studs de la bouche, hors de toute plaque
local OUT_OF_RANGE = Vector3.new(-12, 5, 0) -- 34 studs

-- ── Décision 42 : la tourelle ────────────────────────────────────────────
local w = makeWorld(1, 0)
w.positions[w.thief] = IN_RANGE
w.defense:Step(w.clock)
w.defense:Step(w.clock + 0.5)
local afterFirst = w.steal:GetSession(w.thief).Hits
w.clock += 1
w.defense:Step(w.clock)
check(("Niveau 1, voleur a 20 studs, tirage 0,10 < 0,15 : touche ; un seul tir dans la seconde (%d tir(s), %d coup(s)) ; la tete suit sa cible entre deux tirs (%d visees)")
    :format(#w.shots, w.steal:GetSession(w.thief).Hits, #w.aims),
    w.carrying and afterFirst == 1 and #w.shots == 2 and w.steal:GetSession(w.thief).Hits == 2 and #w.aims == 3
    and w.aims[2] == IN_RANGE)
w.roll = 0.20
w.clock += 1
w.defense:Step(w.clock)
check("Niveau 1, tirage 0,20 : tir manque, aucun coup", #w.shots == 3 and w.shots[3] == false
    and w.steal:GetSession(w.thief).Hits == 2)
local aimsBefore = #w.aims
w.positions[w.thief] = OUT_OF_RANGE
w.clock += 1
w.defense:Step(w.clock)
check("Voleur a 34 studs : hors de portee, ni tir ni visee", #w.shots == 3 and #w.aims == aimsBefore)

w = makeWorld(3, 0)
w.positions[w.thief] = IN_RANGE
for _ = 1, 3 do
    w.clock += 1
    w.defense:Step(w.clock)
end
local victimProfile = w.profiles[w.victim]
check(("A4 : trois tirs au but, le voleur lache (etat %s), defense comptee a la victime (%d), vitesse rendue (%s)")
    :format(w.steal:GetSession(w.thief).State, victimProfile.Stats.Defends, tostring(w.speeds[w.thief])),
    #w.shots == 3 and w.steal:GetSession(w.thief).State == "IDLE" and #w.steal:GetDrops() == 1
    and victimProfile.Stats.Defends == 1 and w.speeds[w.thief] == 1)
local banner = w.victim.Attributes
check(("Bandeau de la victime : sa tourelle a fait lacher %s a %s, publie une fois"):format(
    tostring(banner.DefenseDropCreatureId), tostring(banner.DefenseDropThiefName)),
    banner.DefenseDropCreatureId == "noobini" and banner.DefenseDropThiefName == "Voleur"
    and banner.DefenseDropAt == w.clock and w.victim.Sets.DefenseDropAt == 1)

w = makeWorld(0, 0)
w.positions[w.thief] = IN_RANGE
w.clock += 1
w.defense:Step(w.clock)
check("Sans tourelle : ni tir ni visee", #w.shots == 0 and #w.aims == 0 and w.steal:GetSession(w.thief).Hits == 0)

w = makeWorld(5, 0)
local bystander = {Name = "Voisin", UserId = 303}
local neighbour = Migrations:Create()
neighbour.Base.Turret, neighbour.Base.Alarm = 5, 3
w.profiles[bystander], w.present[bystander], w.byId[303] = neighbour, true, bystander
w.plots[bystander] = makePlot(0) -- meme emplacement : sa tourelle voit le voleur
table.insert(w.players, bystander)
w.plots[w.victim] = makePlot(500) -- la victime est loin : sa tourelle ne le voit pas
w.positions[w.thief] = IN_RANGE
w.clock += 1
w.defense:Step(w.clock)
check("Une base ne defend que son brainrot : ni la tourelle ni l'alarme d'un voisin ne se declenchent",
    #w.shots == 0 and w.thief.Attributes.AlarmLevel == nil)

-- ── Décision 43 : le piège ───────────────────────────────────────────────
w = makeWorld(0, 2)
local carrySpeed = 1 - StealConfig.Thief.CarrySpeedPenalty
check(("Portage seul : vitesse x%.2f"):format(w.speeds[w.thief] or -1), near(w.speeds[w.thief], carrySpeed))
w.positions[w.thief] = ON_PLATE[1]
w.defense:Step(w.clock)
local glued1 = w.speeds[w.thief]
w.clock += 1
w.defense:Step(w.clock)
check(("Plaque 1 : colle, vitesse x%.2f (0,7 x 0,5), gouttes pendant %s s ; une seule fois par portage")
    :format(glued1 or -1, tostring(w.glued[1])),
    near(glued1, carrySpeed * 0.5) and near(w.speeds[w.thief], carrySpeed * 0.5) and #w.glued == 1 and w.glued[1] == 5)
w.clock += 5
w.steal:Step()
check(("Apres 5 s : retour a la vitesse du portage (x%.2f)"):format(w.speeds[w.thief] or -1),
    near(w.speeds[w.thief], carrySpeed))
w.positions[w.thief] = ON_PLATE[1]
w.defense:Step(w.clock)
local again = w.speeds[w.thief]
w.positions[w.thief] = ON_PLATE[2]
w.defense:Step(w.clock)
local second = w.speeds[w.thief]
w.clock += 5
w.steal:Step()
w.positions[w.thief] = ON_PLATE[3]
w.defense:Step(w.clock)
check("Retour sur la plaque 1 : rien ; plaque 2 : colle et gouttes ; plaque 3 absente au niveau 2 : rien",
    near(again, carrySpeed) and near(second, carrySpeed * 0.5) and near(w.speeds[w.thief], carrySpeed)
    and #w.glued == 2)
check("Ralenti et coup refuses hors portage : NOT_CARRYING",
    select(2, w.steal:SlowThief(w.victim, 0.5, 5)) == "NOT_CARRYING"
    and select(2, w.steal:ApplyDefenseHit(w.victim, "TURRET")) == "NOT_CARRYING")

-- ── Décision 43 : l'alarme ───────────────────────────────────────────────
w = makeWorld(0, 0, 0)
w.defense:Step(w.clock)
check("Sans alarme : rien de publie sur le voleur, aucun surlignage", next(w.thief.Attributes) == nil and #w.marks == 0)

w = makeWorld(0, 0, 1)
w.defense:Step(w.clock)
w.profiles[w.victim].Base.Alarm = 3 -- achat pendant le portage : l'alarme garde son niveau de départ
w.defense:Step(w.clock + 0.1)
local rung = w.thief.Attributes
check(("Alarme niv. 1 : le voleur porte l'alarme de la victime %s (niveau %s, %s), publiee une fois, sans surlignage")
    :format(tostring(rung.AlarmVictimUserId), tostring(rung.AlarmLevel), tostring(rung.AlarmCreatureId)),
    rung.AlarmLevel == 1 and rung.AlarmVictimUserId == 101 and rung.AlarmCreatureId == "noobini"
    and w.thief.Sets.AlarmLevel == 1 and #w.marks == 0)

w = makeWorld(0, 0, 2)
w.defense:Step(w.clock)
local highlighted = w.marks[#w.marks] == true
w.clock += StealConfig.Thief.CarryTimeoutSeconds + 1
w.steal:Step() -- A4 : 60 s sans poser, le voleur lâche
w.defense:Step(w.clock)
local silent = w.thief.Attributes
check(("Alarme niv. 2 : voleur surligne ; fin du portage (%s) : alarme tue (niveau %s), surlignage retire")
    :format(w.steal:GetSession(w.thief).State, tostring(silent.AlarmLevel)),
    highlighted and w.steal:GetSession(w.thief).State == "IDLE" and silent.AlarmLevel == 0
    and silent.AlarmVictimUserId == 0 and silent.AlarmCreatureId == "" and w.marks[#w.marks] == false)

w = makeWorld(0, 0, 3)
w.defense:Step(w.clock)
local ringing = w.thief.Attributes.AlarmLevel
w.defense:Stop()
check(("Alarme niv. 3 : niveau %s publie pour la fleche, voleur surligne ; arret du service : alarme tue")
    :format(tostring(ringing)),
    ringing == 3 and w.marks[1] == true and w.thief.Attributes.AlarmLevel == 0 and w.marks[#w.marks] == false)

-- ── A5 : l'achat redessine le plot ───────────────────────────────────────
local buyer = assert(Players:GetPlayers()[1], "Joueur de test requis")
local profiles = {[buyer] = Migrations:Create()}
profiles[buyer].Money = 100000 + 30000 + 5000 + 25000
local fake = {}
function fake:Get(t) local s = profiles[t] return s and TableUtil.DeepCopy(s) or nil end
function fake:Update(t, cb)
    local candidate = TableUtil.DeepCopy(profiles[t])
    local ok, accepted, result = pcall(cb, candidate)
    if not ok or not accepted then return false, result end
    profiles[t] = assert(Migrations:Apply(candidate))
    return true, result
end
fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return 0 end})
local refreshes = 0
local logged = {}
local upgrades = UpgradeService.new({Data = fake, Placement = {Refresh = function() refreshes += 1 return true end},
    Remote = Instance.new("RemoteFunction"), Log = function(line) table.insert(logged, line) end})
upgrades:Init()
local bought = {}
for _, key in ipairs({"Turret", "Trap", "Slots", "Alarm"}) do
    local ok, result = upgrades:Buy(buyer, key)
    table.insert(bought, if ok == true then "ok" else tostring(result))
end
check(("Achat : tourelle et piege redessinent le plot (%d), ni un piedestal ni l'alarme (achats %s) ; %d lignes de journal captees")
    :format(refreshes, table.concat(bought, "/"), #logged),
    table.concat(bought, "/") == "ok/ok/ok/ok" and refreshes == 2
    and profiles[buyer].Base.Turret == 1 and profiles[buyer].Base.Trap == 1 and profiles[buyer].Base.Alarm == 1
    and profiles[buyer].Money == 0 and #logged == 4 and (logged[4] or ""):find("key=Alarm level=1 price=25000", 1, true) ~= nil)

table.insert(T.lines, ("[DEFENSE TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
