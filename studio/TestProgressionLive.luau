--!nonstrict
--[[ TestProgressionLive
     Rôle    : observer le compteur réel du joueur par SyncProfile, sans rien envoyer au serveur.
     Doc     : GAME_MASTER_V2 G2, A4 ; PROMPT_EXECUTION_SABL_V4 §25.1, §31.5 ; Q1
     Étape   : 5, lot B1
     Dépend  : Play client ; Remotes.SyncProfile, Config.ProgressionConfig
     Exposé  : bilan ; lecture seule du profil réel tel que le client le reçoit
     Limite  : le profil réel est bien modifié pendant le Play, par ProgressionService
               lui-même (+1 s par seconde de jeu) ; ce script ne fait qu'observer.
               Tolérance d'une seconde : les instantanés arrivent au plus une fois par seconde.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsClient() and RunService:IsRunning(), "Exécuter en Play client")
local ProgressionConfig = require(ReplicatedStorage.Config.ProgressionConfig)
local sync = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SyncProfile")

local OBSERVE_SECONDS = 5
local samples = {}
local connection = sync.OnClientEvent:Connect(function(snapshot)
    if type(snapshot) == "table" then
        table.insert(samples, {clock = os.clock(), playtime = snapshot.Playtime, level = snapshot.Level})
    end
end)
task.wait(OBSERVE_SECONDS)
connection:Disconnect()

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local first, last = samples[1], samples[#samples]
check(("Instantanes SyncProfile recus : %d en %d s"):format(#samples, OBSERVE_SECONDS), #samples >= 3)
if first and last and first ~= last then
    local gained = last.playtime - first.playtime
    local elapsed = last.clock - first.clock
    check(("Playtime reel : %d -> %d, soit +%d s en %.1f s"):format(first.playtime, last.playtime, gained, elapsed),
        gained >= math.floor(elapsed) - 1 and gained <= math.ceil(elapsed) + 1)
    check(("Niveau reel %d coherent avec %d s de jeu"):format(last.level, last.playtime),
        last.level >= ProgressionConfig.LevelFor(last.playtime))
end

table.insert(T.lines, ("[PROGRESSION LIVE] %d OK / %d FAIL"):format(T.pass, T.fail))
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
