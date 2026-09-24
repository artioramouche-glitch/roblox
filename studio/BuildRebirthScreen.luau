--!strict
--[[ BuildRebirthScreen
     Rôle    : créer l'écran de rebirth (A6 §7) dans StarterGui, en mode Édition, sans rien supprimer.
     Doc     : GAME_MASTER_V2 A6 §7, C3 ; PROMPT_EXECUTION_SABL_V4 §20, §31.9 lot E, Loi 7
     Étape   : 9, lot E
     Dépend  : StarterGui
     Exposé  : exécution manuelle dans Studio ; idempotent, aucun script de gameplay
     Limite  : coquille seule. Le coût, les gains et les pertes sont écrits par RebirthController à partir du
               profil reçu du serveur ; couleurs et gabarits repris de studio/BuildInventory.luau.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local MIN_TOUCH = 44 -- Loi 7
local TEXT_SMALL, TEXT_BODY, TEXT_TITLE = 16, 18, 24
local PANEL_WIDTH, PANEL_HEIGHT = 560, 440 -- tient en 720p paysage sans défilement (§20.1)
local CONFIRM_WIDTH = 240
local PANEL = Color3.fromRGB(30, 30, 38)
local BUTTON = Color3.fromRGB(70, 70, 88)
local LIGHT = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(150, 150, 160)
local ACCENT = Color3.fromRGB(255, 200, 50)
local LOSS = Color3.fromRGB(255, 120, 120)

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

local function label(parent: Instance, name: string, size: number, color: Color3): TextLabel
    local created = ensure(parent, "TextLabel", name) :: TextLabel
    created.BackgroundTransparency = 1
    created.Font = Enum.Font.Gotham
    created.TextSize = size
    created.TextColor3 = color
    created.TextXAlignment = Enum.TextXAlignment.Left
    created.RichText = false
    return created
end

local function touchButton(parent: Instance, name: string, text: string, width: number): TextButton
    local button = ensure(parent, "TextButton", name) :: TextButton
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = TEXT_SMALL
    button.TextColor3 = LIGHT
    button.BackgroundColor3 = BUTTON
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Size = UDim2.fromOffset(math.max(width, MIN_TOUCH), MIN_TOUCH)
    ensure(button, "UICorner", "UICorner")
    return button
end

local function makeScreen(name: string, order: number): ScreenGui
    local screen = ensure(StarterGui, "ScreenGui", name) :: ScreenGui
    screen.IgnoreGuiInset = true
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = order
    screen.Enabled = false -- §20.2.6
    local scale = ensure(screen, "UIScale", "UIScale") :: UIScale
    scale.Scale = 1
    local backdrop = ensure(screen, "Frame", "Backdrop") :: Frame
    backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
    backdrop.BackgroundTransparency = 0.45
    backdrop.BorderSizePixel = 0
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.ZIndex = 1
    return screen
end

local function makePanel(screen: ScreenGui, width: number, height: number, title: string): Frame
    local panel = ensure(screen, "Frame", "Panel") :: Frame
    panel.BackgroundColor3 = PANEL
    panel.BorderSizePixel = 0
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.fromOffset(width, height)
    panel.ZIndex = 2
    ensure(panel, "UICorner", "UICorner")
    local padding = ensure(panel, "UIPadding", "UIPadding") :: UIPadding
    padding.PaddingTop = UDim.new(0, 12)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 16)
    padding.PaddingRight = UDim.new(0, 16)
    local titleLabel = label(panel, "TitleLabel", TEXT_TITLE, LIGHT)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = title
    titleLabel.Size = UDim2.new(1, -MIN_TOUCH - 8, 0, 32)
    titleLabel.ZIndex = 3
    local close = touchButton(panel, "CloseButton", "X", MIN_TOUCH)
    close.AnchorPoint = Vector2.new(1, 0)
    close.Position = UDim2.fromScale(1, 0)
    close.ZIndex = 3
    return panel
end

-- Zones à hauteur fixe, du haut vers le bas : coût, gains, pertes, ce qui reste, puis la confirmation.
local function block(panel: Frame, name: string, y: number, height: number, size: number, color: Color3): TextLabel
    local created = label(panel, name, size, color)
    created.Position = UDim2.fromOffset(0, y)
    created.Size = UDim2.new(1, 0, 0, height)
    created.TextWrapped = true
    created.TextYAlignment = Enum.TextYAlignment.Top
    created.ZIndex = 3
    return created
end

-- ── Écran 7 : rebirth (A6 §7) ──────────────────────────────────────────────
local screen = makeScreen("RebirthScreen", 32)
local panel = makePanel(screen, PANEL_WIDTH, PANEL_HEIGHT, "♻️ Rebirth")
block(panel, "CostLabel", 44, 44, TEXT_BODY, LIGHT).Text = ""
local gainsTitle = block(panel, "GainsTitle", 92, 22, TEXT_SMALL, ACCENT)
gainsTitle.Font = Enum.Font.GothamBold
gainsTitle.Text = "Ce que tu gagnes"
block(panel, "GainsLabel", 114, 84, TEXT_SMALL, LIGHT).Text = ""
local lossesTitle = block(panel, "LossesTitle", 202, 22, TEXT_SMALL, LOSS)
lossesTitle.Font = Enum.Font.GothamBold
lossesTitle.Text = "Ce que tu perds"
block(panel, "LossesLabel", 224, 84, TEXT_SMALL, LIGHT).Text = ""
block(panel, "KeptLabel", 310, 40, TEXT_SMALL, DIM).Text =
    "Tu gardes tes brainrots (en Réserve d'or, utilisables en PvP), ton niveau, ton temps de jeu et tes stats."

local confirm = touchButton(panel, "ConfirmButton", "CONFIRMER LE REBIRTH", CONFIRM_WIDTH)
confirm.AnchorPoint = Vector2.new(0, 1)
confirm.Position = UDim2.fromScale(0, 1)
confirm.ZIndex = 3
local status = label(panel, "StatusLabel", TEXT_SMALL, ACCENT)
status.Text = ""
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, CONFIRM_WIDTH + 12, 1, 0)
status.Size = UDim2.new(1, -CONFIRM_WIDTH - 12, 0, MIN_TOUCH)
status.TextWrapped = true
status.ZIndex = 3

print(("[BUILD REBIRTH] Ecran de rebirth pret : panneau %dx%d, CONFIRMER %dx%d, texte minimal %dpx"):format(
    PANEL_WIDTH, PANEL_HEIGHT, CONFIRM_WIDTH, MIN_TOUCH, TEXT_SMALL))
