--!strict
--[[ BuildInventory
     Rôle    : créer l'écran d'inventaire et le panneau de base dans StarterGui.
     Doc     : GAME_MASTER_V2 A6 §3-4, A5 ; PROMPT_EXECUTION_SABL_V4 §20, Loi 7
     Étape   : 4, lot D ; lignes achetables du panneau de base à l'étape 9, lot B
     Dépend  : StarterGui
     Exposé  : exécution manuelle dans Studio ; idempotent, aucun script de gameplay
     Limite  : coquilles seules. Les cartes de créatures sont clonées du modèle par
               InventoryController à partir du profil reçu du serveur.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local MIN_TOUCH = 44 -- Loi 7
local TEXT_SMALL, TEXT_BODY, TEXT_TITLE = 16, 18, 24
local CARD_SIZE = 136
local PANEL = Color3.fromRGB(30, 30, 38)
local CARD = Color3.fromRGB(42, 42, 52)
local BUTTON = Color3.fromRGB(70, 70, 88)
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

-- ── Écran 3 : inventaire (A6 §3) ────────────────────────────────────────────
local inventory = makeScreen("Inventory", 30)
local panel = makePanel(inventory, 700, 470, "Inventaire")

local sortBar = ensure(panel, "Frame", "SortBar") :: Frame
sortBar.BackgroundTransparency = 1
sortBar.Position = UDim2.fromOffset(0, 40)
sortBar.Size = UDim2.new(1, 0, 0, MIN_TOUCH)
sortBar.ZIndex = 3
local sortLayout = ensure(sortBar, "UIListLayout", "UIListLayout") :: UIListLayout
sortLayout.FillDirection = Enum.FillDirection.Horizontal
sortLayout.SortOrder = Enum.SortOrder.LayoutOrder
sortLayout.Padding = UDim.new(0, 8)
-- A6 §3 : tri par revenu OU par stats PvP.
local sortIncome = touchButton(sortBar, "SortIncomeButton", "Revenu", 120)
sortIncome.LayoutOrder = 1
sortIncome.ZIndex = 3
local sortPvp = touchButton(sortBar, "SortPvpButton", "Stats PvP", 120)
sortPvp.LayoutOrder = 2
sortPvp.ZIndex = 3

local status = label(panel, "StatusLabel", TEXT_SMALL, ACCENT)
status.Text = ""
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, 0, 0, 52)
status.Size = UDim2.new(0.55, 0, 0, 24)
status.TextXAlignment = Enum.TextXAlignment.Right
status.ZIndex = 3

local grid = ensure(panel, "ScrollingFrame", "Grid") :: ScrollingFrame
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.Position = UDim2.fromOffset(0, 92)
grid.Size = UDim2.new(1, 0, 1, -92 - MIN_TOUCH - 12)
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollBarThickness = 6
grid.ZIndex = 3
local gridLayout = ensure(grid, "UIGridLayout", "UIGridLayout") :: UIGridLayout
gridLayout.CellSize = UDim2.fromOffset(CARD_SIZE, 96)
gridLayout.CellPadding = UDim2.fromOffset(8, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

local actionBar = ensure(panel, "Frame", "ActionBar") :: Frame
actionBar.BackgroundTransparency = 1
actionBar.AnchorPoint = Vector2.new(0, 1)
actionBar.Position = UDim2.fromScale(0, 1)
actionBar.Size = UDim2.new(1, 0, 0, MIN_TOUCH)
actionBar.ZIndex = 3
local actionLayout = ensure(actionBar, "UIListLayout", "UIListLayout") :: UIListLayout
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Padding = UDim.new(0, 8)
for order, spec in ipairs({
    {name = "PlaceButton", text = "Placer", locked = false},
    {name = "SellButton", text = "Vendre", locked = false},
    {name = "FuseButton", text = "Fusionner", locked = false},
    {name = "EngageButton", text = "Engager", locked = true},
}) do
    local button = touchButton(actionBar, spec.name, spec.text, 130)
    button.LayoutOrder = order
    button.ZIndex = 3
    button:SetAttribute("Locked", spec.locked)
    button.AutoButtonColor = not spec.locked
    button.TextColor3 = spec.locked and DIM or LIGHT
end

-- Modèle de carte : une créature de l'inventaire.
local template = ensure(inventory, "Frame", "CardTemplate") :: Frame
template.Visible = false
template.BackgroundColor3 = CARD
template.BorderSizePixel = 0
template.Size = UDim2.fromOffset(CARD_SIZE, 96)
template.ZIndex = 3
ensure(template, "UICorner", "UICorner")
local cardPadding = ensure(template, "UIPadding", "UIPadding") :: UIPadding
cardPadding.PaddingTop = UDim.new(0, 6)
cardPadding.PaddingBottom = UDim.new(0, 6)
cardPadding.PaddingLeft = UDim.new(0, 8)
cardPadding.PaddingRight = UDim.new(0, 8)
-- Le contour matérialise la sélection et le surlignage des duplicatas (A6 §3).
local stroke = ensure(template, "UIStroke", "UIStroke") :: UIStroke
stroke.Thickness = 2
stroke.Transparency = 1
stroke.Color = ACCENT
local cardName = label(template, "NameLabel", TEXT_SMALL, LIGHT)
cardName.Font = Enum.Font.GothamBold
cardName.Size = UDim2.new(1, 0, 0, 34)
cardName.TextWrapped = true
cardName.TextYAlignment = Enum.TextYAlignment.Top
cardName.ZIndex = 4
local cardTier = label(template, "TierLabel", TEXT_SMALL, DIM)
cardTier.Position = UDim2.fromOffset(0, 36)
cardTier.Size = UDim2.new(1, 0, 0, 20)
cardTier.ZIndex = 4
local cardStat = label(template, "StatLabel", TEXT_SMALL, ACCENT)
cardStat.Position = UDim2.fromOffset(0, 56)
cardStat.Size = UDim2.new(1, 0, 0, 20)
cardStat.ZIndex = 4
-- Le bouton couvre la carte : toute la tuile est tactile (Loi 7).
local selectButton = ensure(template, "TextButton", "SelectButton") :: TextButton
selectButton.Text = ""
selectButton.BackgroundTransparency = 1
selectButton.Size = UDim2.fromScale(1, 1)
selectButton.ZIndex = 5

-- ── Écran 4 : gestion de base (A6 §4) : achats des composants depuis l'étape 9 ─
local base = makeScreen("BasePanel", 31)
local basePanel = makePanel(base, 520, 380, "Ma base")
local summary = label(basePanel, "SummaryLabel", TEXT_BODY, LIGHT)
summary.Text = "" -- rempli par le controller au premier profil reçu
summary.Position = UDim2.fromOffset(0, 44)
summary.Size = UDim2.new(1, 0, 0, 52)
summary.TextWrapped = true
summary.TextYAlignment = Enum.TextYAlignment.Top
summary.ZIndex = 3
local baseStatus = label(basePanel, "StatusLabel", TEXT_SMALL, ACCENT)
baseStatus.Text = ""
baseStatus.Position = UDim2.fromOffset(0, 98)
baseStatus.Size = UDim2.new(1, 0, 0, 20)
baseStatus.ZIndex = 3
local componentList = ensure(basePanel, "ScrollingFrame", "ComponentList") :: ScrollingFrame
componentList.BackgroundTransparency = 1
componentList.BorderSizePixel = 0
componentList.Position = UDim2.fromOffset(0, 122)
componentList.Size = UDim2.new(1, 0, 1, -122)
componentList.CanvasSize = UDim2.new()
componentList.AutomaticCanvasSize = Enum.AutomaticSize.Y
componentList.ScrollBarThickness = 6
componentList.ZIndex = 3
local componentLayout = ensure(componentList, "UIListLayout", "UIListLayout") :: UIListLayout
componentLayout.FillDirection = Enum.FillDirection.Vertical
componentLayout.SortOrder = Enum.SortOrder.LayoutOrder
componentLayout.Padding = UDim.new(0, 4)
-- Étape 9 : une ligne = un libellé et un bouton d'achat ; l'ancien modèle texte seul est remplacé.
local oldRow = base:FindFirstChild("RowTemplate")
if oldRow and not oldRow:IsA("Frame") then oldRow:Destroy() end
local rowTemplate = ensure(base, "Frame", "RowTemplate") :: Frame
rowTemplate.Visible = false
rowTemplate.BackgroundColor3 = CARD
rowTemplate.BorderSizePixel = 0
rowTemplate.Size = UDim2.new(1, -8, 0, MIN_TOUCH + 4)
rowTemplate.ZIndex = 4
ensure(rowTemplate, "UICorner", "UICorner")
local rowLabel = label(rowTemplate, "Label", TEXT_SMALL, LIGHT)
rowLabel.Text = ""
rowLabel.Position = UDim2.fromOffset(8, 0)
rowLabel.Size = UDim2.new(1, -144, 1, 0)
rowLabel.TextWrapped = true
rowLabel.ZIndex = 5
local buyButton = touchButton(rowTemplate, "BuyButton", "AMÉLIORER", 124)
buyButton.AnchorPoint = Vector2.new(1, 0.5)
buyButton.Position = UDim2.new(1, -4, 0.5, 0)
buyButton.BackgroundColor3 = Color3.fromRGB(46, 160, 67)
buyButton.ZIndex = 5

print(("[BUILD INVENTORY] Inventory et BasePanel prets ; carte %dpx, touche minimale %dpx")
    :format(CARD_SIZE, MIN_TOUCH))
