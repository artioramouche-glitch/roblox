--!nonstrict
--[[ TestSoundClient
     Rôle    : vérifier la sirène de l'alarme (A7, « sirène 2 tons ») : son livré avec Roblox chargé, entendu pour une
               alarme publiée par le serveur, deux hauteurs alternées, une seule sirène par alarme, arrêt ensuite.
     Doc     : GAME_MASTER_V2 A7, A5 (Alarme) ; PROMPT_EXECUTION_SABL_V4 §25 ; décision 43
     Étape   : 10, lot 0
     Dépend  : Play en cours, datamodel Client, lancé dans les 30 s qui suivent studio/FixtureAlarmShow.luau (voleur
               simulé en solo) ; Controllers.SoundController démarré (SoundService.Sirene)
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas require
     Limite  : la seconde alarme est simulée en local sur le client (rien n'est envoyé au serveur), puis les attributs
               d'origine sont rétablis. Settings.SFX coupé vient du profil serveur : ce cas n'est pas simulé ici.
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local SIREN_ID = "rbxasset://sounds/electronicpingshort.wav" -- Controllers.SoundController
local TONES = {1, 4 / 3}
local SIREN_SECONDS = 8 * 0.35 -- 8 notes de 0,35 s
local SAMPLE_SECONDS = 0.05
local LOAD_WAIT = 5 -- s
local SERVER_WAIT = 35 -- s : le voleur simulé par la fixture dure 30 s
local SIMULATED = {"AlarmVictimUserId", "AlarmCreatureId", "AlarmLevel"}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.001 end

local player = Players.LocalPlayer
local siren = SoundService:WaitForChild("Sirene", 10)
local deadline = os.clock() + LOAD_WAIT
while siren and not siren.IsLoaded and os.clock() < deadline do task.wait(0.1) end
check(("Sirene prete : son livre avec Roblox, charge (%.2f s)"):format(siren and siren.TimeLength or 0),
    siren ~= nil and siren.SoundId == SIREN_ID and siren.IsLoaded and siren.TimeLength > 0)

-- L'alarme publiée par le serveur (fixture, voleur simulé) : surlignage reçu, sirène jouée, puis tout se retire.
local character = player.Character
local serverLevel = player:GetAttribute("AlarmLevel")
local marked = character ~= nil and character:FindFirstChild("AlarmeSurlignage") ~= nil
deadline = os.clock() + SERVER_WAIT
while (player:GetAttribute("AlarmLevel") or 0) > 0 and os.clock() < deadline do task.wait(0.25) end
task.wait(0.5)
local played = siren and (siren:GetAttribute("Joues") or 0) or 0
check(("Alarme du serveur (niveau %s) : surlignage recu, sirene jouee (%d fois), puis alarme et surlignage retires")
    :format(tostring(serverLevel), played),
    serverLevel == 3 and marked and played >= 1 and (player:GetAttribute("AlarmLevel") or 0) == 0
    and (character == nil or character:FindFirstChild("AlarmeSurlignage") == nil))

-- Simulation locale : une alarme sonne ; on relève les hauteurs pendant toute la sirène.
local saved = {}
for _, name in ipairs(SIMULATED) do saved[name] = player:GetAttribute(name) end
player:SetAttribute("AlarmVictimUserId", 1)
player:SetAttribute("AlarmCreatureId", "noobini")
player:SetAttribute("AlarmLevel", 1)
local heard, playing = {}, false
local started = os.clock()
while os.clock() - started < SIREN_SECONDS - 0.4 do
    task.wait(SAMPLE_SECONDS)
    if siren and siren.IsPlaying then
        playing = true
        heard[math.round(siren.PlaybackSpeed * 1000)] = true
    end
end
player:SetAttribute("AlarmLevel", 2) -- même portage, niveau changé : pas de seconde sirène
task.wait(0.8)
local count = siren and (siren:GetAttribute("Joues") or 0) or 0
local stopped = siren ~= nil and not siren.IsPlaying
for _, name in ipairs(SIMULATED) do player:SetAttribute(name, saved[name]) end
local tones = {}
for key in pairs(heard) do table.insert(tones, key / 1000) end
table.sort(tones)
local shown = {}
for _, tone in ipairs(tones) do table.insert(shown, ("%.3f"):format(tone)) end
check(("A7 : sirene a deux tons, hauteurs entendues %s"):format(table.concat(shown, " / ")),
    playing and #tones == 2 and near(tones[1], TONES[1]) and near(tones[2], TONES[2]))
check(("Une seule sirene par alarme (%d -> %d), arretee apres ses notes"):format(played, count),
    count == played + 1 and stopped)

table.insert(T.lines, ("[SOUND CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
