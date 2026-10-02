--!nonstrict
--[[ TestAntiCheatConfig
     Rôle    : vérifier l'escalade des sanctions et le contrôle de vitesse de l'anti-triche G3.
     Doc     : GAME_MASTER_V2 G3 ; PROMPT_EXECUTION_SABL_V4 §23, §31.12 lot C ; Q1-Q2 de l'étape 12
     Étape   : 12, lot C (configuration)
     Dépend  : ReplicatedStorage.Config.AntiCheatConfig, RemoteConfig, MapConfig
     Exposé  : exécution manuelle ; aucune écriture de données, aucune sanction
     Limite  : ne prouve que les règles ; le comptage par remote, BanAsync et le retour en arrière se testent en Play
               (BanAsync probablement sur un serveur réel seulement).
]]
local config = assert(game:GetService("ReplicatedStorage"):FindFirstChild("Config"), "Config absent")
local A = require(assert(config:FindFirstChild("AntiCheatConfig"), "AntiCheatConfig absent"))
local R = require(assert(config:FindFirstChild("RemoteConfig"), "RemoteConfig absent"))
local Map = require(assert(config:FindFirstChild("MapConfig"), "MapConfig absent"))
local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

-- G3 et Q1, recopiés ici.
local e = A.Escalation
check("G3 : 10 requêtes/s (RemoteConfig inchangé)", R.MaxRequestsPerWindow == 10 and R.WindowSeconds == 1)
check("Q1 : 3 infractions en 60 s → avertissement", e.InfractionsForWarning == 3 and e.InfractionWindow == 60)
check("Q1 : 3 avertissements en 600 s → exclusion", e.WarningsForKick == 3 and e.WarningWindow == 600)
check("Q1 : 2e exclusion en 86 400 s → ban", e.KicksForBan == 2 and e.KickWindow == 86400)
check("G3 : exclusion 60 s, ban 86 400 s", e.KickSeconds == 60 and e.BanSeconds == 86400)
check("G3 : 50 studs par image, 60 images/s", A.Speed.MaxStudsPerFrame == 50 and A.Speed.FramesPerSecond == 60)

-- Rejoue une suite d'infractions ; renvoie les actions et l'état final.
local function play(times, state)
    local actions = {}
    for _, at in ipairs(times) do
        local action
        state, action = A.OnInfraction(state, at)
        table.insert(actions, action)
    end
    return table.concat(actions, ","), state
end
check("2 infractions → rien", (play({0, 10})) == "none,none")
check("3 infractions en 1 min → avertissement", (play({0, 10, 59})) == "none,none,warn")
check("La 1re sort de la fenêtre à 60 s pile", (play({0, 30, 60})) == "none,none,none")
check("Après un avertissement, le compte repart", (play({0, 1, 2, 3, 4})) == "none,none,warn,none,none")
local nine = {0, 1, 2, 100, 101, 102, 200, 201, 202}
check("3 avertissements en 10 min → exclusion", (play(nine)) == "none,none,warn,none,none,warn,none,none,kick")
local spread = {0, 1, 2, 300, 301, 302, 601, 602, 603}
check("Avertissements étalés sur plus de 10 min → pas d'exclusion",
    (play(spread)) == "none,none,warn,none,none,warn,none,none,warn")
local _, afterKick = play(nine)
local again = {}
for _, at in ipairs(nine) do table.insert(again, at + 3600) end
check("2e exclusion dans les 24 h → ban", select(1, play(again, afterKick)):sub(-3) == "ban")
local later = {}
for _, at in ipairs(nine) do table.insert(later, at + 86400) end
check("Exclusion de plus de 24 h oubliée → nouvelle exclusion", select(1, play(later, afterKick)):sub(-4) == "kick")
local _, fromBadState = A.OnInfraction({Infractions = "x", Warnings = {false, "1"}, Kicks = 3}, 50)
check("État absent ou mal formé ignoré", (A.OnInfraction(nil, 0)) ~= nil and select(2, A.OnInfraction(nil, 0)) == "none"
    and fromBadState == "none")
local kept = select(1, A.OnInfraction({Kicks = {-90000, 100}}, 200))
check("Exclusions de plus de 24 h purgées de l'état", #kept.Kicks == 1 and kept.Kicks[1] == 100)

-- Vitesse : 50 studs par image (1/60 s) ; au moins une image comptée.
local frame = 1 / 60
check("50 studs en une image : toléré", not A.ExceedsSpeed(50, frame))
check("50,1 studs en une image : rollback", A.ExceedsSpeed(50.1, frame))
check("Téléportation de 200 studs en une image : rollback", A.ExceedsSpeed(200, frame))
local bounce = Map.Trampoline.LaunchSpeed * frame
check(("Trampoline (%.2f studs par image, dette 14) : toléré"):format(bounce), not A.ExceedsSpeed(bounce, frame))
check("Image longue de 0,5 s : 1 500 studs permis", not A.ExceedsSpeed(1400, 0.5) and A.ExceedsSpeed(1600, 0.5))
check("dt nul, négatif ou NaN : une image", A.ExceedsSpeed(51, 0) and A.ExceedsSpeed(51, -1)
    and A.ExceedsSpeed(51, 0 / 0) and not A.ExceedsSpeed(49, 0 / 0))

local summary = ("[ANTICHEAT CONFIG TEST] %d OK / %d FAIL"):format(T.pass, T.fail)
table.insert(T.lines, summary)
local output = table.concat(T.lines, "\n")
print(output)
return {passed = T.pass, failed = T.fail, success = T.fail == 0, output = output}
