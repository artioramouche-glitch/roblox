--!strict
--[[ BuildEggShop
     Rôle    : créer l'écran de boutique d'œufs dans StarterGui, en mode Édition.
     Doc     : GAME_MASTER_V2 A6 §2, B2 ; PROMPT_EXECUTION_SABL_V4 §20, §24, Loi 7
     Étape   : 3, lot D
     Dépend  : StarterGui
     Exposé  : exécution manuelle dans Studio ; idempotent, aucun script de gameplay
     Limite  : la coquille seule ; les cartes d'œufs sont clonées du modèle par
               EggShopController à partir d'EggConfig, jamais écrites en dur ici.
]]
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Construction autorisée uniquement en mode Édition")
local StarterGui = game:GetService("StarterGui")

local MIN_TOUCH = 44 -- Loi 7
local TEXT_SMALL = 16
local TEXT_BODY = 18
local TEXT_TITLE = 24
local DARK = Color3.fromRGB(18, 18, 24)
local PANEL = Color3.fromRGB(30, 30, 38)
local CARD = Color3.fromRGB(42, 42, 52)
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
    button.BackgroundColor3 = CARD
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Size = UDim2.fromOffset(math.max(width, MIN_TOUCH), MIN_TOUCH)
    ensure(button, "UICorner", "UICorner")
    return button
end

local shop = ensure(StarterGui, "ScreenGui", "EggShop") :: ScreenGui
shop.IgnoreGuiInset = true
shop.ResetOnSpawn = false
shop.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
shop.DisplayOrder = 20
shop.Enabled = false -- §20.2.6 : écran activé/désactivé, jamais reconstruit

local scale = ensure(shop, "UIScale", "UIScale") :: UIScale
scale.Scale = 1

local backdrop = ensure(shop, "Frame", "Backdrop") :: Frame
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.ZIndex = 1

local panel = ensure(shop, "Frame", "Panel") :: Frame
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(660, 430)
panel.ZIndex = 2
ensure(panel, "UICorner", "UICorner")
local panelPadding = ensure(panel, "UIPadding", "UIPadding") :: UIPadding
panelPadding.PaddingTop = UDim.new(0, 12)
panelPadding.PaddingBottom = UDim.new(0, 12)
panelPadding.PaddingLeft = UDim.new(0, 16)
panelPadding.PaddingRight = UDim.new(0, 16)

local title = label(panel, "TitleLabel", TEXT_TITLE, LIGHT)
title.Font = Enum.Font.GothamBold
title.Text = "Boutique d'œufs"
title.Size = UDim2.new(1, -MIN_TOUCH - 8, 0, 32)
title.ZIndex = 3

local close = touchButton(panel, "CloseButton", "X", MIN_TOUCH)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.fromScale(1, 0)
close.ZIndex = 3

-- Rappel de conformité : la mention des probabilités est exigée par §24.
local notice = label(panel, "NoticeLabel", TEXT_SMALL, DIM)
notice.Text = "Probabilités d'obtention affichées pour chaque œuf."
notice.Position = UDim2.fromOffset(0, 36)
notice.Size = UDim2.new(1, 0, 0, 20)
notice.ZIndex = 3

local tabBar = ensure(panel, "Frame", "TabBar") :: Frame
tabBar.BackgroundTransparency = 1
tabBar.Position = UDim2.fromOffset(0, 62)
tabBar.Size = UDim2.new(1, 0, 0, MIN_TOUCH)
tabBar.ZIndex = 3
local tabLayout = ensure(tabBar, "UIListLayout", "UIListLayout") :: UIListLayout
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 8)
for world = 1, 4 do
    local tab = touchButton(tabBar, ("World%dButton"):format(world), "Monde " .. world, 96)
    tab.LayoutOrder = world
    tab.ZIndex = 3
end

local list = ensure(panel, "ScrollingFrame", "EggList") :: ScrollingFrame
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(0, 114)
list.Size = UDim2.new(1, 0, 1, -114)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.ScrollBarThickness = 6
list.ZIndex = 3
local listLayout = ensure(list, "UIListLayout", "UIListLayout") :: UIListLayout
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)

-- Modèle de carte : cloné une fois par œuf par le controller, jamais rempli ici.
local template = ensure(shop, "Frame", "CardTemplate") :: Frame
template.Visible = false
template.BackgroundColor3 = CARD
template.BorderSizePixel = 0
template.Size = UDim2.new(1, -8, 0, 108)
template.ZIndex = 3
ensure(template, "UICorner", "UICorner")
local cardPadding = ensure(template, "UIPadding", "UIPadding") :: UIPadding
cardPadding.PaddingTop = UDim.new(0, 8)
cardPadding.PaddingBottom = UDim.new(0, 8)
cardPadding.PaddingLeft = UDim.new(0, 12)
cardPadding.PaddingRight = UDim.new(0, 12)

local cardName = label(template, "NameLabel", TEXT_BODY, LIGHT)
cardName.Font = Enum.Font.GothamBold
cardName.Size = UDim2.new(0.6, 0, 0, 22)
cardName.ZIndex = 4
local cardPrice = label(template, "PriceLabel", TEXT_BODY, ACCENT)
cardPrice.Font = Enum.Font.GothamBold
cardPrice.TextXAlignment = Enum.TextXAlignment.Right
cardPrice.AnchorPoint = Vector2.new(1, 0)
cardPrice.Position = UDim2.fromScale(1, 0)
cardPrice.Size = UDim2.new(0.4, 0, 0, 22)
cardPrice.ZIndex = 4
local cardOdds = label(template, "OddsLabel", TEXT_SMALL, DIM)
cardOdds.Position = UDim2.fromOffset(0, 26)
cardOdds.Size = UDim2.new(1, 0, 0, 20)
cardOdds.TextTruncate = Enum.TextTruncate.AtEnd
cardOdds.ZIndex = 4
local cardState = label(template, "StateLabel", TEXT_SMALL, DIM)
cardState.Position = UDim2.fromOffset(0, 46)
cardState.Size = UDim2.new(1, 0, 0, 18)
cardState.Text = ""
cardState.ZIndex = 4

local buyRow = ensure(template, "Frame", "BuyRow") :: Frame
buyRow.BackgroundTransparency = 1
buyRow.AnchorPoint = Vector2.new(0, 1)
buyRow.Position = UDim2.fromScale(0, 1)
buyRow.Size = UDim2.new(1, 0, 0, MIN_TOUCH)
buyRow.ZIndex = 4
local buyLayout = ensure(buyRow, "UIListLayout", "UIListLayout") :: UIListLayout
buyLayout.FillDirection = Enum.FillDirection.Horizontal
buyLayout.SortOrder = Enum.SortOrder.LayoutOrder
buyLayout.Padding = UDim.new(0, 8)
for order, quantity in ipairs({1, 10, 50}) do
    local button = touchButton(buyRow, ("Buy%dButton"):format(quantity), "×" .. quantity, 88)
    button.LayoutOrder = order
    button.ZIndex = 4
    -- Fond plus clair que la carte : sans cela le bouton se confond avec elle (§20.2.5).
    button.BackgroundColor3 = Color3.fromRGB(70, 70, 88)
end

-- Panneau de révélation : le serveur a déjà décidé, le client rejoue (Loi 2).
local result = ensure(shop, "Frame", "ResultPanel") :: Frame
result.Visible = false
result.BackgroundColor3 = DARK
result.BorderSizePixel = 0
result.AnchorPoint = Vector2.new(0.5, 0.5)
result.Position = UDim2.fromScale(0.5, 0.5)
result.Size = UDim2.fromOffset(420, 360)
result.ZIndex = 10
ensure(result, "UICorner", "UICorner")
local resultPadding = ensure(result, "UIPadding", "UIPadding") :: UIPadding
resultPadding.PaddingTop = UDim.new(0, 12)
resultPadding.PaddingBottom = UDim.new(0, 12)
resultPadding.PaddingLeft = UDim.new(0, 16)
resultPadding.PaddingRight = UDim.new(0, 16)

local resultTitle = label(result, "ResultTitle", TEXT_TITLE, LIGHT)
resultTitle.Font = Enum.Font.GothamBold
resultTitle.Text = "Ouverture"
resultTitle.Size = UDim2.new(1, 0, 0, 30)
resultTitle.ZIndex = 11

local resultList = ensure(result, "ScrollingFrame", "ResultList") :: ScrollingFrame
resultList.BackgroundTransparency = 1
resultList.BorderSizePixel = 0
resultList.Position = UDim2.fromOffset(0, 36)
resultList.Size = UDim2.new(1, 0, 1, -36 - MIN_TOUCH - 8)
resultList.CanvasSize = UDim2.new()
resultList.AutomaticCanvasSize = Enum.AutomaticSize.Y
resultList.ScrollBarThickness = 6
resultList.ZIndex = 11
local resultLayout = ensure(resultList, "UIListLayout", "UIListLayout") :: UIListLayout
resultLayout.FillDirection = Enum.FillDirection.Vertical
resultLayout.SortOrder = Enum.SortOrder.LayoutOrder
resultLayout.Padding = UDim.new(0, 4)

local resultLine = label(shop, "ResultLineTemplate", TEXT_BODY, LIGHT)
resultLine.Visible = false
resultLine.Size = UDim2.new(1, -8, 0, 24)
resultLine.ZIndex = 11

local skip = touchButton(result, "SkipButton", "Passer", 140)
skip.AnchorPoint = Vector2.new(0.5, 1)
skip.Position = UDim2.fromScale(0.5, 1)
skip.ZIndex = 11

local status = label(panel, "StatusLabel", TEXT_SMALL, ACCENT)
status.Text = ""
status.AnchorPoint = Vector2.new(1, 0)
status.Position = UDim2.new(1, 0, 0, 36)
status.Size = UDim2.new(0.6, 0, 0, 20)
status.TextXAlignment = Enum.TextXAlignment.Right
status.ZIndex = 3

print(("[BUILD EGGSHOP] coquille prete : 4 onglets, modele de carte, panneau de revelation ; touche minimale %dpx"):format(MIN_TOUCH))
