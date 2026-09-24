--!nonstrict
--[[ TestVaultService
     Rôle    : prouver le coffre-fort : capacité par niveau, 50 % du revenu pendant l'absence, schéma v3 (LastSeenAt).
     Doc     : GAME_MASTER_V2 A5, C2, G2 ; PROMPT_EXECUTION_SABL_V4 §31.9 lot F ; décision 44 (Q6)
     Étape   : 9, lot F1 ; coffre plein au lot F2
     Dépend  : Play serveur avec un joueur connecté ; Config.UpgradeConfig, Config.DefaultProfile, Shared.TableUtil,
               Migrations, Services.VaultService ; lancé par ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; joueurs et profils factices, horloge injectée. Le joueur réel n'est que lu (ses attributs)
     Limite  : le versement réel se prouve à part : coffre acheté, départ, retour (annoncé au Producer).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local UpgradeConfig = require(ReplicatedStorage.Config.UpgradeConfig)
local DefaultProfile = require(ReplicatedStorage.Config.DefaultProfile)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local Migrations = require(Server.Data.Migrations)
local VaultService = require(Server.Services.VaultService)

local HOUR = 3600
local NOW = 1000000 -- horloge injectée
local NOOBINI = {Uid = "aaa", Id = "noobini", Tier = 1, PlacedSlot = 1} -- B1 : 10/s

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- ── Q6 : capacité et taux ────────────────────────────────────────────────
local capacities = {}
for level = 0, 5 do table.insert(capacities, UpgradeConfig.VaultCapacitySeconds(level) / HOUR) end
check(("Q6 : capacite %s h aux niveaux 0 a 5, taux %d %%"):format(table.concat(capacities, "/"),
    UpgradeConfig.VaultIncomeShare * 100),
    table.concat(capacities, "/") == "0/1/2/4/8/12" and UpgradeConfig.VaultIncomeShare == 0.5)
local invalid = true
for _, level in ipairs({-1, "2", 0 / 0}) do
    if UpgradeConfig.VaultCapacitySeconds(level) ~= 0 then invalid = false end
end
check("Niveaux invalides (-1, texte, NaN) : aucune capacite ; niveau 9 plafonne a 12 h",
    invalid and UpgradeConfig.VaultCapacitySeconds(9) == 12 * HOUR)
local vault = UpgradeConfig.Get("Vault")
check("A5 : Coffre-fort achetable, 10K au niveau 1 et 10M au niveau 5",
    vault.Available == true and UpgradeConfig.NextPrice("Vault", 0) == 10000
    and UpgradeConfig.NextPrice("Vault", 4) == 10000000)

-- ── G2 : schéma v3 ───────────────────────────────────────────────────────
local fromV2, errorV2 = Migrations:Apply({DataVersion = 2, Money = 7, Creatures = {}})
local future, futureError = Migrations:Apply({DataVersion = 4})
check("Migration v2 -> v3 : LastSeenAt a 0 (presence inconnue), argent garde ; profil v4 refuse (FUTURE_VERSION)",
    DefaultProfile.DataVersion == 3 and DefaultProfile.LastSeenAt == 0 and errorV2 == nil
    and fromV2.DataVersion == 3 and fromV2.LastSeenAt == 0 and fromV2.Money == 7
    and future == nil and futureError == "FUTURE_VERSION")

-- ── Faux joueurs, faux profils, horloge injectée ─────────────────────────
local clock = {now = NOW}
local function fakePlayer(id)
    return {UserId = id, Attributes = {}, SetAttribute = function(self, name, value) self.Attributes[name] = value end}
end
local function makeVault(target, profile)
    local profiles = {[target] = profile}
    local fake = {}
    function fake:Get(t) local s = profiles[t] return s and TableUtil.DeepCopy(s) or nil end
    function fake:Update(t, cb)
        local current = profiles[t]
        if not current then return false, "NO_PROFILE" end
        local candidate = TableUtil.DeepCopy(current)
        local ok, accepted, result = pcall(cb, candidate)
        if not ok or type(accepted) ~= "boolean" then return false, "INTERNAL" end
        if not accepted then return false, result end
        local reconciled, reason = Migrations:Apply(candidate)
        if not reconciled then return false, reason end
        profiles[t] = reconciled
        return true, result
    end
    local service = VaultService.new({Data = fake, Clock = function() return clock.now end})
    service:Init()
    return service, fake
end
local function vaultProfile(level, lastSeen, creatures, rebirths)
    local profile = Migrations:Create()
    profile.Base.Vault = level
    profile.LastSeenAt = lastSeen
    profile.Rebirths = rebirths or 0
    profile.Creatures = creatures or {TableUtil.DeepCopy(NOOBINI)}
    return profile
end

-- ── Décision 44 : le versement au retour ─────────────────────────────────
local first = fakePlayer(1)
local vaultA, dataA = makeVault(first, vaultProfile(1, NOW - 1800))
local okA, resultA = vaultA:Settle(first)
local afterA = dataA:Get(first)
check(("Niveau 1, absent 30 min, noobini pose (10/s) : +%d = 10 x 1 800 s x 50 %%"):format(resultA and resultA.Gain or -1),
    okA == true and resultA.Gain == 9000 and afterA.Money == 9000 and afterA.Stats.Earned == 9000
    and afterA.LastSeenAt == NOW and first.Attributes.VaultOfflineIncome == 9000
    and first.Attributes.VaultOfflineSeconds == 1800 and first.Attributes.VaultOfflineFull == false)

-- Dernière colonne : coffre plein (l'absence a dépassé sa capacité), signalé au lot F2.
local cases = {
    {"Niveau 3 (4 h), absent 10 h : plafonne a 4 h, coffre plein", 3, NOW - 10 * HOUR, nil, 72000, 4 * HOUR, true},
    {"Sans coffre, absent 5 h : rien", 0, NOW - 5 * HOUR, nil, 0, 0, false},
    {"Premier retour (presence inconnue) : rien", 5, 0, nil, 0, 0, false},
    {"Derniere presence dans le futur : rien", 5, NOW + 600, nil, 0, 0, false},
    {"Reserve d'or seule : pas de revenu, rien", 5, NOW - HOUR,
        {{Uid = "r1", Id = "noobini", Tier = 1, Reserve = true}}, 0, HOUR, false},
}
for index, case in ipairs(cases) do
    local target = fakePlayer(10 + index)
    local service, fake = makeVault(target, vaultProfile(case[2], case[3], case[4]))
    local ok, result = service:Settle(target)
    local after = fake:Get(target)
    check(("%s : +%d pour %d s"):format(case[1], result and result.Gain or -1, result and result.Seconds or -1),
        ok == true and result.Gain == case[5] and result.Seconds == case[6] and after.Money == case[5]
        and after.LastSeenAt == NOW and target.Attributes.VaultOfflineIncome == case[5]
        and target.Attributes.VaultOfflineFull == case[7])
end

local reborn = fakePlayer(20)
local vaultR = makeVault(reborn, vaultProfile(1, NOW - HOUR, nil, 1))
local okR, resultR = vaultR:Settle(reborn)
check(("C2 : le revenu d'absence suit tous les multiplicateurs, rebirth 1 (x2) : +%d"):format(resultR and resultR.Gain or -1),
    okR == true and resultR.Gain == 36000)

local twice = fakePlayer(21)
local vaultT, dataT = makeVault(twice, vaultProfile(1, NOW - 600))
local touchedEarly = vaultT:Touch(twice)
vaultT:Settle(twice)
local okAgain, codeAgain = vaultT:Settle(twice)
clock.now = NOW + 45
local touched = vaultT:Touch(twice)
local afterT = dataT:Get(twice)
clock.now = NOW
check(("Un seul versement par session (%s) ; presence avancee seulement apres le versement (%s puis %s)")
    :format(tostring(codeAgain), tostring(touchedEarly), tostring(touched)),
    okAgain == false and codeAgain == "ALREADY_SETTLED" and afterT.Money == 3000 and touchedEarly == false
    and touched == true and afterT.LastSeenAt == NOW + 45)

-- ── Service vivant : le retour du joueur réel a été réglé à sa connexion ──
local paid, covered = player:GetAttribute("VaultOfflineIncome"), player:GetAttribute("VaultOfflineSeconds")
check(("VaultService vivant : retour regle a la connexion (verse %s pour %s s)"):format(tostring(paid), tostring(covered)),
    type(paid) == "number" and type(covered) == "number")

table.insert(T.lines, ("[VAULT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
