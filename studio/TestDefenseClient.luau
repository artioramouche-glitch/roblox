--!nonstrict
--[[ TestDefenseClient
     Rôle    : vérifier côté client l'alarme (bandeau, traqueur), le bandeau de la tourelle, et ce que les défenses
               dessinent côté serveur : tête tournée, gouttes soudées, surlignage visible à travers les murs.
     Doc     : GAME_MASTER_V2 A5, A6 §5 ; PROMPT_EXECUTION_SABL_V4 §20.1, §25 ; décisions 42 et 43
     Étape   : 9, lot F3
     Dépend  : Play en cours, datamodel Client, lancé dans les 45 s qui suivent studio/FixtureDefenseVisuals.luau ;
               Controllers.NotificationController et StealAlertController démarrés ; StarterGui.Notifications et
               StealStatus.AlarmTracker (studio/BuildStealAlert.luau)
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, car l'outil ne peut pas require
     Limite  : l'alarme et le bandeau de la tourelle sont simulés en local sur le client (rien n'est envoyé au
               serveur), puis les attributs d'origine sont rétablis. Seul sur le serveur, le joueur ne peut être que
               le voleur : le traqueur vu par un autre joueur se prouvera à la poursuite à 2 joueurs.
]]
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MIN_TEXT = 16 -- §20.1
local GLUE_DROPS = 5 -- Base.DefenseVisual
local HELD_DISTANCE = 4 -- studs : une goutte soudée reste contre le personnage
local AIM_TOLERANCE = 3 -- degrés
local SETTLE_SECONDS = 0.4 -- laissé aux controllers pour réagir et rendre une image
local SIMULATED = {"AlarmVictimUserId", "AlarmCreatureId", "AlarmLevel", "DefenseDropCreatureId",
    "DefenseDropThiefName", "DefenseDropAt"}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local label = gui:WaitForChild("Notifications"):WaitForChild("Toast"):WaitForChild("ToastLabel")
local tracker = gui:WaitForChild("StealStatus"):FindFirstChild("AlarmTracker")
check(("Traqueur d'alarme construit : fleche en barres, nom en %d px, masque sans alarme")
    :format(tracker and tracker.ThiefLabel.TextSize or 0),
    tracker ~= nil and tracker.Visible == false and tracker.ThiefLabel.TextSize >= MIN_TEXT
    and tracker.Arrow:FindFirstChild("Stem") ~= nil and tracker.Arrow:FindFirstChild("Left") ~= nil)

-- Simulation locale : le joueur vole un brainrot chez un joueur absent, dont l'alarme est au niveau 3.
local saved = {}
for _, name in ipairs(SIMULATED) do saved[name] = player:GetAttribute(name) end
player:SetAttribute("AlarmVictimUserId", 1)
player:SetAttribute("AlarmCreatureId", "noobini")
player:SetAttribute("AlarmLevel", 3)
task.wait(SETTLE_SECONDS)
local thiefToast = label.Text
local trackerShown = tracker ~= nil and tracker.Visible
player:SetAttribute("AlarmLevel", 0)
check(("Alarme (simulation locale, le joueur est le voleur) : « %s »"):format(thiefToast),
    thiefToast == "🚨 Une alarme a sonné : tout le serveur sait que tu voles Noobini Pizzanini !")
check("Le voleur n'a pas de traqueur pointe vers lui-meme", trackerShown == false)

-- Simulation locale : la tourelle du joueur a fait lâcher son voleur.
player:SetAttribute("DefenseDropCreatureId", "noobini")
player:SetAttribute("DefenseDropThiefName", "Voleur")
player:SetAttribute("DefenseDropAt", Workspace:GetServerTimeNow())
task.wait(SETTLE_SECONDS)
local dropToast = label.Text
check(("Tourelle (simulation locale) : « %s »"):format(dropToast),
    dropToast == "🛡️ Ta tourelle a fait lâcher Noobini Pizzanini à Voleur !")
for _, name in ipairs(SIMULATED) do player:SetAttribute(name, saved[name]) end

-- Ce que studio/FixtureDefenseVisuals.luau a posé côté serveur, reçu ici par réplication.
local character = player.Character
local root = character and character:FindFirstChild("HumanoidRootPart")
local highlight = character and character:FindFirstChild("AlarmeSurlignage")
check("Alarme niv. 2 : surlignage recu du serveur, visible a travers les murs",
    highlight ~= nil and highlight:IsA("Highlight") and highlight.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop)
local glue = character and character:FindFirstChild("Colle")
local held = 0
for _, drop in ipairs(glue and glue:GetChildren() or {}) do
    if drop:IsA("BasePart") and root and (drop.Position - root.Position).Magnitude < HELD_DISTANCE then held += 1 end
end
check(("Gouttes de colle recues du serveur, collees au personnage : %d / %d"):format(held, GLUE_DROPS),
    held == GLUE_DROPS)

-- La tourelle la plus proche du point visé, et l'angle entre son canon et ce point, vus du client.
local target = Workspace:GetAttribute("SABL_AimTarget")
local head, barrel, best = nil, nil, math.huge
if typeof(target) == "Vector3" then
    for _, defenses in ipairs(Workspace:GetDescendants()) do
        local turret = defenses.Name == "Defenses" and defenses:FindFirstChild("PROP_turret")
        if turret and turret:FindFirstChild("Tete") and turret:FindFirstChild("Canon") then
            local distance = (turret.Tete.Position - target).Magnitude
            if distance < best then head, barrel, best = turret.Tete, turret.Canon, distance end
        end
    end
end
local angle = nil
if head then
    local pointing = (barrel.Position - head.Position) * Vector3.new(1, 0, 1)
    local wanted = (target - head.Position) * Vector3.new(1, 0, 1)
    angle = math.deg(math.acos(math.clamp(pointing.Unit:Dot(wanted.Unit), -1, 1)))
end
check(("Tourelle : tete tournee vers le point vise par le serveur (ecart %s deg)"):format(
    angle and ("%.1f"):format(angle) or "?"), angle ~= nil and angle <= AIM_TOLERANCE)

table.insert(T.lines, ("[DEFENSE CLIENT TEST] %d OK / %d FAIL"):format(T.pass, T.fail))
return table.concat(T.lines, "\n")
