--!strict
--[[ BuildHUD
     Rôle    : créer l'écran HUD dans StarterGui, en mode Édition, sans rien supprimer.
     Doc     : GAME_MASTER_V2 A6 §1 ; PROMPT_EXECUTION_SABL_V4 §20.1, §20.2, Loi 7
     Étape   : 3, lot C ; bouton ♻️ déverrouillé à l'étape 9, lot E (écran de rebirth)
     Dépend  : StarterGui
     Exposé  : exécution manuelle dans Studio ; idempotent, aucun script de gameplay
     Limite  : les couleurs ne sont pas spécifiées par le doc ; choix sobre déclaré.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local BUTTON_SIZE = 72 -- > 44 px exigés par la Loi 7, avant tout UIScale (jamais < 1)
local ICON_TEXT_SIZE = 26
local CAPTION_TEXT_SIZE = 16 -- minimum absolu du §20.1
local MONEY_TEXT_SIZE = 28
local INFO_TEXT_SIZE = 18
local DARK = Color3.fromRGB(18, 18, 24)
local LIGHT = Color3.fromRGB(255, 255, 255)
local DIM = Color3.fromRGB(150, 150, 160)

-- A6 §1 : l'ordre des six boutons est celui du document.
local BUTTONS = {
    {name = "EggsButton", icon = "🥚", caption = "Œufs", locked = false},
    {name = "BaseButton", icon = "🏠", caption = "Base", locked = false},
    {name = "InventoryButton", icon = "📦", caption = "Sac", locked = false},
    {name = "QuestsButton", icon = "📜", caption = "Quêtes", locked = true},
    {name = "RebirthButton", icon = "♻️", caption = "Rebirth", locked = false},
    {name = "ArenaButton", icon = "⚔️", caption = "Arène", locked = true},
}

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

local hud = ensure(StarterGui, "ScreenGui", "HUD") :: ScreenGui
hud.IgnoreGuiInset = true -- §20.2.1 : l'encoche est gérée par le controller
hud.ResetOnSpawn = false
hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hud.DisplayOrder = 10
hud.Enabled = true

local scale = ensure(hud, "UIScale", "UIScale") :: UIScale
scale.Scale = 1 -- §20.2.2 : ajusté au runtime, jamais sous 1

-- Bloc d'informations : en haut, hors des zones de pouce (§20.2.4).
local infoPanel = ensure(hud, "Frame", "InfoPanel") :: Frame
infoPanel.BackgroundColor3 = DARK
infoPanel.BackgroundTransparency = 0.25
infoPanel.BorderSizePixel = 0
infoPanel.Position = UDim2.fromOffset(16, 16)
infoPanel.Size = UDim2.fromOffset(240, 104)
ensure(infoPanel, "UICorner", "UICorner")
local infoPadding = ensure(infoPanel, "UIPadding", "UIPadding") :: UIPadding
infoPadding.PaddingTop = UDim.new(0, 8)
infoPadding.PaddingBottom = UDim.new(0, 8)
infoPadding.PaddingLeft = UDim.new(0, 12)
infoPadding.PaddingRight = UDim.new(0, 12)
local infoLayout = ensure(infoPanel, "UIListLayout", "UIListLayout") :: UIListLayout
infoLayout.FillDirection = Enum.FillDirection.Vertical
infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
infoLayout.Padding = UDim.new(0, 4)

local function makeInfoLabel(name: string, order: number, size: number, color: Color3): TextLabel
    local label = ensure(infoPanel, "TextLabel", name) :: TextLabel
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, size + 8)
    label.LayoutOrder = order
    label.Font = Enum.Font.GothamBold
    label.TextSize = size
    label.TextColor3 = color
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.RichText = false
    return label
end

local moneyLabel = makeInfoLabel("MoneyLabel", 1, MONEY_TEXT_SIZE, LIGHT)
moneyLabel.Text = "💰 0"
local incomeLabel = makeInfoLabel("IncomeLabel", 2, INFO_TEXT_SIZE, LIGHT)
incomeLabel.Text = "0/s"
local shieldLabel = makeInfoLabel("ShieldLabel", 3, INFO_TEXT_SIZE, DIM)
shieldLabel.Text = "🛡️ —"

-- Barre de boutons : en bas, atteignable au pouce (§20.2.4).
local buttonBar = ensure(hud, "Frame", "ButtonBar") :: Frame
buttonBar.BackgroundTransparency = 1
buttonBar.AnchorPoint = Vector2.new(0.5, 1)
buttonBar.Position = UDim2.new(0.5, 0, 1, -16)
buttonBar.Size = UDim2.fromOffset(#BUTTONS * BUTTON_SIZE + (#BUTTONS - 1) * 8, BUTTON_SIZE)
local barLayout = ensure(buttonBar, "UIListLayout", "UIListLayout") :: UIListLayout
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, 8)

for order, spec in ipairs(BUTTONS) do
    local button = ensure(buttonBar, "TextButton", spec.name) :: TextButton
    button.Text = ""
    button.LayoutOrder = order
    button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
    button.BackgroundColor3 = DARK
    button.BackgroundTransparency = 0.1
    button.BorderSizePixel = 0
    button.AutoButtonColor = not spec.locked
    button.Active = not spec.locked
    button:SetAttribute("Locked", spec.locked)
    ensure(button, "UICorner", "UICorner")
    local ratio = ensure(button, "UIAspectRatioConstraint", "UIAspectRatioConstraint") :: UIAspectRatioConstraint
    ratio.AspectRatio = 1 -- §20.2.3 : les boutons restent carrés

    local icon = ensure(button, "TextLabel", "Icon") :: TextLabel
    icon.BackgroundTransparency = 1
    icon.Position = UDim2.fromScale(0, 0.06)
    icon.Size = UDim2.new(1, 0, 0.52, 0)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = ICON_TEXT_SIZE
    icon.Text = spec.icon
    icon.TextColor3 = spec.locked and DIM or LIGHT

    local caption = ensure(button, "TextLabel", "Caption") :: TextLabel
    caption.BackgroundTransparency = 1
    caption.Position = UDim2.fromScale(0, 0.58)
    caption.Size = UDim2.new(1, 0, 0.36, 0)
    caption.Font = Enum.Font.Gotham
    caption.TextSize = CAPTION_TEXT_SIZE
    caption.Text = spec.caption
    caption.TextColor3 = spec.locked and DIM or LIGHT
    caption.TextTruncate = Enum.TextTruncate.AtEnd
end

print(("[BUILD HUD] HUD pret : %d boutons de %dpx, texte minimal %dpx"):format(
    #BUTTONS, BUTTON_SIZE, CAPTION_TEXT_SIZE))
