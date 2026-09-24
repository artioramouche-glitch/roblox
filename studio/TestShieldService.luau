--!nonstrict
--[[ TestShieldService
     Rôle    : vérifier les chiffres du bouclier et le cycle de protection de chaque base.
     Doc     : GAME_MASTER_V2 A4, A5, G2 ; PROMPT_EXECUTION_SABL_V4 §16.6, §25.1, §31.5
     Étape   : 5, lot A
     Dépend  : Play serveur avec un joueur connecté ; Migrations, TableUtil, StealConfig ;
               lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; profils et plots factices, horloge simulée, aucun profil réel lu ou écrit
     Limite  : les attributs ShieldState et ShieldPhaseEndsAt du joueur de test sont écrasés
               pendant la batterie ; l'instance réelle les remet au tick suivant, ce que
               vérifient les deux derniers contrôles. L'écriture occupée provoque un
               avertissement [SHIELD] attendu dans la console.
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
local StealConfig = require(ReplicatedStorage.Config.StealConfig)
local ShieldService = require(Server.Services.ShieldService)
local S = ShieldService.BaseState

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- A4 et A5 recopiés : les attendus ne sont jamais déduits de la configuration testée.
local minutes = StealConfig.Shield.MinutesByGenerator
check("A5 : generateur 1/2/3 = 5/6/7 min", minutes[1] == 5 and minutes[2] == 6 and minutes[3] == 7)
check("A5 : 300/360/420 s", StealConfig.GetShieldSeconds(1) == 300
    and StealConfig.GetShieldSeconds(2) == 360 and StealConfig.GetShieldSeconds(3) == 420)
check("Q2 option A : aucun bouclier au niveau 0", StealConfig.GetShieldSeconds(0) == nil)
check("Niveaux invalides refuses (4, -1, 1.5, nil, texte, NaN)", StealConfig.GetShieldSeconds(4) == nil
    and StealConfig.GetShieldSeconds(-1) == nil and StealConfig.GetShieldSeconds(1.5) == nil
    and StealConfig.GetShieldSeconds(nil) == nil and StealConfig.GetShieldSeconds("1") == nil
    and StealConfig.GetShieldSeconds(0 / 0) == nil)
check("A4 : alerte 60 s", StealConfig.GetAlertSeconds() == 60)
check("A4 : vulnerable 8 min = 480 s", StealConfig.Shield.VulnerableMinutes == 8
    and StealConfig.GetVulnerableSeconds() == 480)
check("Configuration gelee", table.isfrozen(StealConfig) and table.isfrozen(StealConfig.Shield)
    and table.isfrozen(minutes))

local function profileWith(generator, shieldEndsAt, vulnerableEndsAt)
    local profile = Migrations:Create()
    profile.Base.Generator = generator
    profile.ShieldEndsAt = shieldEndsAt or 0
    profile.VulnerableEndsAt = vulnerableEndsAt or 0
    return profile
end
local compute = ShieldService.ComputePhase

-- Calcul pur, générateur 1 : cycle de 300 + 60 + 480 = 840 s.
local phase, endsAt, write = compute(profileWith(0), 1000)
check("Sans generateur : VULNERABLE, sans fin de phase ni ecriture",
    phase == S.VULNERABLE and endsAt == 0 and write == nil)
phase, endsAt, write = compute(profileWith(0, 1300, 1840), 1000)
check("Sans generateur : horodatages perimes remis a 0", phase == S.VULNERABLE
    and write ~= nil and write.ShieldEndsAt == 0 and write.VulnerableEndsAt == 0)
phase, endsAt, write = compute(profileWith(1), 1000)
check("Premier cycle a t=1000 : SHIELDED jusqu'a 1300", phase == S.SHIELDED and endsAt == 1300)
check("Premier cycle : ecriture 1300 / 1840", write ~= nil and write.ShieldEndsAt == 1300
    and write.VulnerableEndsAt == 1840)

local bounds, silent = true, true
for _, case in ipairs({
    {1299, S.SHIELDED, 1300}, {1300, S.ALERT, 1360}, {1359, S.ALERT, 1360},
    {1360, S.VULNERABLE, 1840}, {1839, S.VULNERABLE, 1840},
}) do
    local p, e, w = compute(profileWith(1, 1300, 1840), case[1])
    bounds = bounds and p == case[2] and e == case[3]
    silent = silent and w == nil
end
check("Bouclier 5 min -> alerte 60 s -> vulnerable 8 min, bornes exactes", bounds)
check("Aucune ecriture pendant le cycle en cours", silent)
phase, endsAt, write = compute(profileWith(1, 1300, 1840), 1840)
check("Fin de cycle a 1840 : SHIELDED jusqu'a 2140, ecriture 2140 / 2680", phase == S.SHIELDED
    and endsAt == 2140 and write ~= nil and write.ShieldEndsAt == 2140 and write.VulnerableEndsAt == 2680)

local _, ends2 = compute(profileWith(2), 1000)
local _, ends3 = compute(profileWith(3), 1000)
check("Generateur 2 : 6 min ; generateur 3 : 7 min", ends2 == 1360 and ends3 == 1420)

phase, endsAt, write = compute(profileWith(1, 1300, 1840), 1840 + 3 * 840 + 400)
check("Hors ligne 3 cycles + 400 s : VULNERABLE jusqu'a 5200", phase == S.VULNERABLE and endsAt == 5200
    and write ~= nil and write.ShieldEndsAt == 4660 and write.VulnerableEndsAt == 5200)
phase, endsAt = compute(profileWith(1, 1300, 1840), 1840 + 3 * 840 + 100)
check("Hors ligne 3 cycles + 100 s : SHIELDED jusqu'a 4660", phase == S.SHIELDED and endsAt == 4660)
phase, endsAt, write = compute(profileWith(1, 1300, 1840), 1500)
check("Rejoin en phase VULNERABLE : bouclier non relance, aucune ecriture",
    phase == S.VULNERABLE and endsAt == 1840 and write == nil)
phase, endsAt, write = compute(profileWith(1, 2000, 1000), 1000)
check("Horodatages incoherents : nouveau cycle protege", phase == S.SHIELDED and endsAt == 1300 and write ~= nil)
check("Profil invalide : VULNERABLE sans ecriture", select(3, compute(nil, 1000)) == nil)

-- Service complet : données, plots, dossier d'effets et horloge factices.
local function makeService(generator)
    local state = {clock = 1000, writes = 0, busy = 0}
    local profiles = {[player] = profileWith(generator)}
    local fake = {}
    function fake:Get(target) local s = profiles[target] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(target, callback)
        if state.busy > 0 then state.busy -= 1 return false, "BUSY" end
        local current = profiles[target]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(callback, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        profiles[target] = reconciled
        state.writes += 1
        return true, result
    end
    local map = Instance.new("Folder")
    local plots = Instance.new("Folder")
    plots.Name = "Plots"
    plots.Parent = map
    for index = 1, 2 do
        local plot = Instance.new("Part")
        plot.Name = "Plot" .. index
        plot.Anchored = true
        plot.Size = Vector3.new(80, 1, 80)
        plot.Position = Vector3.new(index * 200, 1.5, 0)
        plot:SetAttribute("Owner", "")
        plot.Parent = plots
    end
    plots.Plot1:SetAttribute("Owner", tostring(player.UserId))
    local effects = Instance.new("Folder")
    local service = ShieldService.new({
        Data = fake, Map = map, Effects = effects, Clock = function() return state.clock end,
    })
    service:Init()
    state.profile = function() return fake:Get(player) end
    state.drop = function() profiles[player] = nil end
    return service, state, plots, effects
end

local service, state, plots, effects = makeService(1)
service:Step()
check("Step t=1000 : ShieldState = SHIELDED, fin 1300", player:GetAttribute("ShieldState") == S.SHIELDED
    and player:GetAttribute("ShieldPhaseEndsAt") == 1300)
check("Premier cycle enregistre dans le profil, une ecriture", state.profile().ShieldEndsAt == 1300
    and state.profile().VulnerableEndsAt == 1840 and state.writes == 1)
local dome = effects:FindFirstChild("ShieldDome_Plot1")
check("Dome ShieldDome_Plot1 cree", dome ~= nil and dome:IsA("Part"))
check("Dome : sphere ancree, sans collision, requete ni contact", dome ~= nil
    and dome.Shape == Enum.PartType.Ball and dome.Anchored and not dome.CanCollide
    and not dome.CanQuery and not dome.CanTouch)
check("Dome : bleu 4CC9F0, centre sur le plot, couvre ses coins", dome ~= nil
    and dome.Color:ToHex():upper() == "4CC9F0"
    and (dome.Position - plots.Plot1.Position).Magnitude < 0.01
    and dome.Size.X / 2 >= math.sqrt(40 ^ 2 + 40 ^ 2))
check("Dome : attribut Owner = UserId", dome ~= nil and dome:GetAttribute("Owner") == tostring(player.UserId))
check("Plot sans proprietaire : aucun dome", effects:FindFirstChild("ShieldDome_Plot2") == nil)
service:Step()
check("Second Step sans changement : aucune ecriture de plus", state.writes == 1)

state.clock = 1300
service:Step()
check("t=1300 : ALERT jusqu'a 1360", player:GetAttribute("ShieldState") == S.ALERT
    and player:GetAttribute("ShieldPhaseEndsAt") == 1360)
local first = dome and dome.Transparency
state.clock = 1301
service:Step()
local second = dome and dome.Transparency
check("Alerte : dome rouge E63946 qui clignote d'un tick a l'autre", dome ~= nil
    and dome.Color:ToHex():upper() == "E63946" and first ~= second)

state.clock = 1360
service:Step()
check("t=1360 : VULNERABLE jusqu'a 1840, dome retire", player:GetAttribute("ShieldState") == S.VULNERABLE
    and player:GetAttribute("ShieldPhaseEndsAt") == 1840 and effects:FindFirstChild("ShieldDome_Plot1") == nil)

state.clock = 1500
local gotPhase, gotEnds = service:GetPhase(player)
check("GetPhase sans Step : VULNERABLE jusqu'a 1840", gotPhase == S.VULNERABLE and gotEnds == 1840)

state.busy = 1
state.clock = 1840
service:Step()
check("Ecriture occupee en fin de cycle : SHIELDED publie jusqu'a 2140",
    player:GetAttribute("ShieldState") == S.SHIELDED and player:GetAttribute("ShieldPhaseEndsAt") == 2140)
check("Ecriture occupee : profil pas encore modifie", state.profile().ShieldEndsAt == 1300)
service:Step()
check("Tick suivant : 2140 / 2680 enregistres", state.profile().ShieldEndsAt == 2140
    and state.profile().VulnerableEndsAt == 2680)
check("Dome recree au nouveau cycle", effects:FindFirstChild("ShieldDome_Plot1") ~= nil)

plots.Plot1:SetAttribute("Owner", "")
service:Step()
check("Plot libere : dome retire", effects:FindFirstChild("ShieldDome_Plot1") == nil)
check("Stop retourne true", service:Stop() == true)
check("Apres Stop : GetPhase refuse INTERNAL", select(2, service:GetPhase(player)) == "INTERNAL")

local zero, zeroState, _, zeroEffects = makeService(0)
zero:Step()
check("Generateur 0 : VULNERABLE, fin 0, aucun dome, aucune ecriture",
    player:GetAttribute("ShieldState") == S.VULNERABLE and player:GetAttribute("ShieldPhaseEndsAt") == 0
    and zeroEffects:FindFirstChild("ShieldDome_Plot1") == nil and zeroState.writes == 0)
zero:Stop()

local missing, missingState, _, missingEffects = makeService(1)
missingState.drop()
missing:Step()
check("Profil absent : NO_PROFILE et aucun dome", select(2, missing:GetPhase(player)) == "NO_PROFILE"
    and missingEffects:FindFirstChild("ShieldDome_Plot1") == nil)
missing:Stop()

local stopper, _, _, stopperEffects = makeService(1)
stopper:Step()
local hadDome = stopperEffects:FindFirstChild("ShieldDome_Plot1") ~= nil
stopper:Stop()
check("Stop retire les domes crees", hadDome and stopperEffects:FindFirstChild("ShieldDome_Plot1") == nil)

-- Instance réelle démarrée par Main : lecture seule, le profil réel n'a pas de générateur.
task.wait(1.5)
check("Instance reelle : ShieldState = VULNERABLE et fin 0 (generateur 0)",
    player:GetAttribute("ShieldState") == S.VULNERABLE and player:GetAttribute("ShieldPhaseEndsAt") == 0)
local effectsFolder = Workspace:FindFirstChild("Effects")
local realDomes = 0
for _, child in ipairs(effectsFolder and effectsFolder:GetChildren() or {}) do
    if child.Name:sub(1, 11) == "ShieldDome_" then realDomes += 1 end
end
check("Instance reelle : aucun dome dans Workspace.Effects", effectsFolder ~= nil and realDomes == 0)

table.insert(T.lines, ("[SHIELD TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
