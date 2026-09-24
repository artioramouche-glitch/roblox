--!nonstrict
--[[ TestSfxClient
     Rôle    : vérifier les sons A7 côté client : sons préchargés, casse d'œuf après un achat, saisie et pose jouées sur
               le voleur, rebond du trampoline repris par SoundController.
     Doc     : GAME_MASTER_V2 A7, A4, D1.3 Z7 ; PROMPT_EXECUTION_SABL_V4 §25 ; décisions 31 et 61
     Étape   : 10, lot A (suggestions du lot 0)
     Dépend  : Play en cours, datamodel Client ; Controllers.SoundController et TrampolineController démarrés ; lancé
               après un achat d'œuf par clic (annoncé) ; un PROP_trampoline de la map habillée
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas require
     Limite  : saisie et pose sont simulées en local (attributs du joueur, rien n'est envoyé au serveur), puis
               rétablies. Le rebond se déclenche en lâchant le personnage au-dessus d'une toile, comme à l'étape 8,
               puis le personnage revient à sa place. La fanfare demande une vraie fusion : elle n'est pas jouée ici.
]]
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local PRELOADED = {Sirene = "electronicpingshort.wav", CasseOeuf = "snap.mp3", Fanfare = "victory.wav"}
local EGG_PITCHES = {1, 1.12, 1.25, 1.4, 1.6} -- les 5 variantes de la casse d'œuf (Controllers.SoundController)
local GRAB_PITCH, BOUNCE_PITCH = 0.7, 1.6
local SETTLE_SECONDS = 0.3
local SAMPLE_SECONDS = 0.02
local BOUNCE_SECONDS = 3
local FEET_TO_ROOT = 3 -- studs : hanches d'un avatar au-dessus de ses pieds
local DROP_HEIGHT = 4 -- studs lâchés au-dessus de la toile, comme à l'étape 8
local RISE_SPEED = 50 -- studs/s : moitié du lancer de MapConfig (100), signe d'un rebond

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end
local function near(a, b) return a ~= nil and b ~= nil and math.abs(a - b) < 0.001 end
local function plays(sound) return sound and (sound:GetAttribute("Joues") or 0) or 0 end

local player = Players.LocalPlayer
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")

local ready = 0
for name, file in pairs(PRELOADED) do
    local sound = SoundService:FindFirstChild(name)
    if sound and sound.SoundId == "rbxasset://sounds/" .. file and sound.IsLoaded then ready += 1 end
end
check(("Sons sans position prets : %d / 3 (sirene, casse d'oeuf, fanfare)"):format(ready), ready == 3)

local egg = SoundService:FindFirstChild("CasseOeuf")
local variant = false
for _, pitch in ipairs(EGG_PITCHES) do
    if egg and near(egg.PlaybackSpeed, pitch) then variant = true end
end
check(("A7 : casse d'oeuf jouee apres l'achat (%d fois), note %.2f parmi les 5 variantes"):format(plays(egg),
    egg and egg.PlaybackSpeed or 0), plays(egg) >= 1 and variant)

-- Simulation locale : le joueur saisit un brainrot, puis le pose.
local savedState, savedSecured = player:GetAttribute("StealState"), player:GetAttribute("StealSecuredAt")
player:SetAttribute("StealState", "IDLE")
player:SetAttribute("StealState", "CARRYING")
task.wait(SETTLE_SECONDS)
local grab = root and root:FindFirstChild("Saisie")
local grabPlays, grabPitch = plays(grab), grab and grab.PlaybackSpeed
player:SetAttribute("StealSecuredAt", Workspace:GetServerTimeNow())
local notes = {}
local started = os.clock()
while os.clock() - started < SETTLE_SECONDS + 0.1 do
    task.wait(SAMPLE_SECONDS)
    local secure = root and root:FindFirstChild("Securise")
    if secure and secure.IsPlaying then notes[math.round(secure.PlaybackSpeed * 100)] = true end
end
player:SetAttribute("StealState", savedState)
player:SetAttribute("StealSecuredAt", savedSecured)
local secure = root and root:FindFirstChild("Securise")
check(("A7 : saisie « boing » jouee sur le voleur (note %s) ; pose « cha-ching » en deux notes (1,50 puis 2,00 : %s)")
    :format(tostring(grabPitch), tostring(notes[150] == true and notes[200] == true)),
    grabPlays >= 1 and near(grabPitch, GRAB_PITCH) and plays(secure) >= 1 and notes[150] == true and notes[200] == true)

-- Rebond : le personnage est lâché au-dessus d'une toile, puis ramené à sa place.
local trampoline = Workspace:FindFirstChild("PROP_trampoline1", true)
local bed = trampoline and trampoline:FindFirstChild("Bed")
local bounces, rising, heard = 0, false, 0
local rebondBefore = plays(root and root:FindFirstChild("Rebond"))
if bed and root then
    local home = character:GetPivot()
    character:PivotTo(CFrame.new(bed.Position.X, bed.Position.Y + bed.Size.Y / 2 + FEET_TO_ROOT + DROP_HEIGHT, bed.Position.Z))
    started = os.clock()
    while os.clock() - started < BOUNCE_SECONDS do
        local vertical = root.AssemblyLinearVelocity.Y
        if vertical > RISE_SPEED and not rising then
            rising = true
            bounces += 1
            local sound = root:FindFirstChild("Rebond")
            if sound and sound.IsPlaying then heard += 1 end
        elseif vertical < 0 then
            rising = false
        end
        task.wait()
    end
    character:PivotTo(home)
end
local rebond = root and root:FindFirstChild("Rebond")
check(("Rebond du trampoline repris par SoundController : son joue a %d rebonds sur %d, note %s, %d lecture(s)")
    :format(heard, bounces, tostring(rebond and rebond.PlaybackSpeed), plays(rebond) - rebondBefore),
    bounces >= 1 and heard == bounces and rebond ~= nil and near(rebond.PlaybackSpeed, BOUNCE_PITCH)
    and plays(rebond) - rebondBefore >= bounces)

table.insert(T.lines, ("[SFX CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
