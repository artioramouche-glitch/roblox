--!nonstrict
--[[ TestProgressionService
     Rôle    : vérifier le compteur de temps de jeu et le calcul du niveau.
     Doc     : GAME_MASTER_V2 G2, A4 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.5 ; Q1 (pas de 450 s)
     Étape   : 5, lot B1
     Dépend  : Play serveur avec un joueur connecté ; Migrations, TableUtil, ProgressionConfig ;
               lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; profils factices, aucun profil réel lu ou écrit
     Limite  : le compteur réel du joueur s'observe côté client par SyncProfile
               (studio/TestProgressionLive.luau), pas dans cette batterie.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local Migrations = require(Server.Data.Migrations)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local ProgressionConfig = require(ReplicatedStorage.Config.ProgressionConfig)
local ProgressionService = require(Server.Services.ProgressionService)

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- Q1 et G2 recopiés : les attendus ne sont jamais déduits de la configuration testée.
local L = ProgressionConfig.LevelFor
check("Q1 : un niveau toutes les 450 s", ProgressionConfig.LevelStepSeconds == 450)
check("G2 : niveau de depart 1", ProgressionConfig.StartLevel == 1)
check("LevelFor : 0 s -> 1, 449 s -> 1, 450 s -> 2", L(0) == 1 and L(449) == 1 and L(450) == 2)
check("LevelFor : 1799 s -> 4, 1800 s -> 5 (niveau 5 a 30 min)", L(1799) == 4 and L(1800) == 5)
check("LevelFor : 3600 s -> 9 (1 h de jeu)", L(3600) == 9)
check("LevelFor : valeurs invalides -> 1 (nil, -1, NaN, inf, texte)", L(nil) == 1 and L(-1) == 1
    and L(0 / 0) == 1 and L(math.huge) == 1 and L("900") == 1)
check("Configuration gelee", table.isfrozen(ProgressionConfig))

local function makeService(playtime, level)
    local state = {busy = 0, writes = 0}
    local original = Migrations:Create()
    original.Playtime = playtime or 0
    original.Level = level or 1
    local profiles = {[player] = original}
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
    local service = ProgressionService.new({Data = fake})
    service:Init()
    state.profile = function() return fake:Get(player) end
    state.drop = function() profiles[player] = nil end
    state.restore = function() profiles[player] = original end
    return service, state
end

local service, state = makeService()
local ok, result = service:Credit(player, 1)
check("1 seconde : Playtime 1, niveau 1", ok == true and result.Playtime == 1 and result.Level == 1
    and state.profile().Playtime == 1)
service:Credit(player, 449)
check("450 s cumulees : niveau 2", state.profile().Playtime == 450 and state.profile().Level == 2)

local near, nearState = makeService(1799, 4)
near:Credit(player, 1)
check("1799 s + 1 s : niveau 5 atteint a 1800 s", nearState.profile().Playtime == 1800
    and nearState.profile().Level == 5)

local high, highState = makeService(100, 9)
high:Credit(player, 1)
check("Niveau 9 avec 101 s : le niveau ne baisse jamais", highState.profile().Level == 9
    and highState.profile().Playtime == 101)

local busy, busyState = makeService()
busyState.busy = 2
local okA, codeA = busy:Credit(player, 1)
local okB = busy:Credit(player, 1)
check("Ecriture occupee : refus BUSY, rien d'ecrit", okA == false and codeA == "BUSY" and okB == false
    and busyState.profile().Playtime == 0)
busy:Credit(player, 1)
check("Tick suivant : les 3 secondes dues sont enregistrees", busyState.profile().Playtime == 3)

local absent, absentState = makeService()
absentState.drop()
local okC, codeC = absent:Credit(player, 5)
check("Profil absent : refus NO_PROFILE", okC == false and codeC == "NO_PROFILE")
absentState.restore()
absent:Credit(player, 1)
check("Profil revenu : seules les secondes avec profil comptent (+1)", absentState.profile().Playtime == 1)
check("GetPlaytime et GetLevel lisent le profil", absent:GetPlaytime(player) == 1 and absent:GetLevel(player) == 1)
absentState.drop()
check("Sans profil : GetPlaytime et GetLevel refusent NO_PROFILE",
    select(2, absent:GetPlaytime(player)) == "NO_PROFILE" and select(2, absent:GetLevel(player)) == "NO_PROFILE")

local ticked, tickedState = makeService()
ticked:Tick(2)
check("Tick(2) : +2 s pour le joueur connecte", tickedState.profile().Playtime == 2)
ticked:Tick(0)
check("Tick(0) : aucune ecriture", tickedState.profile().Playtime == 2 and tickedState.writes == 1)
check("Secondes invalides refusees (-5, NaN, inf, texte)",
    select(2, ticked:Credit(player, -5)) == "NO_TICK" and select(2, ticked:Credit(player, 0 / 0)) == "NO_TICK"
    and select(2, ticked:Credit(player, math.huge)) == "NO_TICK"
    and select(2, ticked:Credit(player, "3")) == "NO_TICK" and tickedState.profile().Playtime == 2)
check("Stop retourne true", ticked:Stop() == true)
local okD, codeD = ticked:Credit(player, 1)
check("Apres Stop : plus aucun credit", okD == false and codeD == "INTERNAL"
    and tickedState.profile().Playtime == 2)

table.insert(T.lines, ("[PROGRESSION TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
