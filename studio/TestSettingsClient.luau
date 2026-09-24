--!nonstrict
--[[ TestSettingsClient
     Rôle    : vérifier l'écran Réglages (A6 §11) dans l'état où les clics réels l'ont laissé : roue et boutons
               tactiles, interrupteur conforme au profil reçu du serveur, sirène coupée quand les effets le sont.
     Doc     : GAME_MASTER_V2 A6 §11, G2 (Settings), A7 ; PROMPT_EXECUTION_SABL_V4 §20.1, Loi 2, Loi 7 ; décision 62
     Étape   : 10, lot A (suggestion du lot 0)
     Dépend  : Play en cours, datamodel Client ; Controllers.SettingsController et SoundController démarrés ;
               StarterGui.Settings (studio/BuildSettings.luau), Remotes.SyncProfile
     Exposé  : texte de bilan ; exécuté tel quel par l'outil dans le datamodel Client, entre des clics réels (roue,
               interrupteur), car l'outil ne peut pas require
     Limite  : l'alarme qui fait sonner la sirène est simulée en local (rien n'est envoyé au serveur), puis rétablie.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local MIN_TOUCH, MIN_TEXT = 44, 16 -- Loi 7, §20.1
local SNAPSHOT_WAIT = 3 -- s : le profil est renvoyé au client au moins une fois par seconde
local SETTLE_SECONDS = 0.4
local SIMULATED = {"AlarmVictimUserId", "AlarmCreatureId", "AlarmLevel"}

local T = {pass = 0, fail = 0, lines = {}}
local function check(name, ok)
    if ok then T.pass += 1 else T.fail += 1 end
    table.insert(T.lines, (ok and "[OK] " or "[FAIL] ") .. name)
end

local player = Players.LocalPlayer
local screen = player:WaitForChild("PlayerGui"):WaitForChild("Settings", 10)
local gear = screen and screen:FindFirstChild("SettingsButton")
local panel = screen and screen:FindFirstChild("Panel")
local viewport = workspace.CurrentCamera.ViewportSize
-- Le coin haut droit appartient à la liste des joueurs de Roblox : la roue se tient sous le panneau d'infos du HUD.
local info = player.PlayerGui:FindFirstChild("HUD") and player.PlayerGui.HUD:FindFirstChild("InfoPanel")
local below = info ~= nil and gear ~= nil and gear.AbsolutePosition.Y >= info.AbsolutePosition.Y + info.AbsoluteSize.Y
check(("Roue des reglages : %dx%d px, a gauche sous le panneau d'infos du HUD"):format(gear and gear.AbsoluteSize.X or 0,
    gear and gear.AbsoluteSize.Y or 0),
    gear ~= nil and gear.AbsoluteSize.X >= MIN_TOUCH and gear.AbsoluteSize.Y >= MIN_TOUCH and below
    and gear.AbsolutePosition.X < viewport.X / 2 and gear.AbsolutePosition.Y < viewport.Y / 2)

local open = panel ~= nil and panel.Visible
local toggle = panel and panel:FindFirstChild("SfxToggle")
if open then
    local small = 0
    for _, item in ipairs(panel:GetDescendants()) do
        if item:IsA("GuiButton") and (item.AbsoluteSize.X < MIN_TOUCH or item.AbsoluteSize.Y < MIN_TOUCH) then small += 1 end
        if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text ~= "" and item.TextSize < MIN_TEXT then
            small += 1
        end
    end
    check(("Panneau ouvert : %d element(s) sous 44 px ou 16 px ; musique « %s »"):format(small, panel.MusicLabel.Text),
        small == 0 and panel.MusicLabel.Text:find("bientôt", 1, true) ~= nil)
end

-- L'état affiché doit être celui du profil que le serveur renvoie (Loi 2).
local snapshot = nil
local connection = ReplicatedStorage.Remotes.SyncProfile.OnClientEvent:Connect(function(profile)
    if type(profile) == "table" then snapshot = profile end
end)
local deadline = os.clock() + SNAPSHOT_WAIT
while not snapshot and os.clock() < deadline do task.wait(0.1) end
connection:Disconnect()
local sfx = snapshot and snapshot.Settings and snapshot.Settings.SFX
local shown = toggle and toggle.Text or "?"
check(("Interrupteur « %s » conforme au profil du serveur (SFX = %s)"):format(shown, tostring(sfx)),
    type(sfx) == "boolean" and shown == (if sfx then "Activés" else "Coupés"))

-- Une alarme simulée en local : la sirène sonne seulement si les effets sonores sont activés.
local siren = SoundService:FindFirstChild("Sirene")
local saved = {}
for _, name in ipairs(SIMULATED) do saved[name] = player:GetAttribute(name) end
local before = siren and (siren:GetAttribute("Joues") or 0) or 0
player:SetAttribute("AlarmLevel", 0)
player:SetAttribute("AlarmVictimUserId", 1)
player:SetAttribute("AlarmCreatureId", "noobini")
player:SetAttribute("AlarmLevel", 1)
task.wait(SETTLE_SECONDS)
local after = siren and (siren:GetAttribute("Joues") or 0) or 0
for _, name in ipairs(SIMULATED) do player:SetAttribute(name, saved[name]) end
check(("Sirene %s pour une alarme (%d -> %d) : conforme au reglage"):format(if after > before then "jouee" else "muette",
    before, after), siren ~= nil and (if sfx then after == before + 1 else after == before))

table.insert(T.lines, ("[SETTINGS CLIENT TEST %s] %d OK / %d FAIL"):format(if open then "panneau ouvert" else "panneau ferme",
    T.pass, T.fail))
return table.concat(T.lines, "\n")
