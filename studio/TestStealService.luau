--!nonstrict
--[[ TestStealService
     Rôle    : batterie VOL (§25.2) de la logique serveur, sans remote ni personnage réel.
     Doc     : GAME_MASTER_V2 A4, G4, G5.7 ; PROMPT_EXECUTION_SABL_V4 §16.6, §18.2, §25.2 ; Q3-Q5 option A
     Étape   : 5, lot B2
     Dépend  : Play serveur ; Migrations, TableUtil, StealConfig, ShieldService.BaseState
     Exposé  : bilan ; joueurs, profils, plots, positions, bouclier et horloge factices
     Limite  : aucun profil réel lu ou écrit. Les journaux [LOG][STEAL] des joueurs factices
               apparaissent dans la console pendant la batterie.
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local ShieldService = require(Server.Services.ShieldService)
local StealService = require(Server.Services.StealService)
local S = StealService.ThiefState
local B = ShieldService.BaseState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- A4, G4 et Q3-Q5 recopiés : les attendus ne sont jamais déduits de la configuration testée.
local P, TH, D = StealConfig.Protection, StealConfig.Thief, StealConfig.Drop
check("A4 : protection niveau 5 ET 3600 s", P.MinLevel == 5 and P.MinPlaytimeSeconds == 3600)
check("A4 : portage -30 %, 60 s, 3 coups, pose 5 s", TH.CarrySpeedPenalty == 0.30 and TH.CarryTimeoutSeconds == 60
    and TH.HitsToDrop == 3 and TH.SecureHoldSeconds == 5)
check("A4 : cooldowns 60 s voleur, 30 s cible, Secret x3", TH.ThiefCooldownSeconds == 60
    and TH.TargetCooldownSeconds == 30 and TH.SecretCooldownMultiplier == 3)
check("G4 et Q4 : coups a moins de 12 studs, 1 par seconde", TH.HitRangeStuds == 12 and TH.HitCooldownSeconds == 1)
check("G4 et Q5 : priorite 10 s, retour a 60 s, portee 12 studs", D.OwnerPrioritySeconds == 10
    and D.GroundSeconds == 60 and TH.InteractRangeStuds == 12)

local function makeWorld()
    local w = {clock = 10000, present = {}, positions = {}, speeds = {}, phases = {}, profiles = {},
        plots = {}, refreshed = {}, busy = {}}
    local data = {}
    function data:Get(p) local s = w.profiles[p] return s and TableUtil.DeepCopy(s) or nil end
    function data:Update(p, callback)
        if (w.busy[p] or 0) > 0 then w.busy[p] -= 1 return false, "BUSY" end
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
    function shield:GetPhase(p) return w.phases[p] or B.VULNERABLE end
    local placement = {}
    function placement:PlotOf(p) return w.plots[p] end
    function placement:Refresh(p) w.refreshed[p] = (w.refreshed[p] or 0) + 1 return true end
    w.service = StealService.new({
        Data = data, Shield = shield, Placement = placement, Clock = function() return w.clock end,
        Remotes = false, World = false,
        IsPresent = function(p) return w.present[p] == true end,
        Characters = {
            GetPosition = function(p) return w.positions[p] end,
            SetSpeedMultiplier = function(p, m) w.speeds[p] = m end,
        },
    })
    w.service:Init()
    return w
end

local function addPlayer(w, name, id, x, creatures, overrides)
    local p = {Name = name, UserId = id}
    local profile = Migrations:Create()
    profile.Level, profile.Playtime = 5, 3600
    profile.Creatures = creatures or {}
    for key, value in pairs(overrides or {}) do profile[key] = value end
    w.profiles[p], w.present[p] = profile, true
    local plot = Instance.new("Part")
    plot.Anchored, plot.Size, plot.Position = true, Vector3.new(80, 1, 80), Vector3.new(x, 1.5, 0)
    local folder = Instance.new("Folder")
    folder.Name, folder.Parent = "Pedestals", plot
    for slot = 1, 3 do
        local pedestal = Instance.new("Part")
        pedestal.Name, pedestal.Anchored = "Pedestal" .. slot, true
        pedestal.Position, pedestal.Parent = plot.Position + Vector3.new(slot * 4, 1, 0), folder
    end
    w.plots[p] = plot
    return p
end

local function pedestal(w, owner, slot) return w.plots[owner].Pedestals["Pedestal" .. slot].Position end
local function scenario(victimCreatures, thiefCreatures, thiefOverrides, victimOverrides)
    local w = makeWorld()
    local victim = addPlayer(w, "Victime", 101, 0,
        victimCreatures or {{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1}}, victimOverrides)
    local thief = addPlayer(w, "Voleur", 202, 300, thiefCreatures, thiefOverrides)
    w.positions[thief] = pedestal(w, victim, 1)
    return w, victim, thief
end
local function code(ok, result) return ok and "OK" or result end

-- §25.2 : refus attendus.
local w, V, Th = scenario()
w.phases[V] = B.SHIELDED
check("Cible sous bouclier : TARGET_SHIELDED", code(w.service:AttemptSteal(Th, V, "v1")) == "TARGET_SHIELDED")
w.phases[V] = B.ALERT
check("Cible en alerte : TARGET_SHIELDED (vol possible seulement en VULNERABLE)",
    code(w.service:AttemptSteal(Th, V, "v1")) == "TARGET_SHIELDED")
w.phases[V] = nil
w, V, Th = scenario(nil, nil, {Level = 4})
check("Voleur niveau 4 : LEVEL_TOO_LOW", code(w.service:AttemptSteal(Th, V, "v1")) == "LEVEL_TOO_LOW")
w, V, Th = scenario(nil, nil, {Playtime = 3599})
check("Voleur niveau 5 mais 3599 s : LEVEL_TOO_LOW (niveau ET 1 h)",
    code(w.service:AttemptSteal(Th, V, "v1")) == "LEVEL_TOO_LOW")
w, V, Th = scenario(nil, nil, nil, {Playtime = 100})
check("Victime debutante : TARGET_PROTECTED", code(w.service:AttemptSteal(Th, V, "v1")) == "TARGET_PROTECTED")
w, V, Th = scenario({{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1, InPvPTeam = "A"}})
check("Brainrot engage en arene : IN_ARENA", code(w.service:AttemptSteal(Th, V, "v1")) == "IN_ARENA")
w, V, Th = scenario({{Uid = "v1", Id = "noobini", Tier = 1}})
check("Brainrot non pose : NOT_PLACED", code(w.service:AttemptSteal(Th, V, "v1")) == "NOT_PLACED")
w, V, Th = scenario()
check("Uid inconnu : NOT_OWNER ; soi-meme : TARGET_PROTECTED",
    code(w.service:AttemptSteal(Th, V, "zz")) == "NOT_OWNER" and code(w.service:AttemptSteal(V, V, "v1")) == "TARGET_PROTECTED")
w.positions[Th] = pedestal(w, V, 1) + Vector3.new(13, 0, 0)
check("Voleur a 13 studs : TOO_FAR", code(w.service:AttemptSteal(Th, V, "v1")) == "TOO_FAR")
local full = {}
for slot = 1, 3 do full[slot] = {Uid = "t" .. slot, Id = "noobini", Tier = 1, PlacedSlot = slot} end
w, V, Th = scenario(nil, full)
check("Q3 : voleur sans piedestal libre : NO_SLOT", code(w.service:AttemptSteal(Th, V, "v1")) == "NO_SLOT")
local many = {}
for index = 1, 150 do many[index] = {Uid = ("i%03d"):format(index), Id = "noobini", Tier = 1} end
w, V, Th = scenario(nil, many)
check("Q3 : voleur a 150 creatures : INVENTORY_FULL", code(w.service:AttemptSteal(Th, V, "v1")) == "INVENTORY_FULL")

-- Portage, coups et lâcher.
w, V, Th = scenario({{Uid = "v1", Id = "noobini", Tier = 1, PlacedSlot = 1}, {Uid = "v2", Id = "talpa", Tier = 1, PlacedSlot = 2}})
local ok = w.service:AttemptSteal(Th, V, "v1")
check("Vol valide : etat CARRYING", ok == true and w.service:GetSession(Th).State == S.CARRYING)
check("Vitesse pendant le portage : x0.7 (-30 %)", math.abs((w.speeds[Th] or 0) - 0.7) < 1e-9)
check("Loi 8 : le brainrot reste chez la victime pendant le portage", #w.profiles[V].Creatures == 2)
check("LastStealAttempt enregistre a l'heure du vol", w.profiles[Th].LastStealAttempt == 10000)
check("Deuxieme vol pendant le portage : ALREADY_CARRYING", code(w.service:AttemptSteal(Th, V, "v2")) == "ALREADY_CARRYING")
local other = addPlayer(w, "Autre", 303, 600)
w.positions[other] = pedestal(w, V, 2)
check("Meme cible dans les 30 s : ON_COOLDOWN", code(w.service:AttemptSteal(other, V, "v2")) == "ON_COOLDOWN")

local hitter = addPlayer(w, "Defenseur", 404, 900)
w.positions[Th] = Vector3.new(50, 3, 50)
w.positions[hitter] = w.positions[Th] + Vector3.new(11, 0, 0)
local okHit, hit = w.service:HitThief(hitter, Th)
check("Coup 1 a 11 studs accepte", okHit == true and hit.Hits == 1 and hit.Dropped == false)
check("Q4 : second coup dans la seconde : ON_COOLDOWN", code(w.service:HitThief(hitter, Th)) == "ON_COOLDOWN")
w.clock += 1
w.positions[hitter] = w.positions[Th] + Vector3.new(12, 0, 0)
check("Coup a 12 studs : TOO_FAR (G4 : moins de 12)", code(w.service:HitThief(hitter, Th)) == "TOO_FAR")
check("Le voleur ne peut pas se frapper : TARGET_PROTECTED", code(w.service:HitThief(Th, Th)) == "TARGET_PROTECTED")
w.positions[hitter] = w.positions[Th] + Vector3.new(5, 0, 0)
w.service:HitThief(hitter, Th)
w.clock += 1
local okThird, third = w.service:HitThief(hitter, Th)
check("3 coups recus : lache, etat IDLE", okThird == true and third.Dropped == true
    and w.service:GetSession(Th).State == S.IDLE)
check("Vitesse restauree apres le lacher", w.speeds[Th] == 1)
check("Defense comptee dans Stats.Defends", w.profiles[V].Stats.Defends == 1)
local drops = w.service:GetDrops()
check("Brainrot au sol, ramassable", #drops == 1 and drops[1].Uid == "v1" and drops[1].Id == third.DropId)
check("Coup sur un joueur qui ne porte rien : NOT_CARRYING", code(w.service:HitThief(hitter, Th)) == "NOT_CARRYING")

w.positions[other] = drops[1].Position
check("Q5 : ramassage par un autre avant 10 s : NOT_OWNER", code(w.service:ClaimDropped(other, third.DropId)) == "NOT_OWNER")
w.clock = 10031
local okPick, pick = w.service:ClaimDropped(other, third.DropId)
check("Q5 : ramassage apres 10 s (et 30 s de cible) : nouveau portage", okPick == true and pick.Carrying == true
    and w.service:GetSession(other).State == S.CARRYING and #w.service:GetDrops() == 0)
w.clock += 60
w.service:Step()
check("Portage 60 s sans poser : lache au sol", w.service:GetSession(other).State == S.IDLE and #w.service:GetDrops() == 1)
local secondDrop = w.service:GetDrops()[1]
w.positions[V] = secondDrop.Position
local okBack, back = w.service:ClaimDropped(V, secondDrop.Id)
check("Q5 : le proprietaire reprend a tout moment", okBack == true and back.Returned == true and #w.service:GetDrops() == 0)
check("Retour au proprietaire : le brainrot est de nouveau volable", code(w.service:AttemptSteal(hitter, V, "v1")) ~= "NOT_PLACED")

w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.clock += 60
w.service:Step()
w.clock += 59
w.service:Step()
check("Au sol depuis 59 s : toujours au sol", #w.service:GetDrops() == 1)
w.clock += 1
w.service:Step()
check("Q5 : au sol depuis 60 s : retour automatique", #w.service:GetDrops() == 0
    and #w.profiles[V].Creatures == 1)

w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
local second = addPlayer(w, "Second", 505, 1200)
w.positions[second] = pedestal(w, V, 1)
w.clock = 10031
check("Brainrot deja porte (cible hors cooldown) : NOT_PLACED",
    code(w.service:AttemptSteal(second, V, "v1")) == "NOT_PLACED")

-- Pose 5 s et transfert.
w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.positions[Th] = pedestal(w, Th, 1)
check("Pose sur un piedestal hors de Base.Slots : NO_SLOT", code(w.service:BeginSecure(Th, 4)) == "NO_SLOT")
check("Pose commencee sur le piedestal 1", w.service:BeginSecure(Th, 1) == true)
w.clock = 10004.9
check("Pose terminee avant 5 s : SECURE_NOT_READY", code(w.service:CompleteSecure(Th)) == "SECURE_NOT_READY")
w.clock = 10005
local okSecure, secured = w.service:CompleteSecure(Th)
check("Pose 5 s : SECURED puis IDLE", okSecure == true and w.service:GetSession(Th).State == S.IDLE)
check("Transfert effectif : retire chez la victime", #w.profiles[V].Creatures == 0)
local owned = w.profiles[Th].Creatures[1]
check("Transfert effectif : pose chez le voleur au piedestal 1, meme Uid", #w.profiles[Th].Creatures == 1
    and owned.Uid == "v1" and owned.Id == "noobini" and owned.PlacedSlot == 1 and secured.Uid == "v1")
check("Stats.Steals du voleur +1 et rendus des deux bases rafraichis", w.profiles[Th].Stats.Steals == 1
    and w.refreshed[V] == 1 and w.refreshed[Th] == 1)

w, V, Th = scenario(nil, {{Uid = "v1", Id = "talpa", Tier = 1}})
w.service:AttemptSteal(Th, V, "v1")
w.positions[Th] = pedestal(w, Th, 1)
w.service:BeginSecure(Th, 1)
w.clock += 5
local okClash, clash = w.service:CompleteSecure(Th)
check("Uid deja pris chez le voleur : nouvel Uid genere", okClash == true and clash.Uid ~= "v1"
    and #w.profiles[Th].Creatures == 2)

w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.positions[Th] = pedestal(w, Th, 1)
w.service:BeginSecure(Th, 1)
w.clock += 5
w.busy[V] = 1
local okFail, failCode = w.service:CompleteSecure(Th)
check("Loi 8 : retrait impossible chez la victime -> transfert annule", okFail == false and failCode == "BUSY")
check("Loi 8 : ni perte ni doublon apres annulation", #w.profiles[V].Creatures == 1
    and #w.profiles[Th].Creatures == 0 and w.profiles[Th].Stats.Steals == 0)

w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.positions[Th] = pedestal(w, Th, 1)
w.service:BeginSecure(Th, 1)
w.profiles[Th].Creatures = {{Uid = "x1", Id = "talpa", Tier = 1, PlacedSlot = 1}}
w.clock += 5
check("Piedestal occupe entre-temps : SLOT_TAKEN, portage conserve",
    code(w.service:CompleteSecure(Th)) == "SLOT_TAKEN" and w.service:GetSession(Th).State == S.CARRYING)

-- Secret : cooldown x3.
w, V, Th = scenario({{Uid = "s1", Id = "garama", Tier = 1, PlacedSlot = 1}, {Uid = "v2", Id = "noobini", Tier = 1, PlacedSlot = 2}})
local okSecret, secret = w.service:AttemptSteal(Th, V, "s1")
check("Vol d'un Secret : cooldown 180 s (x3)", okSecret == true and secret.Cooldown == 180)
w.clock += 60
w.service:Step()
w.clock += 1
w.positions[Th] = pedestal(w, V, 2)
check("Secret : nouvel essai a +61 s : ON_COOLDOWN", code(w.service:AttemptSteal(Th, V, "v2")) == "ON_COOLDOWN")
w.clock = 10000 + 181
check("Secret : nouvel essai a +181 s : accepte", w.service:AttemptSteal(Th, V, "v2") == true)

-- Départs.
w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.service:PlayerLeft(Th)
check("Voleur parti : portage annule, brainrot rendu", w.service:GetSession(Th).State == S.IDLE
    and #w.service:GetDrops() == 0 and #w.profiles[V].Creatures == 1)
w, V, Th = scenario()
w.service:AttemptSteal(Th, V, "v1")
w.present[V] = nil
w.service:Step()
check("Victime partie : portage annule, vitesse restauree", w.service:GetSession(Th).State == S.IDLE
    and w.speeds[Th] == 1)
check("Stop retourne true", w.service:Stop() == true)

table.insert(T.lines, ("[STEAL TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
