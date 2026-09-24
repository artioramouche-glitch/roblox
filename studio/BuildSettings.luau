--!strict
--[[ BuildSettings
     Rôle    : créer l'écran Réglages (A6 §11) dans StarterGui, en mode Édition, sans rien supprimer : la roue dentée
               qui l'ouvre et le panneau avec l'interrupteur des effets sonores.
     Doc     : GAME_MASTER_V2 A6 §11, G2 (Settings) ; PROMPT_EXECUTION_SABL_V4 §20.1, §20.2, Loi 7 ; suggestion du lot 0
               de l'étape 10
     Étape   : 10, lot A
     Dépend  : StarterGui
     Exposé  : exécution manuelle en Édition ; idempotent ; StarterGui.Settings (SettingsButton, Panel)
     Limite  : coquille seule : SettingsController ouvre le panneau et envoie le réglage au serveur. La musique
               n'existe pas encore : sa ligne dit « bientôt ». Codes et qualité (A6 §11) viendront avec leurs étapes.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local GEAR = 52 -- côté de la roue dentée, > 44 px exigés par la Loi 7
-- Sous le panneau d'infos du HUD (74 + 104 px + 8, recopiés de studio/BuildHUD.luau) : le coin haut droit est pris
-- par la liste des joueurs de Roblox, et à droite du panneau le bandeau d'information la couvrirait.
local GEAR_LEFT, GEAR_TOP = 16, 186
local PANEL = Vector2.new(380, 236)
local TOGGLE = Vector2.new(140, 48)
local TITLE_TEXT, BODY_TEXT, SMALL_TEXT = 24, 18, 16 -- §20.1 : au moins 16 px
local DARK = Color3.fromRGB(30, 30, 38)
local LIGHT = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(150, 150, 160)
local ACCENT = Color3.fromRGB(255, 200, 50)

local function ensure(parent: Instance, className: string, name: string): Instance
    local existing = parent:FindFirstChild(name)
    if existing then
        assert(existing.ClassName == className,
            ("%s existe avec la classe %s"):format(existing:GetFullName(), existing.ClassName))
        return existing
    end
    local created = Instance.new(className)
    created.Name = name
    created.Parent = parent
    return created
end

local function label(parent: Instance, name: string, size: number, color: Color3, text: string): TextLabel
    local item = ensure(parent, "TextLabel", name) :: TextLabel
    item.BackgroundTransparency = 1
    item.Font = Enum.Font.GothamBold
    item.TextSize = size
    item.TextColor3 = color
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.Text = text
    return item
end

local function button(parent: Instance, name: string, size: Vector2, text: string): TextButton
    local item = ensure(parent, "TextButton", name) :: TextButton
    item.Size = UDim2.fromOffset(size.X, size.Y) -- pixels fixes : mesurables comme au §20.4
    item.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    item.BorderSizePixel = 0
    item.AutoButtonColor = true
    item.Font = Enum.Font.GothamBold
    item.TextSize = BODY_TEXT
    item.TextColor3 = LIGHT
    item.Text = text
    ensure(item, "UICorner", "UICorner")
    return item
end

local screen = ensure(StarterGui, "ScreenGui", "Settings") :: ScreenGui
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 35 -- au-dessus des écrans du jeu (30 à 32), sous le bandeau d'information (40)
screen.Enabled = true
local scale = ensure(screen, "UIScale", "UIScale") :: UIScale
scale.Scale = 1 -- §20.2.2 : ajusté au runtime, jamais sous 1

-- Roue dentée à gauche, sous le panneau d'infos du HUD : toujours visible, elle ouvre et ferme le panneau.
local gear = button(screen, "SettingsButton", Vector2.new(GEAR, GEAR), "⚙️")
gear.AnchorPoint = Vector2.new(0, 0)
gear.Position = UDim2.fromOffset(GEAR_LEFT, GEAR_TOP)
gear.BackgroundTransparency = 0.15
gear.TextSize = TITLE_TEXT

local panel = ensure(screen, "Frame", "Panel") :: Frame
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(PANEL.X, PANEL.Y)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
ensure(panel, "UICorner", "UICorner")
local stroke = ensure(panel, "UIStroke", "UIStroke") :: UIStroke
stroke.Color = ACCENT
stroke.Thickness = 2

local title = label(panel, "Title", TITLE_TEXT, LIGHT, "Réglages")
title.Position = UDim2.fromOffset(20, 14)
title.Size = UDim2.new(1, -40, 0, TITLE_TEXT + 8)

local sfxLabel = label(panel, "SfxLabel", BODY_TEXT, LIGHT, "Effets sonores")
sfxLabel.Position = UDim2.fromOffset(20, 70)
sfxLabel.Size = UDim2.new(1, -(TOGGLE.X + 60), 0, TOGGLE.Y)
local sfxToggle = button(panel, "SfxToggle", TOGGLE, "Activés")
sfxToggle.AnchorPoint = Vector2.new(1, 0)
sfxToggle.Position = UDim2.new(1, -20, 0, 70)

local music = label(panel, "MusicLabel", SMALL_TEXT, DIM, "Musique : bientôt")
music.Position = UDim2.fromOffset(20, 128)
music.Size = UDim2.new(1, -40, 0, SMALL_TEXT + 8)

local status = label(panel, "StatusLabel", SMALL_TEXT, ACCENT, "")
status.Position = UDim2.fromOffset(20, 160)
status.Size = UDim2.new(1, -(TOGGLE.X + 60), 0, SMALL_TEXT + 8)

local close = button(panel, "CloseButton", TOGGLE, "Fermer")
close.AnchorPoint = Vector2.new(1, 1)
close.Position = UDim2.new(1, -20, 1, -16)

print(("[BUILD SETTINGS] Reglages prets : roue %dx%d sous le panneau d'infos, panneau %dx%d, boutons %dx%d, texte minimal %dpx")
    :format(GEAR, GEAR, PANEL.X, PANEL.Y, TOGGLE.X, TOGGLE.Y, SMALL_TEXT))
