--!nonstrict
--[[ TestSettingsService
     Rôle    : prouver le remote SetSetting : effets sonores et musique enregistrés dans le profil, test d'abus du §18.4.
     Doc     : GAME_MASTER_V2 G2 (Settings), A6 §11 ; PROMPT_EXECUTION_SABL_V4 §18.2-18.4 ; décision 62
     Étape   : 10, lot A (suggestion du lot 0)
     Dépend  : Play serveur avec un joueur connecté ; Shared.TableUtil, Migrations, RemoteGuard,
               Services.SettingsService, Services.DataService (lecture seule du profil vivant) ; lancé par
               ServerScriptService.Tests.TestRunner
     Exposé  : bilan ; profil factice rangé sous le joueur connecté (RemoteGuard n'admet qu'un vrai joueur) : le profil
               vivant n'est que lu
     Limite  : l'effet du réglage sur les sons se vérifie côté client (studio/TestSettingsClient.luau).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Server = game:GetService("ServerScriptService")
assert(RunService:IsServer(), "Exécuter en Play serveur")
local player = assert(Players:GetPlayers()[1], "Joueur de test requis")
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)
local Migrations = require(Server.Data.Migrations)
local RemoteGuard = require(Server.Networking.RemoteGuard)
local SettingsService = require(Server.Services.SettingsService)
local DataService = require(Server.Services.DataService)

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local clock = 0
local profiles = {[player] = Migrations:Create()}
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
fake.Guard = RemoteGuard.new(function(t) return fake:Get(t) end, {Clock = function() return clock end})
local settings = SettingsService.new({Data = fake, Remote = Instance.new("RemoteFunction")})
settings:Init()
local function set(key, value)
    clock += 1
    return settings:Set(player, key, value)
end

-- ── G2 : les réglages ────────────────────────────────────────────────────
local okOff, off = set("SFX", false)
local sfxOff = profiles[player].Settings.SFX
local okOn = set("SFX", true)
local okMusic = set("Music", false)
check(("G2 : effets sonores coupes (%s) puis remis, musique coupee ; la reponse porte la valeur (%s)")
    :format(tostring(sfxOff), tostring(off and off.Value)),
    okOff == true and off.Key == "SFX" and off.Value == false and sfxOff == false and okOn == true
    and profiles[player].Settings.SFX == true and okMusic == true and profiles[player].Settings.Music == false)

-- ── §18.4 : paramètres absurdes et spam ──────────────────────────────────
local before = TableUtil.DeepCopy(profiles[player])
local codes = {}
local attempts = {
    {"Volume", true}, {nil, true}, {-1, true}, {{}, true}, {string.rep("x", 10000), true},
    {"SFX", "false"}, {"SFX", 0}, {"SFX", nil}, {"Settings", {}},
}
for _, attempt in ipairs(attempts) do
    local ok, code = set(attempt[1], attempt[2])
    table.insert(codes, if ok then "OK" else tostring(code))
end
local refused = 0
for _, code in ipairs(codes) do
    if code == "BAD_SETTING" then refused += 1 end
end
local after = profiles[player]
check(("§18.4 : cle inconnue, nil, -1, table, chaine geante, valeurs non booleennes : %d refus BAD_SETTING sur %d ; profil intact")
    :format(refused, #attempts),
    refused == #attempts and after.Settings.SFX == before.Settings.SFX and after.Settings.Music == before.Settings.Music
    and after.Settings.Volume == nil and after.Settings.Settings == nil)
local limited = 0
for _ = 1, 30 do
    local _, code = settings:Set(player, "SFX", true)
    if code == "RATE_LIMIT" then limited += 1 end
end
check(("§18.4 : spam de 30 reglages dans la meme seconde, %d RATE_LIMIT"):format(limited), limited >= 20)

-- ── Le service vivant ────────────────────────────────────────────────────
local remote = ReplicatedStorage.Remotes:FindFirstChild("SetSetting")
local live = DataService:Get(player)
check(("SettingsService vivant : remote SetSetting present, reglages du testeur SFX=%s Music=%s")
    :format(tostring(live and live.Settings.SFX), tostring(live and live.Settings.Music)),
    remote ~= nil and remote:IsA("RemoteFunction") and live ~= nil and type(live.Settings.SFX) == "boolean")

table.insert(T.lines, ("[SETTINGS TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
